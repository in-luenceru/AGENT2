# 🛡️ WAZUH AGENT - COMPLETE USAGE DOCUMENTATION

## 📋 Table of Contents
1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Installation & Setup](#installation--setup)
4. [Configuration Guide](#configuration-guide)
5. [Operation Commands](#operation-commands)
6. [Agent Identity Management](#agent-identity-management)
7. [Monitoring & Alerts](#monitoring--alerts)
8. [Network Security Detection](#network-security-detection)
9. [Troubleshooting Guide](#troubleshooting-guide)
10. [Production Deployment](#production-deployment)
11. [Maintenance & Updates](#maintenance--updates)

---

## 🎯 Overview

This documentation covers a complete Wazuh Security Information and Event Management (SIEM) setup with:
- **Custom Wazuh Agent**: Extracted and configured for standalone operation
- **Docker Manager**: Containerized Wazuh manager for centralized monitoring
- **Real-time Monitoring**: File integrity, process monitoring, and security alerts
- **Network Detection**: Custom rules for network scanning and intrusion detection

### 🏗️ System Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   WAZUH AGENT   │    │  DOCKER MANAGER  │    │   MONITORING    │
│                 │    │                  │    │                 │
│ • File Monitor  │◄──►│ • Alert Analysis │◄──►│ • Dashboards    │
│ • Log Collector │    │ • Rule Engine    │    │ • Reports       │
│ • Process Watch │    │ • Event Storage  │    │ • Notifications │
│ • Sys Integrity │    │ • API Interface  │    │ • Forensics     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
      Port 1514              Ports 1514,1515,55000
```

### 📁 Directory Structure

```
/workspaces/AGENT2/
├── bin/                    # Agent binaries and scripts
│   ├── monitor-agentd      # Enhanced agent daemon wrapper
│   └── wazuh-*            # Wazuh binary wrappers
├── etc/                    # Configuration files
│   ├── ossec.conf         # Main agent configuration
│   ├── client.keys        # Authentication keys
│   └── agent.identity     # Persistent agent identity (NEW)
├── lib/                    # Library files
│   └── agent_identity.sh  # Identity management library (NEW)
├── logs/                   # Agent logs
│   └── ossec.log          # Main log file
├── var/run/               # Runtime files and PIDs
├── scripts/               # Custom monitoring scripts
│   └── proof_update_agent_name.sh  # Agent name update proof script (NEW)
├── docs/                  # Documentation
│   └── COMPLETE_USAGE_DOCUMENTATION.md
├── monitor-control        # Main agent control script (ENHANCED)
├── PROOF_AGENT_NAME.md    # Static proof of current naming (NEW)
└── PROOF_AGENT_NAME_UPDATE.md  # Dynamic proof of name updates (NEW)
```

---

## 🚀 Installation & Setup

### Prerequisites

```bash
# System requirements
- Linux (Ubuntu/Debian/CentOS/RHEL)
- Docker (for manager)
- Root/sudo access
- Network connectivity
- Minimum 2GB RAM, 10GB disk space
```

### Step 1: Install Docker Manager

```bash
# Pull and start Wazuh manager
docker run -d \
  --name wazuh-manager \
  -p 1514:1514 \
  -p 1515:1515 \
  -p 55000:55000 \
  wazuh/wazuh-manager:4.12.0

# Verify manager is running
docker ps
docker logs wazuh-manager
```

### Step 2: Install Wazuh Agent

```bash
# Install official Wazuh agent

set -e
sudo apt-get update -y
sudo apt-get install -y curl gnupg apt-transport-https lsb-release
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | sudo gpg --dearmor -o /usr/share/keyrings/wazuh-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh-archive-keyring.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee /etc/apt/sources.list.d/wazuh.list
sudo apt-get update -y
sudo apt-get install -y wazuh-agent
sudo apt update
sudo apt install -y wazuh-agent

# Or use your custom agent setup
cd /home/anandhu/AGENT
chmod +x build_simple_agent.sh
./build_simple_agent.sh
```

### Step 3: Register Agent with Manager

```bash
# Method 1: Using monitor-control (Recommended)
cd /workspaces/AGENT2
sudo ./monitor-control enroll

# Method 2: Manual registration with custom name
AGENT_NAME="secure-agent-123"
docker exec -it wazuh-manager bash -c "
echo -e 'A\n$AGENT_NAME\n127.0.0.1\ny\nQ' | /var/ossec/bin/manage_agents"

# Extract agent key
AGENT_ID=$(docker exec wazuh-manager bash -c "echo -e 'L\nQ' | /var/ossec/bin/manage_agents" | grep "$AGENT_NAME" | awk '{print $2}' | tr -d ',')
AGENT_KEY=$(docker exec wazuh-manager bash -c "echo -e 'E\n$AGENT_ID\nQ' | /var/ossec/bin/manage_agents" | grep "Agent key:")

# Set up persistent agent identity
source /workspaces/AGENT2/lib/agent_identity.sh
set_agent_name "$AGENT_NAME" ""

# Add key to agent (replace with actual key)
echo "$AGENT_ID $AGENT_NAME any YOUR_AGENT_KEY_HERE" | sudo tee /workspaces/AGENT2/etc/client.keys

# Create symlinks for Wazuh compatibility
sudo ln -sf /workspaces/AGENT2/etc/client.keys /var/ossec/etc/client.keys
sudo ln -sf /workspaces/AGENT2/etc/ossec.conf /var/ossec/etc/ossec.conf
```

### Step 4: Configure Agent

```bash
# Configure manager IP
sudo sed -i 's/<address>MANAGER_IP<\/address>/<address>127.0.0.1<\/address>/g' /etc/ossec.conf

# Start agent
sudo ./monitor-control start
```

---

## ⚙️ Configuration Guide

### Main Configuration File: `/etc/ossec.conf`

#### Basic Agent Configuration

```xml
<ossec_config>
  <!-- Agent connection settings -->
  <client>
    <server>
      <address>127.0.0.1</address>      <!-- Manager IP -->
      <port>1514</port>                 <!-- Manager port -->
      <protocol>tcp</protocol>          <!-- Connection protocol -->
    </server>
    <config-profile>generic</config-profile>
    <notify_time>10</notify_time>       <!-- Heartbeat interval -->
    <time-reconnect>60</time-reconnect> <!-- Reconnection timeout -->
    <auto_restart>yes</auto_restart>    <!-- Auto-restart on failure -->
    <crypto_method>aes</crypto_method>  <!-- Encryption method -->
  </client>
</ossec_config>
```

#### File Integrity Monitoring

```xml
<syscheck>
  <disabled>no</disabled>
  <frequency>43200</frequency>          <!-- Check every 12 hours -->
  <scan_on_start>yes</scan_on_start>
  
  <!-- Directories to monitor -->
  <directories>/etc,/usr/bin,/usr/sbin</directories>
  <directories>/bin,/sbin</directories>
  <directories realtime="yes">/home</directories>
  
  <!-- Files to ignore -->
  <ignore>/etc/mtab</ignore>
  <ignore>/var/log</ignore>
</syscheck>
```

#### Log Analysis Configuration

```xml
<!-- System logs -->
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/syslog</location>
</localfile>

<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/auth.log</location>
</localfile>

<!-- Command monitoring -->
<localfile>
  <log_format>command</log_format>
  <command>ps aux | grep -E "(nmap|masscan)" | grep -v grep</command>
  <frequency>30</frequency>
</localfile>

<!-- Network monitoring -->
<localfile>
  <log_format>command</log_format>
  <command>netstat -tulpn | head -20</command>
  <frequency>60</frequency>
</localfile>
```

---

## 🎮 Operation Commands

### Agent Control Commands

```bash
# Start/Stop/Restart agent
sudo ./monitor-control enroll
sudo ./monitor-control start
sudo ./montior-control stop
sudo ./monitor-control restart

# Check agent status
sudo ./monitor-control status

# View agent information
sudo ./monitor-control info

# Identity management
source /workspaces/AGENT2/lib/agent_identity.sh
show_agent_identity                    # Display current identity
set_agent_name "new-name" ""          # Set persistent agent name
get_agent_name                        # Get current agent name
verify_identity_integrity             # Check identity file integrity

# Generate proof of name change
/workspaces/AGENT2/scripts/proof_update_agent_name.sh "new-agent-name"
```

### Manager Control Commands

```bash
# Manager operations (Docker)
docker start wazuh-manager
docker stop wazuh-manager
docker restart wazuh-manager

# View manager logs
docker logs wazuh-manager
docker logs -f wazuh-manager  # Follow logs

# Access manager shell
docker exec -it wazuh-manager bash
```

### Agent Management

```bash
# List registered agents
docker exec wazuh-manager bash -c "echo -e 'L\nQ' | /var/ossec/bin/manage_agents"

# Add new agent
docker exec -it wazuh-manager bash -c "echo -e 'A\nAGENT_NAME\nAGENT_IP\ny\nQ' | /var/ossec/bin/manage_agents"

# Remove agent
docker exec -it wazuh-manager bash -c "echo -e 'R\nAGENT_ID\ny\nQ' | /var/ossec/bin/manage_agents"
```

### Log Analysis Commands

```bash
# View agent logs
sudo tail -f /logs/ossec.log

# View alerts on manager
docker exec wazuh-manager tail -f /var/ossec/logs/alerts/alerts.log

# Search for specific alerts
docker exec wazuh-manager grep -i "nmap\|scan" /var/ossec/logs/alerts/alerts.log

# View JSON alerts
docker exec wazuh-manager tail -f /var/ossec/logs/alerts/alerts.json
```

---

## 🏷️ Agent Identity Management

### Persistent Agent Naming

The agent now supports persistent, user-defined names that survive restarts and override the system hostname. This ensures consistent identification in alerts and manager communications.

#### Setting Agent Name

```bash
# Set a persistent agent name using the identity library
source /workspaces/AGENT2/lib/agent_identity.sh
set_agent_name "my-custom-agent-name" ""

# Or use the proof script to update and verify
/workspaces/AGENT2/scripts/proof_update_agent_name.sh "new-agent-name"
```

#### Verifying Agent Identity

```bash
# Check current agent identity
source /workspaces/AGENT2/lib/agent_identity.sh
show_agent_identity

# View identity file contents
sudo cat /workspaces/AGENT2/etc/agent.identity

# Check agent name in manager
docker exec wazuh-manager /var/ossec/bin/agent_control -l
```

#### Agent Name Update Workflow

1. **Update Local Identity**: The agent's persistent identity is stored in `/workspaces/AGENT2/etc/agent.identity`
2. **Restart Agent**: Apply the new name by restarting the agent
3. **Verify Manager**: Check that alerts use the new agent name
4. **Generate Proof**: Use the proof script for documentation

```bash
#!/bin/bash
# Complete agent name update workflow

# Step 1: Set new agent name
NEW_NAME="production-web-server-01"
source /workspaces/AGENT2/lib/agent_identity.sh
set_agent_name "$NEW_NAME" ""

# Step 2: Restart agent to apply changes
sudo ./monitor-control restart

# Step 3: Verify on manager
echo "Checking agent registration on manager..."
docker exec wazuh-manager /var/ossec/bin/agent_control -l

# Step 4: Check recent alerts for the new name
echo "Checking recent alerts..."
docker exec wazuh-manager tail -20 /var/ossec/logs/alerts/alerts.log | grep "($NEW_NAME)"
```

### Automated Proof Generation

Use the proof script to document agent name changes:

```bash
# Generate proof of agent name update
/workspaces/AGENT2/scripts/proof_update_agent_name.sh "new-secure-agent-name"

# The script will:
# 1. Update the agent's persistent identity
# 2. Restart the agent 
# 3. Collect evidence from manager
# 4. Write proof document to PROOF_AGENT_NAME_UPDATE.md
```

#### Proof Script Features

- **Validation**: Uses the identity library's built-in name validation
- **Security**: Updates persistent storage with integrity checksums
- **Verification**: Collects manager outputs and recent alerts
- **Documentation**: Generates timestamped proof files

#### Identity File Structure

```bash
# /workspaces/AGENT2/etc/agent.identity
AGENT_NAME="secure-agent-123"
AGENT_ID="003"
AGENT_GROUP="default"
REGISTRATION_DATE="2025-09-13 15:44:50"
LAST_UPDATE="2025-09-13 16:23:20"
MANAGER_IP="127.0.0.1"
ENROLLMENT_STATUS="enrolled"
CHECKSUM="b65977f2be014548a5c1457d589e93378a6317c68bbcc281816f1c161ed32326"
```

### Troubleshooting Agent Names

#### Common Issues

**Agent name not updating on manager:**
- The manager's `client.keys` may still reference the old name
- Consider re-enrolling the agent or updating manager keys manually

**Identity file permission errors:**
- Ensure proper file permissions: `sudo chmod 600 /workspaces/AGENT2/etc/agent.identity`
- Check directory ownership: `sudo chown -R root:root /workspaces/AGENT2/etc/`

**Name validation failures:**
- Agent names must be 3-64 characters
- Only alphanumeric, dash, underscore, and dot characters allowed
- Cannot start or end with special characters
- Reserved names (localhost, manager, server, admin, root, system, default) are not allowed

#### Verification Commands

```bash
# Verify agent name is set correctly
./monitor-control status

# Check identity file integrity
source /workspaces/AGENT2/lib/agent_identity.sh
verify_identity_integrity

# View agent environment variables
sudo /workspaces/AGENT2/bin/monitor-agentd --test-name

# Check symlinks are correct
ls -la /var/ossec/etc/client.keys /var/ossec/etc/ossec.conf
```

---

## 🔍 Monitoring & Alerts

### Real-time Monitoring Setup

```bash
#!/bin/bash
# Real-time monitoring script

echo "Starting Wazuh Real-time Monitor..."

# Terminal 1: Agent logs
gnome-terminal --tab --title="Agent Logs" -- bash -c "
sudo tail -f /logs/ossec.log; exec bash"

# Terminal 2: Manager alerts
gnome-terminal --tab --title="Manager Alerts" -- bash -c "
docker exec -it wazuh-manager tail -f /var/ossec/logs/alerts/alerts.log; exec bash"

# Terminal 3: System monitoring
gnome-terminal --tab --title="System Monitor" -- bash -c "
watch -n 2 'ps aux | head -20; echo; netstat -tlnp | head -10'; exec bash"
```

### Alert Types and Meanings

| Alert Level | Severity | Description | Example |
|-------------|----------|-------------|---------|
| **1-3** | Low | Informational events | File access, successful login |
| **4-6** | Medium | Security events | Failed login attempts |
| **7-9** | High | Important security issues | Multiple failed logins |
| **10-12** | Critical | Security violations | Root access, malware |
| **13-15** | Severe | Critical security breaches | System compromise |

### Common Alert Rules

```bash
# Rule 503: Agent started
Rule: 503 (level 3) -> 'Wazuh agent started.'

# Rule 5402: Successful sudo
Rule: 5402 (level 3) -> 'Successful sudo to ROOT executed.'

# Rule 5501: Login session opened
Rule: 5501 (level 3) -> 'PAM: Login session opened.'

# Rule 5706: SSH scan attempt
Rule: 5706 (level 6) -> 'sshd: insecure connection attempt (scan).'
```

---

## 🕵️ Network Security Detection

### Setup Network Attack Detection

#### 1. Install Target Services

```bash
# Install SSH for scan detection
sudo apt install -y openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh

# Configure verbose SSH logging
sudo sed -i 's/#LogLevel INFO/LogLevel VERBOSE/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

#### 2. Add Network Monitoring Rules

```bash
# Create network monitoring configuration
sudo tee -a /etc/ossec.conf << 'EOF'
<!-- Network Security Monitoring -->
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/auth.log</location>
</localfile>

<!-- Process monitoring for security tools -->
<localfile>
  <log_format>command</log_format>
  <command>ps aux | grep -E "(nmap|masscan|nikto|sqlmap)" | grep -v grep</command>
  <frequency>30</frequency>
</localfile>

<!-- Network connection monitoring -->
<localfile>
  <log_format>command</log_format>
  <command>netstat -tuln | grep LISTEN | wc -l</command>
  <alias>listening_ports</alias>
  <frequency>300</frequency>
</localfile>

<!-- Custom security events -->
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/security_events.log</location>
</localfile>
EOF

# Create security events log
sudo touch /var/log/security_events.log
sudo chown root:root /var/log/security_events.log
```

#### 3. Test Network Attack Detection

```bash
#!/bin/bash
# Network attack simulation script

echo "=== WAZUH NETWORK ATTACK DETECTION TEST ==="

# Test 1: SSH Connection attempts
echo "Test 1: SSH scanning simulation"
nmap -sT -p 22 localhost
timeout 3 telnet localhost 22 < /dev/null || true

# Test 2: Process-based detection
echo "Test 2: Security tool detection"
nmap -sT -p 1-10 localhost &
NMAP_PID=$!
sleep 35  # Wait for process monitoring cycle
kill $NMAP_PID 2>/dev/null || true

# Test 3: Custom security event
echo "Test 3: Custom security event"
echo "$(date): SECURITY_ALERT - Network scan detected from $(whoami)@$(hostname)" | sudo tee -a /var/log/security_events.log

# Wait and check alerts
echo "Waiting 30 seconds for alert processing..."
sleep 30

echo "Recent alerts:"
docker exec wazuh-manager tail -20 /var/ossec/logs/alerts/alerts.log
```

### Custom Attack Detection Rules

Create custom rules for specific attack patterns:

```bash
# Custom rule file: /var/ossec/etc/local_rules.xml
sudo tee /var/ossec/etc/local_rules.xml << 'EOF'
<group name="local,syslog,">
  <!-- Custom network scan detection -->
  <rule id="100001" level="7">
    <if_group>command</if_group>
    <match>nmap|masscan|zmap</match>
    <description>Network scanning tool detected</description>
    <group>recon,pci_dss_11.4,</group>
  </rule>
  
  <!-- Multiple connection attempts -->
  <rule id="100002" level="8" frequency="5" timeframe="300">
    <if_group>authentication_failed</if_group>
    <description>Multiple connection attempts - possible scan</description>
    <group>authentication_failures,pci_dss_10.2.4,</group>
  </rule>
</group>
EOF
```

---

## 🔧 Troubleshooting Guide

### Common Issues and Solutions

#### 1. Agent Won't Connect to Manager

**Symptoms:**
- Agent logs show "Connection refused" or "Timeout"
- No alerts appearing on manager

**Solutions:**
```bash
# Check manager is running
docker ps | grep wazuh-manager

# Verify ports are open
telnet 127.0.0.1 1514

# Check agent configuration
grep -A 5 "<server>" /etc/ossec.conf

# Verify client keys match
cat /var/ossec/etc/client.keys
docker exec wazuh-manager cat /var/ossec/etc/client.keys
```

#### 2. No Alerts Being Generated

**Symptoms:**
- Agent connected but no alerts in manager logs
- Events happening but not triggering rules

**Solutions:**
```bash
# Check agent modules are running
sudo /var/ossec/bin/wazuh-control status

# Verify log collection
sudo grep "Analyzing file" /var/ossec/logs/ossec.log

# Test with manual event
logger "TEST: Security event for Wazuh testing"

# Check manager rule processing
docker exec wazuh-manager tail -f /var/ossec/logs/ossec.log
```

#### 3. High CPU Usage

**Symptoms:**
- Wazuh processes consuming high CPU
- System performance degradation

**Solutions:**
```bash
# Reduce monitoring frequency
sudo sed -i 's/<frequency>30<\/frequency>/<frequency>300<\/frequency>/g' /etc/ossec.conf

# Limit file monitoring
sudo sed -i 's/<scan_on_start>yes<\/scan_on_start>/<scan_on_start>no<\/scan_on_start>/g' /etc/ossec.conf

# Check for resource-intensive rules
docker exec wazuh-manager grep -i "frequency" /var/ossec/ruleset/rules/*.xml
```

#### 4. Disk Space Issues

**Symptoms:**
- Logs growing too large
- System running out of space

**Solutions:**
```bash
# Configure log rotation
sudo tee /etc/logrotate.d/wazuh-agent << 'EOF'
/var/ossec/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    postrotate
        /var/ossec/bin/wazuh-control restart > /dev/null 2>&1 || true
    endscript
}
EOF

# Clean old logs
sudo find /var/ossec/logs -name "*.log.*" -mtime +30 -delete
```

### Diagnostic Commands

```bash
#!/bin/bash
# Wazuh diagnostic script

echo "=== WAZUH SYSTEM DIAGNOSTICS ==="

echo "1. Agent Status:"
sudo /var/ossec/bin/wazuh-control status

echo "2. Manager Status:"
docker ps | grep wazuh

echo "3. Network Connectivity:"
telnet 127.0.0.1 1514 < /dev/null

echo "4. Recent Agent Logs:"
sudo tail -20 /var/ossec/logs/ossec.log

echo "5. Recent Alerts:"
docker exec wazuh-manager tail -10 /var/ossec/logs/alerts/alerts.log

echo "6. Agent Configuration:"
grep -A 5 "<server>" /etc/ossec.conf

echo "7. Client Keys:"
wc -l /var/ossec/etc/client.keys

echo "8. Disk Usage:"
df -h /var/ossec/

echo "9. Process Information:"
ps aux | grep -E "(wazuh|ossec)" | grep -v grep

echo "10. Network Ports:"
netstat -tlnp | grep -E "(1514|1515)"
```

---

## 🏭 Production Deployment

### Production Configuration Checklist

- [ ] **Security Hardening**
  - [ ] Change default passwords
  - [ ] Configure SSL/TLS certificates
  - [ ] Restrict network access
  - [ ] Enable firewall rules

- [ ] **Performance Optimization**
  - [ ] Adjust monitoring frequencies
  - [ ] Configure log retention
  - [ ] Optimize rule sets
  - [ ] Scale resources appropriately

- [ ] **High Availability**
  - [ ] Configure backup agents
  - [ ] Set up manager clustering
  - [ ] Implement failover procedures
  - [ ] Configure backup strategies

### Production Security Configuration

```bash
# 1. Configure SSL/TLS
sudo openssl req -x509 -newkey rsa:4096 -keyout /var/ossec/etc/agent.key -out /var/ossec/etc/agent.crt -days 365 -nodes

# 2. Firewall configuration
sudo ufw allow from MANAGER_IP to any port 1514
sudo ufw allow from MANAGER_IP to any port 1515
sudo ufw enable

# 3. User access control
sudo groupadd wazuh-users
sudo usermod -a -G wazuh-users monitoring-user

# 4. Log permissions
sudo chmod 640 /var/ossec/logs/*.log
sudo chown root:wazuh-users /var/ossec/logs/*.log
```

### Backup and Recovery

```bash
#!/bin/bash
# Wazuh backup script

BACKUP_DIR="/backup/wazuh/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

echo "Creating Wazuh backup..."

# Backup agent configuration
sudo cp -r /var/ossec/etc "$BACKUP_DIR/agent-config"

# Backup agent logs (last 7 days)
sudo find /var/ossec/logs -name "*.log" -mtime -7 -exec cp {} "$BACKUP_DIR/" \;

# Backup manager data
docker exec wazuh-manager tar -czf /tmp/manager-backup.tar.gz /var/ossec/etc /var/ossec/logs/alerts
docker cp wazuh-manager:/tmp/manager-backup.tar.gz "$BACKUP_DIR/"

# Backup custom rules
sudo cp /var/ossec/etc/local_rules.xml "$BACKUP_DIR/" 2>/dev/null || true

echo "Backup completed: $BACKUP_DIR"

# Retention: Keep last 30 days
find /backup/wazuh -type d -mtime +30 -exec rm -rf {} \; 2>/dev/null || true
```

---

## 🔄 Maintenance & Updates

### Regular Maintenance Tasks

#### Daily Checks
```bash
#!/bin/bash
# Daily maintenance script

# Check agent status
if ! sudo /var/ossec/bin/wazuh-control status | grep -q "is running"; then
    echo "ALERT: Wazuh agent not running" | mail -s "Wazuh Alert" admin@company.com
    sudo /var/ossec/bin/wazuh-control start
fi

# Check disk space
DISK_USAGE=$(df /var/ossec | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "WARNING: Wazuh disk usage at ${DISK_USAGE}%" | mail -s "Disk Space Alert" admin@company.com
fi

# Check recent alerts count
ALERT_COUNT=$(docker exec wazuh-manager find /var/ossec/logs/alerts -name "*.log" -mtime -1 -exec wc -l {} \; | awk '{sum+=$1} END {print sum}')
echo "Daily alerts: $ALERT_COUNT"
```

#### Weekly Maintenance
```bash
#!/bin/bash
# Weekly maintenance script

# Update rules
docker exec wazuh-manager /var/ossec/bin/update_ruleset

# Clean old logs
sudo find /var/ossec/logs -name "ossec.log.*" -mtime +7 -delete

# Generate reports
docker exec wazuh-manager /var/ossec/bin/wazuh-logtest-legacy -v | grep -c "Rule.*matched" > /var/log/weekly-wazuh-stats.log

# Backup configuration
sudo cp /etc/ossec.conf /etc/ossec.conf.backup.$(date +%Y%m%d)
```

### Update Procedures

#### Agent Updates
```bash
# 1. Backup current configuration
sudo cp -r /var/ossec/etc /var/ossec/etc.backup

# 2. Stop agent
sudo /var/ossec/bin/wazuh-control stop

# 3. Update package
sudo apt update && sudo apt upgrade wazuh-agent

# 4. Restore configuration if needed
sudo diff /etc/ossec.conf /var/ossec/etc.backup/ossec.conf

# 5. Start agent
sudo /var/ossec/bin/wazuh-control start
```

#### Manager Updates
```bash
# 1. Backup manager data
docker exec wazuh-manager tar -czf /tmp/manager-backup.tar.gz /var/ossec

# 2. Stop and remove old container
docker stop wazuh-manager
docker rm wazuh-manager

# 3. Start new version
docker run -d --name wazuh-manager -p 1514:1514 -p 1515:1515 -p 55000:55000 wazuh/wazuh-manager:LATEST_VERSION

# 4. Restore data if needed
docker cp manager-backup.tar.gz wazuh-manager:/tmp/
docker exec wazuh-manager tar -xzf /tmp/manager-backup.tar.gz
```

---

## 📞 Support & Resources

### Quick Reference Commands

```bash
# Essential commands
sudo /var/ossec/bin/wazuh-control status    # Check agent status
docker logs wazuh-manager                   # Check manager logs
sudo tail -f /var/ossec/logs/ossec.log     # Follow agent logs
docker exec wazuh-manager tail -f /var/ossec/logs/alerts/alerts.log  # Follow alerts

# Configuration files
/var/ossec/etc/ossec.conf                   # Agent configuration
/var/ossec/etc/client.keys                  # Authentication keys
/var/ossec/etc/local_rules.xml             # Custom rules
/var/ossec/logs/ossec.log                   # Agent logs
```

### Documentation Links
- [Official Wazuh Documentation](https://documentation.wazuh.com/)
- [Rule Reference](https://documentation.wazuh.com/current/user-manual/ruleset/)
- [Agent Configuration](https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/)
- [API Reference](https://documentation.wazuh.com/current/user-manual/api/)

### Support Contacts
- **Technical Issues**: Check logs and run diagnostics script
- **Security Alerts**: Follow incident response procedures
- **Performance Issues**: Review resource usage and optimization

---

## 📝 Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-09-11 | Initial documentation with full setup guide |
| | | Complete configuration examples |
| | | Troubleshooting procedures |
| | | Production deployment guide |

---

**📧 For questions or issues, consult the troubleshooting section or check the official Wazuh documentation.**

**🔒 Remember: Always test changes in a development environment before applying to production systems.**
