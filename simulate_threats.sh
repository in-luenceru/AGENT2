#!/bin/bash
# Threat Simulation Script for Testing Real Agent Detection

AGENT_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${YELLOW}[SIMULATION]${NC} $1"; }
log_success() { echo -e "${GREEN}[DETECTED]${NC} $1"; }

echo "=== Wazuh Agent Threat Detection Simulation ==="
echo

# Simulate file modification
log_info "Simulating file integrity violation..."
echo "$(date): Test file modification" > /tmp/test_security_file
chmod 777 /tmp/test_security_file
sleep 2

# Simulate failed login attempts
log_info "Simulating failed login attempts..."
echo "$(date): auth.log: Failed password for invalid user test from 192.168.1.100 port 22" | sudo tee -a /var/log/security_events.log

# Simulate network scanning
log_info "Simulating network scanning activity..."
echo "$(date): SECURITY_ALERT - Network scanning detected from 192.168.1.50" | sudo tee -a /var/log/security_events.log

# Simulate privilege escalation
log_info "Simulating privilege escalation attempt..."
echo "$(date): sudo: invalid user test-user: TTY=pts/0 ; PWD=/tmp ; USER=root ; COMMAND=/bin/bash" | sudo tee -a /var/log/security_events.log

# Simulate suspicious process
log_info "Simulating suspicious process detection..."
echo "$(date): Process detected: nmap -sS 192.168.1.0/24" | sudo tee -a /var/log/security_events.log

# Simulate mount attempt
log_info "Simulating network file system mount..."
echo "$(date): mount: 192.168.1.200:/shared /mnt/nfs" | sudo tee -a /var/log/security_events.log

log_success "Threat simulation completed. Check agent logs and manager alerts."
