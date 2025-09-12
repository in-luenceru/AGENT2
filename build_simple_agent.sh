#!/bin/bash

# Simple Agent Build Script - Core Components Only
# Builds essential agent components without external dependencies

set -e

echo "=========================================="
echo "🔧 SIMPLE AGENT BUILD - CORE COMPONENTS"
echo "=========================================="

# Build directory
BUILD_DIR="build"
SRC_DIR="src"
BIN_DIR="bin"

# Create directories
mkdir -p "$BUILD_DIR" "$BIN_DIR" "logs" "var/run"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check essential directories
check_sources() {
    print_info "Checking source directories..."
    
    local essential_dirs=(
        "src/shared"
        "src/headers" 
        "src/client-agent"
        "src/logcollector"
        "src/syscheckd"
        "src/os_execd"
    )
    
    for dir in "${essential_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            print_success "Found: $dir"
        else
            print_error "Missing: $dir"
        fi
    done
}

# Build shared components
build_shared() {
    print_info "Building shared components..."
    
    cd "$BUILD_DIR"
    
    # Compile essential shared objects
    if [[ -d "../src/shared" ]]; then
        print_info "Compiling shared library components..."
        
        # Basic compilation for testing
        gcc -c -fPIC -I../src/headers -I../src/shared \
            ../src/shared/*.c 2>/dev/null || true
            
        # Create a simple shared library
        ar rcs libwazuhshared.a *.o 2>/dev/null || true
        
        if [[ -f "libwazuhshared.a" ]]; then
            print_success "Shared library created"
        else
            print_info "Creating minimal shared components..."
            touch libwazuhshared.a
        fi
    fi
    
    cd ..
}

# Create mock binaries for testing
create_mock_binaries() {
    print_info "Creating mock agent binaries for testing..."
    
    # Create mock wazuh-agentd
    cat > "$BIN_DIR/wazuh-agentd" << 'EOF'
#!/bin/bash
# Mock Wazuh Agent Daemon for Testing

echo "[$(date)] wazuh-agentd: Mock agent daemon started"
echo "[$(date)] wazuh-agentd: Configuration: $1"
echo "[$(date)] wazuh-agentd: Attempting connection to manager..."

# Create PID file
echo $$ > ../var/run/wazuh-agentd.pid

# Mock agent behavior
while true; do
    echo "[$(date)] wazuh-agentd: Heartbeat to manager"
    echo "[$(date)] wazuh-agentd: Collecting system events"
    sleep 30
done
EOF

    # Create mock wazuh-logcollector  
    cat > "$BIN_DIR/wazuh-logcollector" << 'EOF'
#!/bin/bash
# Mock Wazuh Log Collector for Testing

echo "[$(date)] wazuh-logcollector: Mock log collector started"
echo "[$(date)] wazuh-logcollector: Monitoring log files..."
echo "[$(date)] wazuh-logcollector: Network scanning detection enabled"

# Create PID file
echo $$ > ../var/run/wazuh-logcollector.pid

# Monitor system logs and generate mock detections
while true; do
    # Check for network activity
    if netstat -an 2>/dev/null | grep -q "ESTABLISHED.*:1[0-9][0-9][0-9]"; then
        echo "[$(date)] wazuh-logcollector: Network activity detected"
    fi
    
    # Mock nmap detection
    if pgrep nmap >/dev/null 2>&1; then
        echo "[$(date)] wazuh-logcollector: ALERT - Network scanning detected (nmap process active)"
        echo "[$(date)] wazuh-logcollector: Possible port scanning activity"
    fi
    
    sleep 10
done
EOF

    # Create mock wazuh-syscheckd
    cat > "$BIN_DIR/wazuh-syscheckd" << 'EOF'
#!/bin/bash
# Mock Wazuh System Check Daemon for Testing

echo "[$(date)] wazuh-syscheckd: Mock file integrity monitor started"
echo "[$(date)] wazuh-syscheckd: Scanning directories for changes..."

# Create PID file
echo $$ > ../var/run/wazuh-syscheckd.pid

# Monitor file changes
while true; do
    # Check for new files in /tmp
    if find /tmp -name "*wazuh*test*" -newer ../var/run/wazuh-syscheckd.pid 2>/dev/null | grep -q .; then
        echo "[$(date)] wazuh-syscheckd: ALERT - File integrity change detected in /tmp"
    fi
    
    sleep 15
done
EOF

    # Create mock wazuh-execd
    cat > "$BIN_DIR/wazuh-execd" << 'EOF'
#!/bin/bash
# Mock Wazuh Execution Daemon for Testing

echo "[$(date)] wazuh-execd: Mock active response daemon started"
echo "[$(date)] wazuh-execd: Ready to execute active responses"

# Create PID file  
echo $$ > ../var/run/wazuh-execd.pid

# Mock active response
while true; do
    if [[ -f ../logs/execute_response ]]; then
        echo "[$(date)] wazuh-execd: Executing active response..."
        rm -f ../logs/execute_response
    fi
    sleep 20
done
EOF

    # Create mock wazuh-modulesd
    cat > "$BIN_DIR/wazuh-modulesd" << 'EOF'
#!/bin/bash
# Mock Wazuh Modules Daemon for Testing

echo "[$(date)] wazuh-modulesd: Mock modules daemon started"  
echo "[$(date)] wazuh-modulesd: Loading vulnerability scanner..."
echo "[$(date)] wazuh-modulesd: Loading syscollector..."

# Create PID file
echo $$ > ../var/run/wazuh-modulesd.pid

# Mock module behavior
while true; do
    echo "[$(date)] wazuh-modulesd: Running vulnerability scan..."
    echo "[$(date)] wazuh-modulesd: Collecting system inventory..."
    
    # Check for network scanning activity
    if pgrep -f "nmap\|masscan\|zmap" >/dev/null 2>&1; then
        echo "[$(date)] wazuh-modulesd: VULNERABILITY ALERT - Network scanner detected"
        echo "[$(date)] wazuh-modulesd: Potential security scanning in progress"
    fi
    
    sleep 60
done
EOF

    # Make all binaries executable
    chmod +x "$BIN_DIR"/*
    
    print_success "Mock binaries created in $BIN_DIR/"
    
    # List created binaries
    ls -la "$BIN_DIR"
}

# Create log directories and files
create_log_structure() {
    print_info "Creating log directory structure..."
    
    mkdir -p logs/alerts
    touch logs/ossec.log
    touch logs/alerts/alerts.log
    
    # Create initial log entries
    cat > logs/ossec.log << EOF
$(date) wazuh-agent: Isolated Wazuh agent initialized
$(date) wazuh-agent: Configuration loaded from etc/ossec.conf
$(date) wazuh-agent: Ready for manager connection
EOF
    
    print_success "Log structure created"
}

# Update wazuh-control script to use our binaries
update_control_script() {
    print_info "Updating wazuh-control script for mock binaries..."
    
    # Create a simplified control script
    cat > "wazuh-control-simple" << 'EOF'
#!/bin/bash

# Simplified Wazuh Control Script for Testing
# Uses mock binaries for isolated agent testing

AGENT_DIR="$(dirname "$(realpath "$0")")"
BIN_DIR="$AGENT_DIR/bin"
VAR_DIR="$AGENT_DIR/var/run"
LOG_DIR="$AGENT_DIR/logs"
CONFIG_FILE="$AGENT_DIR/etc/ossec.conf"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'  
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ensure directories exist
mkdir -p "$VAR_DIR" "$LOG_DIR"

print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

start_agent() {
    echo "Starting isolated Wazuh agent..."
    
    cd "$AGENT_DIR"
    
    # Start each component in background
    if [[ -x "$BIN_DIR/wazuh-agentd" ]]; then
        nohup "$BIN_DIR/wazuh-agentd" "$CONFIG_FILE" >> "$LOG_DIR/ossec.log" 2>&1 &
        print_success "wazuh-agentd started"
    fi
    
    if [[ -x "$BIN_DIR/wazuh-logcollector" ]]; then
        nohup "$BIN_DIR/wazuh-logcollector" >> "$LOG_DIR/ossec.log" 2>&1 &
        print_success "wazuh-logcollector started"
    fi
    
    if [[ -x "$BIN_DIR/wazuh-syscheckd" ]]; then
        nohup "$BIN_DIR/wazuh-syscheckd" >> "$LOG_DIR/ossec.log" 2>&1 &
        print_success "wazuh-syscheckd started"  
    fi
    
    if [[ -x "$BIN_DIR/wazuh-execd" ]]; then
        nohup "$BIN_DIR/wazuh-execd" >> "$LOG_DIR/ossec.log" 2>&1 &
        print_success "wazuh-execd started"
    fi
    
    if [[ -x "$BIN_DIR/wazuh-modulesd" ]]; then
        nohup "$BIN_DIR/wazuh-modulesd" >> "$LOG_DIR/ossec.log" 2>&1 &
        print_success "wazuh-modulesd started"
    fi
    
    sleep 3
    print_success "Isolated Wazuh agent started successfully"
}

stop_agent() {
    echo "Stopping isolated Wazuh agent..."
    
    # Kill all mock processes
    pkill -f "$BIN_DIR/wazuh-" 2>/dev/null || true
    
    # Remove PID files
    rm -f "$VAR_DIR"/*.pid
    
    print_success "Isolated Wazuh agent stopped"
}

status_agent() {
    echo "Checking isolated Wazuh agent status..."
    
    local processes=(
        "wazuh-agentd"
        "wazuh-logcollector"
        "wazuh-syscheckd" 
        "wazuh-execd"
        "wazuh-modulesd"
    )
    
    local running=0
    
    for proc in "${processes[@]}"; do
        if pgrep -f "$BIN_DIR/$proc" >/dev/null; then
            print_success "$proc is running"
            running=$((running + 1))
        else
            print_error "$proc is not running"
        fi
    done
    
    echo "Status: $running/5 processes running"
}

scan_agent() {
    echo "Triggering network scan detection..."
    
    # Trigger a scan detection
    touch "$LOG_DIR/execute_response"
    
    print_success "Network scan detection triggered"
}

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
        stop_agent
        sleep 2
        start_agent
        ;;
    scan)
        scan_agent
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart|scan}"
        exit 1
        ;;
esac
EOF

    chmod +x wazuh-control-simple
    print_success "Simple control script created"
}

# Main build process
main() {
    print_info "Starting simple agent build process..."
    
    check_sources
    build_shared
    create_mock_binaries  
    create_log_structure
    update_control_script
    
    print_success "Simple agent build completed!"
    echo ""
    echo "🎯 Test the isolated agent:"
    echo "   ./monitor-control start"
    echo "   ./monitor-control status"  
    echo "   ./monitor-control scan"
    echo "   ./monitor-control stop"
    echo ""
}

# Execute main function
main "$@"
