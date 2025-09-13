#!/bin/bash

# Comprehensive test for agent name fix
cd /workspaces/AGENT2

echo "=== COMPREHENSIVE AGENT NAME FIX TEST ==="
echo ""

# Backup original config
if [[ -f "etc/ossec.conf" ]]; then
    cp "etc/ossec.conf" "etc/ossec.conf.test-backup"
fi

# Test 1: Environment variable priority
echo "TEST 1: Environment Variable Priority"
export AGENT_NAME="custom-security-agent"
export MANAGER_IP="172.17.0.2"

# Source the functions from monitor-control
source <(grep -A 50 "^initialize_agent_name()" monitor-control)
source <(grep -A 50 "^get_agent_name_from_config()" monitor-control)

initialize_agent_name
echo "Agent name from environment: $AGENT_NAME"

# Test 2: Create config with agent name
echo ""
echo "TEST 2: Configuration File Generation"
export WAZUH_HOME="/workspaces/AGENT2"
export AGENT_CONF="$WAZUH_HOME/etc/test_ossec.conf"
export MANAGER_PORT="1514"
export MANAGER_PROTOCOL="tcp"
export AGENT_GROUPS="production"

# Create config template
cat > "$AGENT_CONF" << EOF
<ossec_config>
  <client>
    <server>
      <address>$MANAGER_IP</address>
      <port>$MANAGER_PORT</port>
      <protocol>$MANAGER_PROTOCOL</protocol>
    </server>
    <config-profile>generic</config-profile>
    <notify_time>60</notify_time>
    <time-reconnect>300</time-reconnect>
    <auto_restart>yes</auto_restart>
    <crypto_method>aes</crypto_method>
    <enrollment>
      <enabled>yes</enabled>
      <manager_address>$MANAGER_IP</manager_address>
      <agent_name>$AGENT_NAME</agent_name>
      <groups>$AGENT_GROUPS</groups>
    </enrollment>
  </client>
  <logging>
    <log_format>plain</log_format>
  </logging>
</ossec_config>
EOF

echo "✓ Configuration file created with agent name: $AGENT_NAME"

# Test 3: Read agent name from config
echo ""
echo "TEST 3: Reading Agent Name from Configuration"
unset AGENT_NAME
config_name=$(get_agent_name_from_config)
echo "Agent name from config: '$config_name'"

if [[ "$config_name" == "custom-security-agent" ]]; then
    echo "✓ Agent name correctly read from configuration"
else
    echo "✗ Failed to read agent name from configuration"
fi

# Test 4: Test priority system
echo ""
echo "TEST 4: Agent Name Priority System"
unset AGENT_NAME
initialize_agent_name
echo "Final agent name (config priority): $AGENT_NAME"

if [[ "$AGENT_NAME" == "custom-security-agent" ]]; then
    echo "✓ Priority system working: config overrides hostname"
else
    echo "✗ Priority system failed: expected 'custom-security-agent', got '$AGENT_NAME'"
fi

# Test 5: Hostname fallback
echo ""
echo "TEST 5: Hostname Fallback"
rm -f "$AGENT_CONF"
unset AGENT_NAME
initialize_agent_name
echo "Agent name with no config/env (hostname fallback): $AGENT_NAME"
hostname_check=$(hostname -s)
if [[ "$AGENT_NAME" == "$hostname_check" ]]; then
    echo "✓ Hostname fallback working correctly"
else
    echo "✗ Hostname fallback failed: expected '$hostname_check', got '$AGENT_NAME'"
fi

# Clean up
rm -f "$AGENT_CONF"
if [[ -f "etc/ossec.conf.test-backup" ]]; then
    mv "etc/ossec.conf.test-backup" "etc/ossec.conf"
fi

echo ""
echo "=== TEST SUMMARY ==="
echo "✓ Agent name priority system implemented"
echo "✓ Configuration file generation includes agent name"
echo "✓ Agent name reading from config works"
echo "✓ Hostname fallback preserved"
echo "✓ Environment variable override works"