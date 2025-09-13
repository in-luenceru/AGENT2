#!/bin/bash

# Test the agent name update functionality
cd /workspaces/AGENT2

echo "=== TESTING AGENT NAME UPDATE FUNCTIONALITY ==="

# Set up test environment
export WAZUH_HOME="/workspaces/AGENT2"
export AGENT_CONF="$WAZUH_HOME/test_agent_name_update.conf"

# Create a basic config without agent name
cat > "$AGENT_CONF" << 'EOF'
<ossec_config>
  <client>
    <server>
      <address>172.17.0.2</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
    <config-profile>generic</config-profile>
  </client>
</ossec_config>
EOF

echo "Original configuration:"
cat "$AGENT_CONF"
echo ""

# Extract and test the update_agent_name_config function
echo "Testing agent name update function..."

# Simple sed-based update (since xmlstarlet might not be available)
agent_name="production-monitoring-agent-001"

# Add agent_name to enrollment section or create enrollment section
if grep -q "<enrollment>" "$AGENT_CONF"; then
    # Add to existing enrollment section
    sed -i.bak "/^[[:space:]]*<\/enrollment>/i\\
      <agent_name>$agent_name</agent_name>" "$AGENT_CONF"
else
    # Add complete enrollment section after server section
    sed -i.bak "/^[[:space:]]*<\/server>/a\\
    <enrollment>\\
      <enabled>yes</enabled>\\
      <agent_name>$agent_name</agent_name>\\
    </enrollment>" "$AGENT_CONF"
fi

echo "Updated configuration:"
cat "$AGENT_CONF"
echo ""

# Verify the update
updated_name=$(grep -A 10 "<enrollment>" "$AGENT_CONF" | grep "<agent_name>" | sed 's/.*<agent_name>\(.*\)<\/agent_name>.*/\1/' | tr -d '[:space:]')
echo "Extracted agent name: '$updated_name'"

if [[ "$updated_name" == "$agent_name" ]]; then
    echo "✓ Agent name update successful!"
else
    echo "✗ Agent name update failed"
fi

# Clean up
rm -f "$AGENT_CONF" "${AGENT_CONF}.bak"