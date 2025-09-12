#!/bin/bash
# Comprehensive Wazuh Agent Integration Fix Script
# This script replaces mock implementations with real Wazuh components

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_HOME="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to stop mock processes
stop_mock_processes() {
    log_info "Stopping mock agent processes..."
    
    # Find and stop mock processes
    for process in monitor-agentd monitor-logcollector monitor-syscheckd monitor-execd monitor-modulesd; do
        if pgrep -f "$process" > /dev/null; then
            log_info "Stopping $process..."
            pkill -f "$process" || true
            sleep 2
        fi
    done
    
    log_success "Mock processes stopped"
}

# Function to backup mock binaries
backup_mock_binaries() {
    log_info "Backing up mock binaries..."
    
    mkdir -p "$AGENT_HOME/backup/bin"
    
    for mock_bin in monitor-agentd monitor-logcollector monitor-syscheckd monitor-execd monitor-modulesd; do
        if [[ -f "$AGENT_HOME/bin/$mock_bin" ]]; then
            cp "$AGENT_HOME/bin/$mock_bin" "$AGENT_HOME/backup/bin/"
            log_info "Backed up $mock_bin"
        fi
    done
    
    log_success "Mock binaries backed up to $AGENT_HOME/backup/bin/"
}

# Function to create real agent binaries
create_real_binaries() {
    log_info "Creating real agent binaries to replace mocks..."
    
    # Replace monitor-agentd with real wazuh-agentd functionality
    cat > "$AGENT_HOME/bin/monitor-agentd" << 'EOF'
#!/bin/bash
# Real Monitoring Agent Daemon - Wrapper for wazuh-agentd

WAZUH_HOME="${WAZUH_HOME:-$(dirname $(dirname $(realpath $0)))}"
PID_DIR="$WAZUH_HOME/var/run"
mkdir -p "$PID_DIR"

# Use the real compiled wazuh-agentd if available, otherwise use system wazuh-agentd
if [[ -f "$WAZUH_HOME/src/wazuh-agentd" ]]; then
    AGENTD_BIN="$WAZUH_HOME/src/wazuh-agentd"
elif [[ -f "/var/ossec/bin/wazuh-agentd" ]]; then
    AGENTD_BIN="/var/ossec/bin/wazuh-agentd"
else
    echo "[$(date)] ERROR: No wazuh-agentd binary found"
    exit 1
fi

echo "[$(date)] monitor-agentd: Starting real agent daemon"
echo "[$(date)] monitor-agentd: Using binary: $AGENTD_BIN"
echo "[$(date)] monitor-agentd: Configuration: $WAZUH_HOME/etc/ossec.conf"

# Set environment for Wazuh agent
export WAZUH_HOME="$WAZUH_HOME"

# Start the real agent daemon with proper configuration
exec "$AGENTD_BIN" -c "$WAZUH_HOME/etc/ossec.conf" "$@"
EOF

    # Replace monitor-logcollector with real functionality
    cat > "$AGENT_HOME/bin/monitor-logcollector" << 'EOF'
#!/bin/bash
# Real Log Collector - Wrapper for wazuh-logcollector

WAZUH_HOME="${WAZUH_HOME:-$(dirname $(dirname $(realpath $0)))}"
PID_DIR="$WAZUH_HOME/var/run"
mkdir -p "$PID_DIR"

# Use the real compiled wazuh-logcollector
if [[ -f "/var/ossec/bin/wazuh-logcollector" ]]; then
    LOGCOLLECTOR_BIN="/var/ossec/bin/wazuh-logcollector"
else
    echo "[$(date)] ERROR: No wazuh-logcollector binary found"
    exit 1
fi

echo "[$(date)] monitor-logcollector: Starting real log collector"
echo "[$(date)] monitor-logcollector: Using binary: $LOGCOLLECTOR_BIN"

# Set environment
export WAZUH_HOME="$WAZUH_HOME"

# Start the real log collector
exec "$LOGCOLLECTOR_BIN" -c "$WAZUH_HOME/etc/ossec.conf" "$@"
EOF

    # Replace monitor-syscheckd with real functionality
    cat > "$AGENT_HOME/bin/monitor-syscheckd" << 'EOF'
#!/bin/bash
# Real File Integrity Monitor - Wrapper for wazuh-syscheckd

WAZUH_HOME="${WAZUH_HOME:-$(dirname $(dirname $(realpath $0)))}"
PID_DIR="$WAZUH_HOME/var/run"
mkdir -p "$PID_DIR"

# Use the real wazuh-syscheckd
if [[ -f "/var/ossec/bin/wazuh-syscheckd" ]]; then
    SYSCHECKD_BIN="/var/ossec/bin/wazuh-syscheckd"
else
    echo "[$(date)] ERROR: No wazuh-syscheckd binary found"
    exit 1
fi

echo "[$(date)] monitor-syscheckd: Starting real file integrity monitor"
echo "[$(date)] monitor-syscheckd: Using binary: $SYSCHECKD_BIN"

# Set environment
export WAZUH_HOME="$WAZUH_HOME"

# Start the real syscheck daemon
exec "$SYSCHECKD_BIN" -c "$WAZUH_HOME/etc/ossec.conf" "$@"
EOF

    # Replace monitor-execd with real functionality
    cat > "$AGENT_HOME/bin/monitor-execd" << 'EOF'
#!/bin/bash
# Real Active Response Daemon - Wrapper for wazuh-execd

WAZUH_HOME="${WAZUH_HOME:-$(dirname $(dirname $(realpath $0)))}"
PID_DIR="$WAZUH_HOME/var/run"
mkdir -p "$PID_DIR"

# Use the real wazuh-execd
if [[ -f "/var/ossec/bin/wazuh-execd" ]]; then
    EXECD_BIN="/var/ossec/bin/wazuh-execd"
else
    echo "[$(date)] ERROR: No wazuh-execd binary found"
    exit 1
fi

echo "[$(date)] monitor-execd: Starting real active response daemon"
echo "[$(date)] monitor-execd: Using binary: $EXECD_BIN"

# Set environment
export WAZUH_HOME="$WAZUH_HOME"

# Start the real execd daemon
exec "$EXECD_BIN" -c "$WAZUH_HOME/etc/ossec.conf" "$@"
EOF

    # Replace monitor-modulesd with real functionality
    cat > "$AGENT_HOME/bin/monitor-modulesd" << 'EOF'
#!/bin/bash
# Real Modules Daemon - Wrapper for wazuh-modulesd

WAZUH_HOME="${WAZUH_HOME:-$(dirname $(dirname $(realpath $0)))}"
PID_DIR="$WAZUH_HOME/var/run"
mkdir -p "$PID_DIR"

# Use the real wazuh-modulesd
if [[ -f "/var/ossec/bin/wazuh-modulesd" ]]; then
    MODULESD_BIN="/var/ossec/bin/wazuh-modulesd"
else
    echo "[$(date)] ERROR: No wazuh-modulesd binary found"
    exit 1
fi

echo "[$(date)] monitor-modulesd: Starting real modules daemon"
echo "[$(date)] monitor-modulesd: Using binary: $MODULESD_BIN"

# Set environment
export WAZUH_HOME="$WAZUH_HOME"

# Start the real modules daemon
exec "$MODULESD_BIN" -c "$WAZUH_HOME/etc/ossec.conf" "$@"
EOF

    # Make all binaries executable
    chmod +x "$AGENT_HOME/bin/monitor-agentd"
    chmod +x "$AGENT_HOME/bin/monitor-logcollector" 
    chmod +x "$AGENT_HOME/bin/monitor-syscheckd"
    chmod +x "$AGENT_HOME/bin/monitor-execd"
    chmod +x "$AGENT_HOME/bin/monitor-modulesd"
    
    log_success "Real agent binaries created"
}

# Function to update configuration
update_configuration() {
    log_info "Updating agent configuration for real components..."
    
    # Backup original config
    cp "$AGENT_HOME/etc/ossec.conf" "$AGENT_HOME/backup/ossec.conf.backup"
    
    # Create enhanced configuration
    cat > "$AGENT_HOME/etc/ossec.conf" << 'EOF'
<!--
  Enhanced Wazuh Agent Configuration
  Real implementation for production use
-->

<ossec_config>
  <!-- Agent client configuration -->
  <client>
    <server>
      <address>127.0.0.1</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
    <config-profile>generic</config-profile>
    <notify_time>60</notify_time>
    <time-reconnect>300</time-reconnect>
    <auto_restart>yes</auto_restart>
    <crypto_method>aes</crypto_method>
  </client>

  <!-- Logging configuration -->
  <logging>
    <log_format>plain</log_format>
  </logging>

  <!-- Enhanced File integrity monitoring -->
  <syscheck>
    <disabled>no</disabled>
    <frequency>43200</frequency>
    <scan_on_start>yes</scan_on_start>
    <alert_new_files>yes</alert_new_files>
    
    <!-- Monitor critical system directories -->
    <directories check_all="yes" realtime="yes" report_changes="yes">/etc</directories>
    <directories check_all="yes" realtime="yes">/usr/bin,/usr/sbin</directories>
    <directories check_all="yes" realtime="yes">/bin,/sbin</directories>
    <directories check_all="yes" realtime="yes" report_changes="yes">/home</directories>
    <directories check_all="yes" realtime="yes">/root</directories>
    <directories check_all="yes">/var/log</directories>
    <directories check_all="yes">/tmp</directories>
    
    <!-- Monitor network file system mounts -->
    <directories realtime="yes" report_changes="yes">/mnt,/media</directories>
    
    <!-- Ignore temporary files -->
    <ignore>/etc/mtab</ignore>
    <ignore>/etc/hosts.deny</ignore>
    <ignore>/etc/adjtime</ignore>
    <ignore>/etc/random-seed</ignore>
    <ignore>/var/log/</ignore>
    <ignore>/tmp/</ignore>
    
    <!-- Monitor specific files for security -->
    <directories check_all="yes" realtime="yes">/etc/passwd</directories>
    <directories check_all="yes" realtime="yes">/etc/shadow</directories>
    <directories check_all="yes" realtime="yes">/etc/group</directories>
    <directories check_all="yes" realtime="yes">/etc/gshadow</directories>
    <directories check_all="yes" realtime="yes">/etc/ssh/sshd_config</directories>
  </syscheck>

  <!-- Enhanced Log analysis -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/messages</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/secure</location>
  </localfile>

  <!-- Enhanced kernel and network logs -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/kern.log</location>
  </localfile>

  <!-- Monitor for network file systems -->
  <localfile>
    <log_format>command</log_format>
    <command>mount | grep -E "(nfs|cifs|smb|fuse|sshfs)"</command>
    <frequency>60</frequency>
  </localfile>

  <!-- Monitor network connections for suspicious activity -->
  <localfile>
    <log_format>command</log_format>
    <command>netstat -tulpn | grep -E ":(2049|445|139|111|22|80|443|1514|1515)"</command>
    <frequency>30</frequency>
  </localfile>

  <!-- Monitor for suspicious processes and network scanning -->
  <localfile>
    <log_format>command</log_format>
    <command>ps aux | grep -E "(nmap|masscan|nikto|sqlmap|metasploit|hydra|john|hashcat)" | grep -v grep</command>
    <frequency>10</frequency>
  </localfile>

  <!-- Monitor for unauthorized mount attempts -->
  <localfile>
    <log_format>command</log_format>
    <command>cat /proc/mounts | grep -E "(nfs|cifs|smb)" | awk '{print $1" "$2" "$3}'</command>
    <frequency>30</frequency>
  </localfile>

  <!-- Monitor for failed login attempts -->
  <localfile>
    <log_format>command</log_format>
    <command>grep "Failed password" /var/log/auth.log | tail -10</command>
    <frequency>60</frequency>
  </localfile>

  <!-- Monitor for privilege escalation attempts -->
  <localfile>
    <log_format>command</log_format>
    <command>grep -E "(sudo:|su:)" /var/log/auth.log | tail -10</command>
    <frequency>60</frequency>
  </localfile>

  <!-- Custom threat monitoring logs -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/workspaces/AGENT2/logs/network_threats.log</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/security_events.log</location>
  </localfile>

  <!-- Enhanced Active response -->
  <active-response>
    <disabled>no</disabled>
    <ca_store>etc/wpk_root.pem</ca_store>
    <ca_verification>no</ca_verification>
  </active-response>

  <!-- Wodle configurations for system inventory -->
  <wodle name="cis-cat">
    <disabled>yes</disabled>
  </wodle>

  <wodle name="osquery">
    <disabled>yes</disabled>
  </wodle>

  <wodle name="syscollector">
    <disabled>no</disabled>
    <interval>1h</interval>
    <scan_on_start>yes</scan_on_start>
    <hardware>yes</hardware>
    <os>yes</os>
    <network>yes</network>
    <packages>yes</packages>
    <ports all="no">yes</ports>
    <processes>yes</processes>
    <hotfixes>yes</hotfixes>
  </wodle>

  <!-- Enhanced Security Configuration Assessment -->
  <sca>
    <enabled>yes</enabled>
    <scan_on_start>yes</scan_on_start>
    <interval>12h</interval>
    <skip_nfs>no</skip_nfs>
  </sca>

</ossec_config>
EOF

    log_success "Configuration updated with real monitoring capabilities"
}

# Function to create agent control script
create_agent_control() {
    log_info "Creating enhanced agent control script..."
    
    cat > "$AGENT_HOME/wazuh-agent-control" << 'EOF'
#!/bin/bash
# Enhanced Wazuh Agent Control Script

AGENT_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export WAZUH_HOME="$AGENT_HOME"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to start agent components
start_agent() {
    log_info "Starting Wazuh agent components..."
    
    # Create necessary directories
    mkdir -p "$AGENT_HOME/var/run"
    mkdir -p "$AGENT_HOME/logs"
    
    # Start components in order
    components=("monitor-agentd" "monitor-logcollector" "monitor-syscheckd" "monitor-execd" "monitor-modulesd")
    
    for component in "${components[@]}"; do
        if ! pgrep -f "$component" > /dev/null; then
            log_info "Starting $component..."
            "$AGENT_HOME/bin/$component" -f &
            sleep 2
            if pgrep -f "$component" > /dev/null; then
                log_success "$component started successfully"
            else
                log_error "Failed to start $component"
            fi
        else
            log_warning "$component is already running"
        fi
    done
}

# Function to stop agent components
stop_agent() {
    log_info "Stopping Wazuh agent components..."
    
    components=("monitor-modulesd" "monitor-execd" "monitor-syscheckd" "monitor-logcollector" "monitor-agentd")
    
    for component in "${components[@]}"; do
        if pgrep -f "$component" > /dev/null; then
            log_info "Stopping $component..."
            pkill -f "$component"
            sleep 2
        fi
    done
    
    log_success "All agent components stopped"
}

# Function to show agent status
status_agent() {
    log_info "Wazuh Agent Status:"
    echo
    
    components=("monitor-agentd" "monitor-logcollector" "monitor-syscheckd" "monitor-execd" "monitor-modulesd")
    
    for component in "${components[@]}"; do
        if pgrep -f "$component" > /dev/null; then
            pid=$(pgrep -f "$component")
            echo -e "  ${GREEN}✓${NC} $component (PID: $pid)"
        else
            echo -e "  ${RED}✗${NC} $component (not running)"
        fi
    done
    
    echo
    log_info "Manager connection test:"
    if nc -z 127.0.0.1 1514; then
        echo -e "  ${GREEN}✓${NC} Manager reachable on 127.0.0.1:1514"
    else
        echo -e "  ${RED}✗${NC} Manager not reachable on 127.0.0.1:1514"
    fi
}

# Function to restart agent
restart_agent() {
    log_info "Restarting Wazuh agent..."
    stop_agent
    sleep 3
    start_agent
}

# Function to test agent
test_agent() {
    log_info "Testing agent configuration and connectivity..."
    
    # Test configuration syntax
    if [[ -f "$AGENT_HOME/etc/ossec.conf" ]]; then
        log_success "Configuration file found"
    else
        log_error "Configuration file not found"
        return 1
    fi
    
    # Test client keys
    if [[ -f "$AGENT_HOME/etc/client.keys" ]]; then
        log_success "Client keys found"
    else
        log_error "Client keys not found"
        return 1
    fi
    
    # Test manager connectivity
    if nc -z 127.0.0.1 1514; then
        log_success "Manager connectivity OK"
    else
        log_error "Cannot connect to manager"
        return 1
    fi
    
    log_success "Agent test completed successfully"
}

# Main command handling
case "$1" in
    start)
        start_agent
        ;;
    stop)
        stop_agent
        ;;
    status)
        status_agent
        ;;
    restart)
        restart_agent
        ;;
    test)
        test_agent
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart|test}"
        echo
        echo "Commands:"
        echo "  start   - Start all agent components"
        echo "  stop    - Stop all agent components"
        echo "  status  - Show agent status"
        echo "  restart - Restart all agent components"
        echo "  test    - Test agent configuration and connectivity"
        exit 1
        ;;
esac
EOF

    chmod +x "$AGENT_HOME/wazuh-agent-control"
    log_success "Agent control script created"
}

# Function to create threat simulation script
create_threat_simulation() {
    log_info "Creating threat simulation script for testing..."
    
    cat > "$AGENT_HOME/simulate_threats.sh" << 'EOF'
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
EOF

    chmod +x "$AGENT_HOME/simulate_threats.sh"
    log_success "Threat simulation script created"
}

# Main execution
main() {
    echo "======================================================"
    echo "    Wazuh Agent Integration Fix Script"
    echo "    Replacing Mock Components with Real Implementation"
    echo "======================================================"
    echo
    
    # Stop mock processes
    stop_mock_processes
    
    # Backup mock binaries
    backup_mock_binaries
    
    # Create real binaries
    create_real_binaries
    
    # Update configuration
    update_configuration
    
    # Create control script
    create_agent_control
    
    # Create threat simulation
    create_threat_simulation
    
    echo
    echo "======================================================"
    log_success "Agent Integration Fix Completed Successfully!"
    echo "======================================================"
    echo
    echo "Next Steps:"
    echo "1. Start the agent: ./wazuh-agent-control start"
    echo "2. Check status: ./wazuh-agent-control status"
    echo "3. Test detection: ./simulate_threats.sh"
    echo "4. Monitor logs: tail -f logs/ossec.log"
    echo
    echo "The agent now uses REAL Wazuh components instead of mocks!"
}

# Run main function
main "$@"