#!/bin/bash

# 🔧 WAZUH DETECTION ENHANCEMENT SCRIPT
# This script enhances the Wazuh agent configuration for better attack detection

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SUCCESS="✅"
ERROR="❌"
WARNING="⚠️"
INFO="ℹ️"

print_header() {
    echo -e "${BLUE}════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}🔧 WAZUH DETECTION ENHANCEMENT CONFIGURATION 🔧${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════${NC}"
    echo
}

backup_config() {
    echo -e "${INFO} Creating backup of current configuration..."
    sudo cp /etc/ossec.conf /etc/ossec.conf.backup_$(date +%Y%m%d_%H%M%S)
    echo -e "${SUCCESS} Configuration backed up"
}

add_auth_log_monitoring() {
    echo -e "${INFO} Adding authentication log monitoring..."
    
    # Check if auth.log exists
    if [[ -f /var/log/auth.log ]]; then
        echo -e "${SUCCESS} Found /var/log/auth.log"
        
        # Add auth.log monitoring if not already present
        if ! sudo grep -q "/var/log/auth.log" /etc/ossec.conf; then
            sudo sed -i '/<\/ossec_config>/i\
  <localfile>\
    <log_format>syslog</log_format>\
    <location>/var/log/auth.log</location>\
  </localfile>' /etc/ossec.conf
            echo -e "${SUCCESS} Added auth.log monitoring"
        else
            echo -e "${INFO} auth.log monitoring already configured"
        fi
    else
        echo -e "${WARNING} /var/log/auth.log not found"
    fi
}

add_secure_log_monitoring() {
    echo -e "${INFO} Adding secure log monitoring..."
    
    if [[ -f /var/log/secure ]]; then
        if ! sudo grep -q "/var/log/secure" /etc/ossec.conf; then
            sudo sed -i '/<\/ossec_config>/i\
  <localfile>\
    <log_format>syslog</log_format>\
    <location>/var/log/secure</location>\
  </localfile>' /etc/ossec.conf
            echo -e "${SUCCESS} Added secure log monitoring"
        else
            echo -e "${INFO} secure log monitoring already configured"
        fi
    else
        echo -e "${INFO} /var/log/secure not found (normal for Debian-based systems)"
    fi
}

add_syslog_monitoring() {
    echo -e "${INFO} Adding system log monitoring..."
    
    if [[ -f /var/log/syslog ]]; then
        if ! sudo grep -q "/var/log/syslog" /etc/ossec.conf; then
            sudo sed -i '/<\/ossec_config>/i\
  <localfile>\
    <log_format>syslog</log_format>\
    <location>/var/log/syslog</location>\
  </localfile>' /etc/ossec.conf
            echo -e "${SUCCESS} Added syslog monitoring"
        else
            echo -e "${INFO} syslog monitoring already configured"
        fi
    fi
}

add_network_monitoring() {
    echo -e "${INFO} Adding enhanced network monitoring..."
    
    # Add more frequent netstat monitoring
    if ! sudo grep -q "netstat -an" /etc/ossec.conf; then
        sudo sed -i '/<\/ossec_config>/i\
  <localfile>\
    <log_format>full_command</log_format>\
    <command>netstat -an | grep LISTEN</command>\
    <alias>listening ports detailed</alias>\
    <frequency>180</frequency>\
  </localfile>' /etc/ossec.conf
        echo -e "${SUCCESS} Added detailed network monitoring"
    fi
    
    # Add process monitoring
    if ! sudo grep -q "ps aux" /etc/ossec.conf; then
        sudo sed -i '/<\/ossec_config>/i\
  <localfile>\
    <log_format>full_command</log_format>\
    <command>ps aux | grep -E "(ssh|nmap|nc|telnet|ftp)" | grep -v grep</command>\
    <alias>security relevant processes</alias>\
    <frequency>120</frequency>\
  </localfile>' /etc/ossec.conf
        echo -e "${SUCCESS} Added security process monitoring"
    fi
}

create_local_rules() {
    echo -e "${INFO} Creating local custom rules for better detection..."
    
    local rules_file="/var/ossec/etc/local_rules.xml"
    
    if [[ ! -f "$rules_file" ]]; then
        sudo tee "$rules_file" > /dev/null << 'EOF'
<!--
  Local rules for enhanced security detection
  File: /var/ossec/etc/local_rules.xml
-->

<group name="local,syslog,">
  
  <!-- Enhanced Nmap Detection -->
  <rule id="100001" level="8">
    <if_group>command</if_group>
    <match>nmap|masscan|zenmap</match>
    <description>Network scanning tool detected in process list</description>
    <group>recon,scanning,</group>
  </rule>
  
  <!-- SSH Brute Force Enhanced -->
  <rule id="100002" level="10">
    <if_group>authentication_failed</if_group>
    <match>ssh|sshd</match>
    <description>SSH authentication failure detected</description>
    <group>authentication_failed,ssh,</group>
  </rule>
  
  <!-- Netcat/Reverse Shell Detection -->
  <rule id="100003" level="12">
    <if_group>command</if_group>
    <match>nc -l|netcat -l|/bin/sh|/bin/bash</match>
    <regex>\d+\.\d+\.\d+\.\d+</regex>
    <description>Possible reverse shell or netcat listener detected</description>
    <group>intrusion,reverse_shell,</group>
  </rule>
  
  <!-- Multiple Connection Attempts -->
  <rule id="100004" level="6">
    <if_group>command</if_group>
    <match>LISTEN</match>
    <regex>:\d{4,5}\s</regex>
    <description>New network service listening on high port</description>
    <group>network,listening_ports,</group>
  </rule>
  
  <!-- Enhanced Sudo Detection -->
  <rule id="100005" level="4">
    <if_group>sudo</if_group>
    <match>COMMAND=</match>
    <description>Sudo command execution detected</description>
    <group>privilege_escalation,sudo,</group>
  </rule>
  
  <!-- File Access in Sensitive Directories -->
  <rule id="100006" level="7">
    <if_group>command</if_group>
    <match>/etc/passwd|/etc/shadow|/etc/sudoers</match>
    <description>Access to sensitive system files detected</description>
    <group>privilege_escalation,sensitive_files,</group>
  </rule>
  
  <!-- Log Injection Detection -->
  <rule id="100007" level="10">
    <match>SECURITY_TEST|WAZUH_TEST</match>
    <description>Security test injection detected in logs</description>
    <group>log_injection,testing,</group>
  </rule>

</group>

<!-- Frequency-based rules for enhanced detection -->
<group name="local,frequency,">
  
  <!-- Multiple failed connections -->
  <rule id="100101" level="10" frequency="5" timeframe="120">
    <if_matched_sid>100002</if_matched_sid>
    <same_source_ip />
    <description>Multiple SSH authentication failures from same IP</description>
    <group>brute_force,ssh,</group>
  </rule>
  
  <!-- Multiple sudo commands -->
  <rule id="100102" level="8" frequency="3" timeframe="300">
    <if_matched_sid>100005</if_matched_sid>
    <same_user />
    <description>Multiple sudo commands by same user in short time</description>
    <group>privilege_escalation,suspicious_activity,</group>
  </rule>

</group>
EOF
        echo -e "${SUCCESS} Created local custom rules"
    else
        echo -e "${INFO} Local rules file already exists"
    fi
    
    # Set proper permissions
    sudo chown root:ossec "$rules_file" 2>/dev/null || sudo chown root:wazuh "$rules_file" 2>/dev/null || true
    sudo chmod 640 "$rules_file"
}

increase_monitoring_frequency() {
    echo -e "${INFO} Increasing monitoring frequency for better detection..."
    
    # Increase rootcheck frequency (from 12 hours to 1 hour)
    sudo sed -i 's/<frequency>43200<\/frequency>/<frequency>3600<\/frequency>/g' /etc/ossec.conf
    
    # Increase syscheck frequency (from 12 hours to 30 minutes)
    sudo sed -i 's/<frequency>43200<\/frequency>/<frequency>1800<\/frequency>/g' /etc/ossec.conf
    
    echo -e "${SUCCESS} Increased monitoring frequencies"
}

enable_debug_logging() {
    echo -e "${INFO} Enabling debug logging for better visibility..."
    
    # Enable debug level logging
    if ! sudo grep -q "<debug>" /etc/ossec.conf; then
        sudo sed -i '/<logging>/a\    <debug>2</debug>' /etc/ossec.conf
        echo -e "${SUCCESS} Enabled debug logging"
    fi
}

restart_agent() {
    echo -e "${INFO} Restarting Wazuh agent to apply changes..."
    
    if sudo /var/ossec/bin/wazuh-control restart; then
        echo -e "${SUCCESS} Agent restarted successfully"
        
        # Wait for services to start
        sleep 10
        
        # Check status
        echo -e "${INFO} Checking agent status..."
        sudo /var/ossec/bin/wazuh-control status
    else
        echo -e "${ERROR} Failed to restart agent"
        echo -e "${WARNING} Check configuration with: sudo /var/ossec/bin/verify-agent-conf"
    fi
}

show_configuration_summary() {
    echo -e "${INFO} Configuration Summary:"
    echo "========================"
    
    echo -e "${BLUE}Log Sources:${NC}"
    sudo grep -A 2 "<localfile>" /etc/ossec.conf | grep -E "(location|command|alias)" || echo "No additional log sources"
    
    echo
    echo -e "${BLUE}Custom Rules:${NC}"
    if [[ -f /var/ossec/etc/local_rules.xml ]]; then
        echo -e "${SUCCESS} Local rules file exists"
        local rule_count=$(sudo grep -c "<rule id=" /var/ossec/etc/local_rules.xml 2>/dev/null || echo "0")
        echo "Custom rules count: $rule_count"
    else
        echo -e "${WARNING} No local rules file"
    fi
    
    echo
    echo -e "${BLUE}Monitoring Frequencies:${NC}"
    sudo grep -E "(frequency|interval)" /etc/ossec.conf | head -5
}

validate_configuration() {
    echo -e "${INFO} Validating configuration..."
    
    if sudo /var/ossec/bin/verify-agent-conf > /dev/null 2>&1; then
        echo -e "${SUCCESS} Configuration is valid"
        return 0
    else
        echo -e "${ERROR} Configuration validation failed"
        echo -e "${INFO} Running detailed validation..."
        sudo /var/ossec/bin/verify-agent-conf
        return 1
    fi
}

main() {
    print_header
    
    echo -e "${WARNING} This script will modify your Wazuh configuration"
    echo -e "${INFO} A backup will be created automatically"
    read -p "Continue? (y/n): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${INFO} Cancelled by user"
        exit 0
    fi
    
    backup_config
    
    echo -e "${INFO} Enhancing Wazuh detection capabilities..."
    echo
    
    add_auth_log_monitoring
    add_secure_log_monitoring  
    add_syslog_monitoring
    add_network_monitoring
    create_local_rules
    increase_monitoring_frequency
    enable_debug_logging
    
    echo
    echo -e "${INFO} Validating new configuration..."
    if validate_configuration; then
        restart_agent
        echo
        show_configuration_summary
        
        echo
        echo -e "${SUCCESS} Wazuh detection enhancement completed!"
        echo -e "${INFO} Your agent now has:"
        echo "  ✅ Enhanced log monitoring (auth, syslog)"
        echo "  ✅ Custom detection rules for network scans"
        echo "  ✅ Improved SSH brute force detection"
        echo "  ✅ Process monitoring for security tools"
        echo "  ✅ Higher frequency monitoring"
        echo "  ✅ Debug logging enabled"
        echo
        echo -e "${INFO} Run the attack simulation script to test detection:"
        echo "  ./comprehensive_attack_simulation.sh"
    else
        echo -e "${ERROR} Configuration validation failed!"
        echo -e "${INFO} Restoring backup..."
        
        # Find latest backup
        local latest_backup=$(ls -t /etc/ossec.conf.backup_* 2>/dev/null | head -1)
        if [[ -n "$latest_backup" ]]; then
            sudo cp "$latest_backup" /etc/ossec.conf
            echo -e "${SUCCESS} Configuration restored from backup"
        else
            echo -e "${ERROR} No backup found!"
        fi
    fi
}

# Check if running as root or with sudo
if [[ $EUID -eq 0 ]] || sudo -n true 2>/dev/null; then
    main "$@"
else
    echo -e "${ERROR} This script requires sudo privileges"
    echo -e "${INFO} Run with: sudo $0"
    exit 1
fi
