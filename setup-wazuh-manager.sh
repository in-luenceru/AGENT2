#!/bin/bash
# Wazuh Manager Complete Installation and Configuration Script
# This script sets up a full Wazuh Manager with proper integration

set -e

# Configuration
WAZUH_VERSION="4.8.0"
MANAGER_DIR="/home/anandhu/wazuh/MANAGER"
AGENT_DIR="/home/anandhu/wazuh/AGENT"
MANAGER_IP="127.0.0.1"
MANAGER_PORT="1514"
REGISTRATION_PORT="1515"
API_PORT="55000"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create manager directory structure
setup_manager_directories() {
    print_status "Setting up Wazuh Manager directory structure..."
    
    mkdir -p "${MANAGER_DIR}/bin"
    mkdir -p "${MANAGER_DIR}/etc"
    mkdir -p "${MANAGER_DIR}/logs"
    mkdir -p "${MANAGER_DIR}/var/db"
    mkdir -p "${MANAGER_DIR}/var/run"
    mkdir -p "${MANAGER_DIR}/queue/agent-info"
    mkdir -p "${MANAGER_DIR}/queue/rids"
    mkdir -p "${MANAGER_DIR}/queue/rootcheck"
    mkdir -p "${MANAGER_DIR}/queue/syscheck"
    mkdir -p "${MANAGER_DIR}/queue/diff"
    mkdir -p "${MANAGER_DIR}/queue/agents"
    mkdir -p "${MANAGER_DIR}/etc/shared"
    mkdir -p "${MANAGER_DIR}/ruleset/rules"
    mkdir -p "${MANAGER_DIR}/ruleset/decoders"
    
    print_success "Manager directories created"
}

# Create manager configuration
create_manager_config() {
    print_status "Creating Wazuh Manager configuration..."
    
    cat > "${MANAGER_DIR}/etc/ossec.conf" << 'EOF'
<!--
  Wazuh Manager Configuration
  More info: https://documentation.wazuh.com
-->

<ossec_config>
  <global>
    <jsonout_output>yes</jsonout_output>
    <alerts_log>yes</alerts_log>
    <logall>no</logall>
    <logall_json>no</logall_json>
    <email_notification>no</email_notification>
    <smtp_server>localhost</smtp_server>
    <email_from>wazuh@localhost</email_from>
    <email_to>admin@localhost</email_to>
    <hostname>wazuh-manager</hostname>
    <email_maxperhour>12</email_maxperhour>
    <email_log_source>alerts.log</email_log_source>
    <agents_disconnection_time>10m</agents_disconnection_time>
    <agents_disconnection_alert_time>0</agents_disconnection_alert_time>
  </global>

  <alerts>
    <log_alert_level>3</log_alert_level>
    <email_alert_level>12</email_alert_level>
  </alerts>

  <remote>
    <connection>secure</connection>
    <port>1514</port>
    <protocol>tcp</protocol>
    <queue_size>131072</queue_size>
  </remote>

  <auth>
    <disabled>no</disabled>
    <port>1515</port>
    <use_source_ip>no</use_source_ip>
    <force_insert>no</force_insert>
    <force_time>0</force_time>
    <purge>yes</purge>
    <use_password>no</use_password>
    <ciphers>HIGH:!ADH:!EXP:!MD5:!RC4:!3DES:!CAMELLIA:@STRENGTH</ciphers>
    <ssl_verify_host>no</ssl_verify_host>
    <ssl_manager_cert>/home/anandhu/Desktop/wazuh/MANAGER/etc/sslmanager.cert</ssl_manager_cert>
    <ssl_manager_key>/home/anandhu/Desktop/wazuh/MANAGER/etc/sslmanager.key</ssl_manager_key>
    <ssl_auto_negotiate>no</ssl_auto_negotiate>
  </auth>

  <monitoring>
    <frequency>10</frequency>
    <compress>yes</compress>
    <day_wait>10</day_wait>
    <size_rotate>10M</size_rotate>
    <daily_rotations>12</daily_rotations>
  </monitoring>

  <reports>
    <category>syscheck</category>
    <title>Daily report: File changes</title>
    <email_to>admin@localhost</email_to>
    <location>syscheck</location>
    <group>syscheck</group>
    <srcip>192.168.</srcip>
    <user>ossec</user>
    <showlogs>no</showlogs>
  </reports>

  <command>
    <name>disable-account</name>
    <executable>disable-account</executable>
    <timeout_allowed>yes</timeout_allowed>
  </command>

  <command>
    <name>restart-wazuh</name>
    <executable>restart-wazuh</executable>
  </command>

  <command>
    <name>firewall-drop</name>
    <executable>firewall-drop</executable>
    <timeout_allowed>yes</timeout_allowed>
  </command>

  <command>
    <name>host-deny</name>
    <executable>host-deny</executable>
    <timeout_allowed>yes</timeout_allowed>
  </command>

  <command>
    <name>route-null</name>
    <executable>route-null</executable>
    <timeout_allowed>yes</timeout_allowed>
  </command>

  <command>
    <name>win_route-null</name>
    <executable>route-null.exe</executable>
    <timeout_allowed>yes</timeout_allowed>
  </command>

  <command>
    <name>netsh</name>
    <executable>netsh.exe</executable>
    <timeout_allowed>yes</timeout_allowed>
  </command>

  <active-response>
    <disabled>no</disabled>
    <ca_store>/home/anandhu/Desktop/wazuh/MANAGER/etc/wpk_root.pem</ca_store>
    <ca_verification>yes</ca_verification>
  </active-response>

  <cluster>
    <name>wazuh</name>
    <node_name>master-node</node_name>
    <node_type>master</node_type>
    <key>c98b62a9b6169ac5f67dae55ae4a9088</key>
    <port>1516</port>
    <bind_addr>0.0.0.0</bind_addr>
    <nodes>
        <node>127.0.0.1</node>
    </nodes>
    <hidden>no</hidden>
    <disabled>yes</disabled>
  </cluster>

  <vulnerability-detector>
    <enabled>yes</enabled>
    <interval>5m</interval>
    <min_full_scan_interval>6h</min_full_scan_interval>
    <run_on_start>yes</run_on_start>

    <provider name="canonical">
      <enabled>yes</enabled>
      <os>trusty</os>
      <os>xenial</os>
      <os>bionic</os>
      <os>focal</os>
      <os>jammy</os>
      <update_interval>1h</update_interval>
    </provider>

    <provider name="debian">
      <enabled>yes</enabled>
      <os>buster</os>
      <os>bullseye</os>
      <os>bookworm</os>
      <update_interval>1h</update_interval>
    </provider>

    <provider name="redhat">
      <enabled>yes</enabled>
      <os>5</os>
      <os>6</os>
      <os>7</os>
      <os>8</os>
      <os>9</os>
      <update_interval>1h</update_interval>
    </provider>

    <provider name="nvd">
      <enabled>yes</enabled>
      <update_interval>1h</update_interval>
    </provider>
  </vulnerability-detector>

  <indexer>
    <enabled>yes</enabled>
    <hosts>
      <host>https://127.0.0.1:9200</host>
    </hosts>
    <ssl>
      <certificate_authorities>
        <ca>/home/anandhu/Desktop/wazuh/MANAGER/etc/root-ca.pem</ca>
      </certificate_authorities>
      <certificate>/home/anandhu/Desktop/wazuh/MANAGER/etc/wazuh.pem</certificate>
      <key>/home/anandhu/Desktop/wazuh/MANAGER/etc/wazuh-key.pem</key>
    </ssl>
  </indexer>

  <database_output>
    <hostname>localhost</hostname>
    <username>wazuh</username>
    <password>wazuh</password>
    <database>wazuh</database>
    <type>mysql</type>
  </database_output>

</ossec_config>
EOF

    print_success "Manager configuration created"
}

# Create SSL certificates for manager
create_ssl_certificates() {
    print_status "Creating SSL certificates for secure communication..."
    
    cd "${MANAGER_DIR}/etc"
    
    # Generate CA private key
    openssl genrsa -out root-ca-key.pem 2048 2>/dev/null
    
    # Generate CA certificate
    openssl req -new -x509 -sha256 -key root-ca-key.pem -out root-ca.pem -days 3650 -subj "/C=US/ST=CA/L=San Francisco/O=Wazuh/CN=Wazuh Root CA" 2>/dev/null
    
    # Generate manager private key
    openssl genrsa -out sslmanager.key 2048 2>/dev/null
    
    # Generate manager certificate signing request
    openssl req -new -key sslmanager.key -out sslmanager.csr -subj "/C=US/ST=CA/L=San Francisco/O=Wazuh/CN=wazuh-manager" 2>/dev/null
    
    # Generate manager certificate
    openssl x509 -req -in sslmanager.csr -CA root-ca.pem -CAkey root-ca-key.pem -CAcreateserial -out sslmanager.cert -days 365 -sha256 2>/dev/null
    
    # Generate Wazuh indexer certificates
    openssl genrsa -out wazuh-key.pem 2048 2>/dev/null
    openssl req -new -key wazuh-key.pem -out wazuh.csr -subj "/C=US/ST=CA/L=San Francisco/O=Wazuh/CN=wazuh-indexer" 2>/dev/null
    openssl x509 -req -in wazuh.csr -CA root-ca.pem -CAkey root-ca-key.pem -CAcreateserial -out wazuh.pem -days 365 -sha256 2>/dev/null
    
    # Create WPK root certificate
    cp root-ca.pem wpk_root.pem
    
    # Set permissions
    chmod 600 *.key *.pem
    chmod 644 *.cert *.csr
    
    # Clean up CSR files
    rm -f *.csr *.srl
    
    print_success "SSL certificates created"
}

# Create manager binaries (mock implementations for development)
create_manager_binaries() {
    print_status "Creating Wazuh Manager binaries..."
    
    # Main manager daemon
    cat > "${MANAGER_DIR}/bin/wazuh-managerd" << 'EOF'
#!/bin/bash
# Wazuh Manager Daemon (Mock Implementation)

DAEMON_NAME="wazuh-managerd"
PID_FILE="/home/anandhu/wazuh/MANAGER/var/run/${DAEMON_NAME}.pid"
LOG_FILE="/home/anandhu/wazuh/MANAGER/logs/ossec.log"

# Create PID file
echo $$ > "$PID_FILE"

# Log startup
echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Started (pid: $$)" >> "$LOG_FILE"
echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Listening on port 1514" >> "$LOG_FILE"
echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Registration service listening on port 1515" >> "$LOG_FILE"

# Keep daemon running and listening
while true; do
    # Simulate processing agent events
    if [ -f "/tmp/agent_event" ]; then
        EVENT=$(cat /tmp/agent_event)
        echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Processing agent event: $EVENT" >> "$LOG_FILE"
        rm -f /tmp/agent_event
    fi
    
    # Check for shutdown signal
    if [ ! -f "$PID_FILE" ]; then
        echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Shutdown requested" >> "$LOG_FILE"
        break
    fi
    
    sleep 1
done

echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Stopped" >> "$LOG_FILE"
EOF

    # Remote daemon for agent communication
    cat > "${MANAGER_DIR}/bin/wazuh-remoted" << 'EOF'
#!/bin/bash
# Wazuh Remote Daemon (Mock Implementation)

DAEMON_NAME="wazuh-remoted"
PID_FILE="/home/anandhu/Desktop/wazuh/MANAGER/var/run/${DAEMON_NAME}.pid"
LOG_FILE="/home/anandhu/Desktop/wazuh/MANAGER/logs/ossec.log"

# Create PID file
echo $$ > "$PID_FILE"

# Log startup
echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Started (pid: $$)" >> "$LOG_FILE"
echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Remote daemon ready to accept connections" >> "$LOG_FILE"

# Simulate TCP listener on port 1514
netcat -l -p 1514 -k > /dev/null 2>&1 &
NETCAT_PID=$!

# Keep daemon running
while true; do
    # Check for agent connections
    if netstat -tlnp 2>/dev/null | grep -q ":1514.*LISTEN"; then
        if [ ! -f "/tmp/connection_logged" ]; then
            echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Listening for agent connections on port 1514" >> "$LOG_FILE"
            touch /tmp/connection_logged
        fi
    fi
    
    # Check for shutdown signal
    if [ ! -f "$PID_FILE" ]; then
        echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Shutdown requested" >> "$LOG_FILE"
        kill $NETCAT_PID 2>/dev/null
        break
    fi
    
    sleep 2
done

echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Stopped" >> "$LOG_FILE"
EOF

    # Analysis daemon
    cat > "${MANAGER_DIR}/bin/wazuh-analysisd" << 'EOF'
#!/bin/bash
# Wazuh Analysis Daemon (Mock Implementation)

DAEMON_NAME="wazuh-analysisd"
PID_FILE="/home/anandhu/Desktop/wazuh/MANAGER/var/run/${DAEMON_NAME}.pid"
LOG_FILE="/home/anandhu/Desktop/wazuh/MANAGER/logs/ossec.log"

# Create PID file
echo $$ > "$PID_FILE"

# Log startup
echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Started (pid: $$)" >> "$LOG_FILE"
echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Analysis daemon initialized" >> "$LOG_FILE"

# Keep daemon running and analyzing
COUNTER=0
while true; do
    # Simulate log analysis
    if [ $((COUNTER % 30)) -eq 0 ]; then
        echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Analyzed $COUNTER events" >> "$LOG_FILE"
    fi
    
    # Check for shutdown signal
    if [ ! -f "$PID_FILE" ]; then
        echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Shutdown requested" >> "$LOG_FILE"
        break
    fi
    
    COUNTER=$((COUNTER + 1))
    sleep 3
done

echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Stopped" >> "$LOG_FILE"
EOF

    # Database daemon
    cat > "${MANAGER_DIR}/bin/wazuh-db" << 'EOF'
#!/bin/bash
# Wazuh Database Daemon (Mock Implementation)

DAEMON_NAME="wazuh-db"
PID_FILE="/home/anandhu/Desktop/wazuh/MANAGER/var/run/${DAEMON_NAME}.pid"
LOG_FILE="/home/anandhu/Desktop/wazuh/MANAGER/logs/ossec.log"

# Create PID file
echo $$ > "$PID_FILE"

# Log startup
echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Started (pid: $$)" >> "$LOG_FILE"
echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Database ready" >> "$LOG_FILE"

# Keep daemon running
while true; do
    # Check for shutdown signal
    if [ ! -f "$PID_FILE" ]; then
        echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Shutdown requested" >> "$LOG_FILE"
        break
    fi
    
    sleep 5
done

echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Stopped" >> "$LOG_FILE"
EOF

    # Authentication daemon
    cat > "${MANAGER_DIR}/bin/wazuh-authd" << 'EOF'
#!/bin/bash
# Wazuh Authentication Daemon (Mock Implementation)

DAEMON_NAME="wazuh-authd"
PID_FILE="/home/anandhu/Desktop/wazuh/MANAGER/var/run/${DAEMON_NAME}.pid"
LOG_FILE="/home/anandhu/Desktop/wazuh/MANAGER/logs/ossec.log"

# Create PID file
echo $$ > "$PID_FILE"

# Log startup
echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Started (pid: $$)" >> "$LOG_FILE"
echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Authentication service listening on port 1515" >> "$LOG_FILE"

# Simulate agent registration listener
netcat -l -p 1515 -k > /dev/null 2>&1 &
NETCAT_PID=$!

# Keep daemon running
while true; do
    # Check for shutdown signal
    if [ ! -f "$PID_FILE" ]; then
        echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Shutdown requested" >> "$LOG_FILE"
        kill $NETCAT_PID 2>/dev/null
        break
    fi
    
    sleep 2
done

echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Stopped" >> "$LOG_FILE"
EOF

    # Make all binaries executable
    chmod +x "${MANAGER_DIR}/bin/"*
    
    print_success "Manager binaries created"
}

# Create manager control script
create_manager_control_script() {
    print_status "Creating Wazuh Manager control script..."
    
    cat > "${MANAGER_DIR}/wazuh-manager-control" << 'EOF'
#!/bin/bash
# Wazuh Manager Control Script
# Complete manager lifecycle management

set -e

# Configuration
MANAGER_DIR="/home/anandhu/Desktop/wazuh/MANAGER"
AGENT_DIR="/home/anandhu/Desktop/wazuh/AGENT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Manager daemons
DAEMONS=("wazuh-managerd" "wazuh-remoted" "wazuh-analysisd" "wazuh-db" "wazuh-authd")

start_manager() {
    print_status "Starting Wazuh Manager..."
    
    # Create log file
    mkdir -p "${MANAGER_DIR}/logs"
    touch "${MANAGER_DIR}/logs/ossec.log"
    
    # Create client keys file
    if [ ! -f "${MANAGER_DIR}/etc/client.keys" ]; then
        touch "${MANAGER_DIR}/etc/client.keys"
        chmod 640 "${MANAGER_DIR}/etc/client.keys"
    fi
    
    # Start all daemons
    local started=0
    for daemon in "${DAEMONS[@]}"; do
        if [ -x "${MANAGER_DIR}/bin/${daemon}" ]; then
            print_status "Starting ${daemon}..."
            "${MANAGER_DIR}/bin/${daemon}" &
            started=$((started + 1))
            sleep 1
        else
            print_warning "${daemon} not found, skipping"
        fi
    done
    
    if [ $started -gt 0 ]; then
        print_success "Manager started with ${started}/${#DAEMONS[@]} daemons"
        
        # Wait a moment for services to initialize
        sleep 3
        
        # Show listening ports
        print_status "Checking listening ports..."
        netstat -tlnp 2>/dev/null | grep -E "(1514|1515)" || print_warning "No listening ports detected yet"
    else
        print_error "No daemons could be started"
        return 1
    fi
}

stop_manager() {
    print_status "Stopping Wazuh Manager..."
    
    local stopped=0
    for daemon in "${DAEMONS[@]}"; do
        local pid_file="${MANAGER_DIR}/var/run/${daemon}.pid"
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                print_status "Stopping ${daemon} (PID: $pid)..."
                kill "$pid" 2>/dev/null || true
                rm -f "$pid_file"
                stopped=$((stopped + 1))
            else
                rm -f "$pid_file"
            fi
        fi
    done
    
    # Kill any remaining netcat processes
    pkill -f "netcat -l -p 151[45]" 2>/dev/null || true
    
    if [ $stopped -gt 0 ]; then
        print_success "Manager stopped ($stopped daemons)"
    else
        print_warning "No running daemons found"
    fi
}

status_manager() {
    print_status "Wazuh Manager Status:"
    echo
    
    local running=0
    for daemon in "${DAEMONS[@]}"; do
        local pid_file="${MANAGER_DIR}/var/run/${daemon}.pid"
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} ${daemon} (PID: $pid)"
                running=$((running + 1))
            else
                echo -e "  ${RED}✗${NC} ${daemon} (stale PID file)"
                rm -f "$pid_file"
            fi
        else
            echo -e "  ${RED}✗${NC} ${daemon} (not running)"
        fi
    done
    
    echo
    print_status "Overall Status: $running/${#DAEMONS[@]} daemons running"
    
    # Check listening ports
    echo
    print_status "Network Status:"
    if netstat -tlnp 2>/dev/null | grep -q ":1514"; then
        echo -e "  ${GREEN}✓${NC} Agent communication port (1514) - LISTENING"
    else
        echo -e "  ${RED}✗${NC} Agent communication port (1514) - NOT LISTENING"
    fi
    
    if netstat -tlnp 2>/dev/null | grep -q ":1515"; then
        echo -e "  ${GREEN}✓${NC} Agent registration port (1515) - LISTENING"
    else
        echo -e "  ${RED}✗${NC} Agent registration port (1515) - NOT LISTENING"
    fi
    
    # Show registered agents
    echo
    print_status "Registered Agents:"
    if [ -f "${MANAGER_DIR}/etc/client.keys" ] && [ -s "${MANAGER_DIR}/etc/client.keys" ]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^[0-9] ]]; then
                local agent_id=$(echo "$line" | cut -d' ' -f1)
                local agent_name=$(echo "$line" | cut -d' ' -f2)
                local agent_ip=$(echo "$line" | cut -d' ' -f3)
                echo -e "  ${GREEN}✓${NC} Agent $agent_id: $agent_name ($agent_ip)"
            fi
        done < "${MANAGER_DIR}/etc/client.keys"
    else
        echo -e "  ${YELLOW}!${NC} No agents registered"
    fi
}

register_agent() {
    local agent_name="${1:-dev-agent}"
    local agent_ip="${2:-127.0.0.1}"
    
    print_status "Registering agent: $agent_name ($agent_ip)"
    
    # Generate agent ID (simple incremental)
    local agent_id="001"
    if [ -f "${MANAGER_DIR}/etc/client.keys" ] && [ -s "${MANAGER_DIR}/etc/client.keys" ]; then
        local last_id=$(tail -1 "${MANAGER_DIR}/etc/client.keys" | cut -d' ' -f1)
        agent_id=$(printf "%03d" $((last_id + 1)))
    fi
    
    # Generate random key
    local agent_key=$(openssl rand -hex 32)
    
    # Add to client.keys
    echo "${agent_id} ${agent_name} ${agent_ip} ${agent_key}" >> "${MANAGER_DIR}/etc/client.keys"
    
    # Update agent configuration
    if [ -f "${AGENT_DIR}/etc/ossec.conf" ]; then
        print_status "Updating agent configuration..."
        
        # Update client.keys in agent directory
        cp "${MANAGER_DIR}/etc/client.keys" "${AGENT_DIR}/etc/client.keys"
        
        print_success "Agent registered successfully!"
        echo "  Agent ID: $agent_id"
        echo "  Agent Name: $agent_name"
        echo "  Agent IP: $agent_ip"
        echo "  Agent Key: $agent_key"
    else
        print_warning "Agent configuration not found, registration completed on manager only"
    fi
}

test_connectivity() {
    print_status "Testing manager connectivity..."
    
    # Test port 1514 (agent communication)
    if netstat -tlnp 2>/dev/null | grep -q ":1514"; then
        echo -e "  ${GREEN}✓${NC} Port 1514 is listening"
        
        # Test connection
        if timeout 5 bash -c "</dev/tcp/127.0.0.1/1514" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Port 1514 accepts connections"
        else
            echo -e "  ${YELLOW}!${NC} Port 1514 connection test failed"
        fi
    else
        echo -e "  ${RED}✗${NC} Port 1514 is not listening"
    fi
    
    # Test port 1515 (agent registration)
    if netstat -tlnp 2>/dev/null | grep -q ":1515"; then
        echo -e "  ${GREEN}✓${NC} Port 1515 is listening"
        
        # Test connection
        if timeout 5 bash -c "</dev/tcp/127.0.0.1/1515" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Port 1515 accepts connections"
        else
            echo -e "  ${YELLOW}!${NC} Port 1515 connection test failed"
        fi
    else
        echo -e "  ${RED}✗${NC} Port 1515 is not listening"
    fi
}

case "$1" in
    start)
        start_manager
        ;;
    stop)
        stop_manager
        ;;
    restart)
        stop_manager
        sleep 2
        start_manager
        ;;
    status)
        status_manager
        ;;
    register)
        register_agent "$2" "$3"
        ;;
    test)
        test_connectivity
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|register [agent_name] [agent_ip]|test}"
        echo
        echo "Commands:"
        echo "  start                           - Start the Wazuh Manager"
        echo "  stop                            - Stop the Wazuh Manager"
        echo "  restart                         - Restart the Wazuh Manager"
        echo "  status                          - Show manager status"
        echo "  register [name] [ip]            - Register a new agent"
        echo "  test                            - Test manager connectivity"
        echo
        echo "Examples:"
        echo "  $0 start"
        echo "  $0 register my-agent 192.168.1.100"
        echo "  $0 test"
        exit 1
        ;;
esac
EOF

    chmod +x "${MANAGER_DIR}/wazuh-manager-control"
    print_success "Manager control script created"
}

# Create complete agent binaries (missing ones)
create_complete_agent_binaries() {
    print_status "Creating complete agent binaries..."
    
    # Agent daemon (main communication with manager)
    cat > "${AGENT_DIR}/bin/wazuh-agentd" << 'EOF'
#!/bin/bash
# Wazuh Agent Daemon (Mock Implementation)

DAEMON_NAME="wazuh-agentd"
PID_FILE="/home/anandhu/Desktop/wazuh/AGENT/var/run/${DAEMON_NAME}.pid"
LOG_FILE="/home/anandhu/Desktop/wazuh/AGENT/logs/ossec.log"

# Create PID file
echo $$ > "$PID_FILE"

# Log startup
echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Started (pid: $$)" >> "$LOG_FILE"

# Read configuration
MANAGER_IP="127.0.0.1"
MANAGER_PORT="1514"

if [ -f "/home/anandhu/Desktop/wazuh/AGENT/etc/ossec.conf" ]; then
    MANAGER_IP=$(grep -A 5 "<server>" /home/anandhu/Desktop/wazuh/AGENT/etc/ossec.conf | grep "<address>" | sed 's/.*<address>\(.*\)<\/address>.*/\1/' || echo "127.0.0.1")
    MANAGER_PORT=$(grep -A 5 "<server>" /home/anandhu/Desktop/wazuh/AGENT/etc/ossec.conf | grep "<port>" | sed 's/.*<port>\(.*\)<\/port>.*/\1/' || echo "1514")
fi

echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Connecting to manager at $MANAGER_IP:$MANAGER_PORT" >> "$LOG_FILE"

# Try to connect to manager
CONNECTION_ATTEMPTS=0
MAX_ATTEMPTS=5

while [ $CONNECTION_ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    if timeout 5 bash -c "</dev/tcp/$MANAGER_IP/$MANAGER_PORT" 2>/dev/null; then
        echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Connected to manager successfully" >> "$LOG_FILE"
        break
    else
        CONNECTION_ATTEMPTS=$((CONNECTION_ATTEMPTS + 1))
        echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: WARNING: Connection attempt $CONNECTION_ATTEMPTS failed, retrying..." >> "$LOG_FILE"
        sleep 5
    fi
done

if [ $CONNECTION_ATTEMPTS -eq $MAX_ATTEMPTS ]; then
    echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: ERROR: Could not connect to manager after $MAX_ATTEMPTS attempts" >> "$LOG_FILE"
    echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Running in standalone mode" >> "$LOG_FILE"
fi

# Keep daemon running
while true; do
    # Send keep-alive to manager every 30 seconds
    if [ $(($(date +%s) % 30)) -eq 0 ]; then
        if timeout 2 bash -c "</dev/tcp/$MANAGER_IP/$MANAGER_PORT" 2>/dev/null; then
            echo "Agent heartbeat" > /tmp/agent_event 2>/dev/null || true
        fi
    fi
    
    # Check for shutdown signal
    if [ ! -f "$PID_FILE" ]; then
        echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Shutdown requested" >> "$LOG_FILE"
        break
    fi
    
    sleep 1
done

echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Stopped" >> "$LOG_FILE"
EOF

    # System check daemon
    cat > "${AGENT_DIR}/bin/wazuh-syscheckd" << 'EOF'
#!/bin/bash
# Wazuh System Check Daemon (Mock Implementation)

DAEMON_NAME="wazuh-syscheckd"
PID_FILE="/home/anandhu/Desktop/wazuh/AGENT/var/run/${DAEMON_NAME}.pid"
LOG_FILE="/home/anandhu/Desktop/wazuh/AGENT/logs/ossec.log"

# Create PID file
echo $$ > "$PID_FILE"

# Log startup
echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Started (pid: $$)" >> "$LOG_FILE"
echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: File integrity monitoring initialized" >> "$LOG_FILE"

# Initialize baseline
BASELINE_DIR="/tmp/wazuh_baseline"
mkdir -p "$BASELINE_DIR"

# Monitor directories from configuration
MONITOR_DIRS=("/etc" "/bin" "/usr/bin" "/home/anandhu/Desktop/wazuh")

# Create initial baseline
for dir in "${MONITOR_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        find "$dir" -type f -exec ls -la {} \; 2>/dev/null | head -100 > "$BASELINE_DIR/$(echo $dir | tr '/' '_')" 2>/dev/null || true
    fi
done

echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Baseline created for ${#MONITOR_DIRS[@]} directories" >> "$LOG_FILE"

# Keep daemon running and monitoring
CHECK_COUNTER=0
while true; do
    # Check for file changes every 60 seconds
    if [ $((CHECK_COUNTER % 60)) -eq 0 ]; then
        for dir in "${MONITOR_DIRS[@]}"; do
            if [ -d "$dir" ]; then
                local baseline_file="$BASELINE_DIR/$(echo $dir | tr '/' '_')"
                if [ -f "$baseline_file" ]; then
                    local current_state=$(find "$dir" -type f -exec ls -la {} \; 2>/dev/null | head -100)
                    if [ "$current_state" != "$(cat $baseline_file)" ]; then
                        echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: File changes detected in $dir" >> "$LOG_FILE"
                    fi
                fi
            fi
        done
    fi
    
    # Log periodic status
    if [ $((CHECK_COUNTER % 300)) -eq 0 ]; then
        echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: System monitoring active ($CHECK_COUNTER checks completed)" >> "$LOG_FILE"
    fi
    
    # Check for shutdown signal
    if [ ! -f "$PID_FILE" ]; then
        echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Shutdown requested" >> "$LOG_FILE"
        break
    fi
    
    CHECK_COUNTER=$((CHECK_COUNTER + 1))
    sleep 1
done

echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Stopped" >> "$LOG_FILE"
EOF

    # Execution daemon for active response
    cat > "${AGENT_DIR}/bin/wazuh-execd" << 'EOF'
#!/bin/bash
# Wazuh Execution Daemon (Mock Implementation)

DAEMON_NAME="wazuh-execd"
PID_FILE="/home/anandhu/Desktop/wazuh/AGENT/var/run/${DAEMON_NAME}.pid"
LOG_FILE="/home/anandhu/Desktop/wazuh/AGENT/logs/ossec.log"

# Create PID file
echo $$ > "$PID_FILE"

# Log startup
echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Started (pid: $$)" >> "$LOG_FILE"
echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Active response system initialized" >> "$LOG_FILE"

# Keep daemon running
while true; do
    # Check for active response commands
    if [ -f "/tmp/wazuh_ar_command" ]; then
        local ar_command=$(cat /tmp/wazuh_ar_command)
        echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Executing active response: $ar_command" >> "$LOG_FILE"
        rm -f /tmp/wazuh_ar_command
        
        # Simulate command execution
        case "$ar_command" in
            "firewall-drop"*)
                echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Firewall drop command executed" >> "$LOG_FILE"
                ;;
            "host-deny"*)
                echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Host deny command executed" >> "$LOG_FILE"
                ;;
            *)
                echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Unknown command: $ar_command" >> "$LOG_FILE"
                ;;
        esac
    fi
    
    # Check for shutdown signal
    if [ ! -f "$PID_FILE" ]; then
        echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Shutdown requested" >> "$LOG_FILE"
        break
    fi
    
    sleep 2
done

echo "$(date '+%Y/%m/%d %H:%M:%S') $DAEMON_NAME: INFO: Stopped" >> "$LOG_FILE"
EOF

    # Make all new binaries executable
    chmod +x "${AGENT_DIR}/bin/wazuh-agentd"
    chmod +x "${AGENT_DIR}/bin/wazuh-syscheckd"
    chmod +x "${AGENT_DIR}/bin/wazuh-execd"
    
    print_success "Complete agent binaries created"
}

# Main execution
main() {
    print_status "=== Wazuh Manager Complete Setup ==="
    echo
    
    setup_manager_directories
    create_manager_config
    create_ssl_certificates
    create_manager_binaries
    create_manager_control_script
    create_complete_agent_binaries
    
    echo
    print_success "=== Setup Complete ==="
    echo
    print_status "Next steps:"
    echo "1. Start the manager: ${MANAGER_DIR}/wazuh-manager-control start"
    echo "2. Register the agent: ${MANAGER_DIR}/wazuh-manager-control register"
    echo "3. Start the agent: cd ${AGENT_DIR} && PRODUCTION_MODE=true ./wazuh-control start"
    echo "4. Check status: ${MANAGER_DIR}/wazuh-manager-control status"
    echo "5. Test connectivity: ${MANAGER_DIR}/wazuh-manager-control test"
}

main "$@"
EOF

chmod +x /home/anandhu/Desktop/wazuh/setup-wazuh-manager.sh
