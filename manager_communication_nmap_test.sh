#!/bin/bash

# Isolated Agent Manager Communication & Nmap Detection Test
# Focused testing script for agent-manager connectivity and network scanning detection

echo "=========================================================="
echo "🔗 ISOLATED AGENT ↔️ MANAGER COMMUNICATION TEST"
echo "=========================================================="
echo "Date: $(date)"
echo "Testing: Agent-Manager connectivity & Nmap signal detection"
echo "=========================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
AGENT_DIR="$(pwd)"
MANAGER_IP="127.0.0.1"
MANAGER_PORT="1514"
TEST_LOG_DIR="$AGENT_DIR/manager_test_logs"
AGENT_CONFIG="$AGENT_DIR/etc/ossec.conf"

print_header() {
    echo -e "\n${PURPLE}🔍 === $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Setup test environment
setup_test_env() {
    print_header "SETUP TEST ENVIRONMENT"
    
    mkdir -p "$TEST_LOG_DIR"
    
    # Ensure we have a proper agent configuration
    print_info "Creating manager communication configuration..."
    
    cat > "$AGENT_CONFIG" << 'EOF'
<ossec_config>
    <client>
        <server>
            <address>127.0.0.1</address>
            <port>1514</port>
            <protocol>tcp</protocol>
        </server>
        <auto_restart>yes</auto_restart>
        <notify_time>60</notify_time>
        <time_reconnect>300</time_reconnect>
    </client>
    
    <logging>
        <log_format>plain</log_format>
    </logging>
    
    <!-- Network monitoring for nmap detection -->
    <wodle name="syscollector">
        <disabled>no</disabled>
        <interval>5m</interval>
        <scan_on_start>yes</scan_on_start>
        <network>yes</network>
        <ports>yes</ports>
        <processes>yes</processes>
    </wodle>
    
    <!-- File integrity monitoring -->
    <syscheck>
        <disabled>no</disabled>
        <frequency>120</frequency>
        <scan_on_start>yes</scan_on_start>
        <directories check_all="yes">/tmp</directories>
        <directories check_all="yes">/home</directories>
    </syscheck>
    
    <!-- Log collection for nmap detection -->
    <localfile>
        <log_format>syslog</log_format>
        <location>/var/log/syslog</location>
    </localfile>
    
    <localfile>
        <log_format>syslog</log_format>
        <location>/var/log/auth.log</location>
    </localfile>
    
    <!-- Kernel messages for network activity -->
    <localfile>
        <log_format>syslog</log_format>
        <location>/var/log/kern.log</location>
    </localfile>
</ossec_config>
EOF
    
    print_success "Configuration created"
    
    # Create agent key for authentication
    mkdir -p "$AGENT_DIR/etc"
    if [[ ! -f "$AGENT_DIR/etc/client.keys" ]]; then
        echo "001 isolated-agent any $(openssl rand -hex 32)" > "$AGENT_DIR/etc/client.keys"
        chmod 600 "$AGENT_DIR/etc/client.keys"
        print_success "Agent authentication key created"
    fi
}

# Test manager availability
test_manager_availability() {
    print_header "MANAGER AVAILABILITY CHECK"
    
    # Check if manager is running
    if pgrep -f "wazuh-remoted\|ossec-remoted" >/dev/null; then
        print_success "Wazuh manager (remoted) is running"
    else
        print_warning "Manager not detected - attempting to start system manager"
        if command -v /var/ossec/bin/wazuh-control >/dev/null; then
            sudo /var/ossec/bin/wazuh-control start >/dev/null 2>&1
            sleep 10
            if pgrep -f "wazuh-remoted\|ossec-remoted" >/dev/null; then
                print_success "Manager started successfully"
            else
                print_error "Failed to start manager"
            fi
        else
            print_error "No system manager available for testing"
        fi
    fi
    
    # Test port connectivity
    print_info "Testing TCP connection to manager..."
    if timeout 5 bash -c "</dev/tcp/$MANAGER_IP/$MANAGER_PORT" 2>/dev/null; then
        print_success "Manager is listening on $MANAGER_IP:$MANAGER_PORT"
    else
        print_error "Cannot connect to manager port $MANAGER_PORT"
        print_info "Available listening ports:"
        netstat -tlnp 2>/dev/null | grep ":151[0-9]" || print_warning "No Wazuh ports detected"
    fi
}

# Start isolated agent
start_isolated_agent() {
    print_header "STARTING ISOLATED AGENT"
    
    # Stop any existing agent processes
    print_info "Stopping existing agent processes..."
    sudo pkill -f "wazuh-.*" 2>/dev/null || true
    sleep 3
    
    # Start isolated agent
    print_info "Starting isolated agent services..."
    
    if [[ -x "./wazuh-control" ]]; then
        ./wazuh-control start > "$TEST_LOG_DIR/agent_start.log" 2>&1 &
        START_PID=$!
        sleep 8
        
        # Check if processes are running
        local processes=(
            "wazuh-agentd"
            "wazuh-logcollector"
            "wazuh-syscheckd"
            "wazuh-execd"
            "wazuh-modulesd"
        )
        
        local running_count=0
        for process in "${processes[@]}"; do
            if pgrep -f "$process" >/dev/null; then
                print_success "$process is running"
                running_count=$((running_count + 1))
            else
                print_error "$process is not running"
            fi
        done
        
        if [[ $running_count -ge 3 ]]; then
            print_success "Isolated agent started ($running_count/5 processes running)"
        else
            print_error "Isolated agent startup failed ($running_count/5 processes running)"
        fi
    else
        print_error "wazuh-control script not found or not executable"
    fi
}

# Test agent-manager communication
test_agent_manager_communication() {
    print_header "AGENT-MANAGER COMMUNICATION TEST"
    
    print_info "Monitoring agent-manager communication..."
    
    # Monitor agent logs for connection attempts
    local agent_log="$AGENT_DIR/logs/ossec.log"
    local connection_timeout=30
    
    if [[ -f "$agent_log" ]]; then
        # Get initial log size
        local initial_size=$(wc -l < "$agent_log" 2>/dev/null || echo "0")
        
        print_info "Waiting for agent-manager handshake (timeout: ${connection_timeout}s)..."
        
        # Wait for connection activity
        local elapsed=0
        local connected=false
        
        while [[ $elapsed -lt $connection_timeout ]]; do
            sleep 5
            elapsed=$((elapsed + 5))
            
            # Check for connection-related log entries
            if tail -n 50 "$agent_log" 2>/dev/null | grep -i "connect\|server\|manager\|authentication" >/dev/null; then
                print_success "Agent-manager communication activity detected"
                connected=true
                break
            fi
            
            print_info "Waiting... (${elapsed}/${connection_timeout}s)"
        done
        
        if [[ "$connected" = true ]]; then
            print_success "Agent successfully initiated communication with manager"
            
            # Show recent communication logs
            print_info "Recent communication logs:"
            tail -n 10 "$agent_log" 2>/dev/null | grep -i "connect\|server\|manager\|authentication" | head -5 || print_warning "No specific connection logs found"
        else
            print_warning "No clear agent-manager communication detected in logs"
        fi
        
        # Check final log size
        local final_size=$(wc -l < "$agent_log" 2>/dev/null || echo "0")
        local new_entries=$((final_size - initial_size))
        
        if [[ $new_entries -gt 0 ]]; then
            print_success "Agent generated $new_entries new log entries"
        else
            print_warning "No new log activity detected"
        fi
    else
        print_error "Agent log file not found: $agent_log"
    fi
}

# Generate test network traffic and scan detection
test_nmap_scan_detection() {
    print_header "NMAP SCAN DETECTION TEST"
    
    print_info "Generating network scanning activity for detection..."
    
    # Get baseline metrics
    local agent_log="$AGENT_DIR/logs/ossec.log"
    local alerts_log="$AGENT_DIR/logs/alerts/alerts.log"
    local initial_log_size=0
    local initial_alerts=0
    
    if [[ -f "$agent_log" ]]; then
        initial_log_size=$(wc -l < "$agent_log")
    fi
    
    if [[ -f "$alerts_log" ]]; then
        initial_alerts=$(wc -l < "$alerts_log")
    fi
    
    print_info "Baseline - Logs: $initial_log_size, Alerts: $initial_alerts"
    
    # Install nmap if needed
    if ! command -v nmap >/dev/null; then
        print_info "Installing nmap..."
        sudo apt-get update -qq && sudo apt-get install -y nmap >/dev/null 2>&1
    fi
    
    # Perform different types of scans
    print_info "Performing TCP SYN scan..."
    nmap -sS -p 1-100 127.0.0.1 > "$TEST_LOG_DIR/nmap_syn.log" 2>&1 &
    
    sleep 3
    
    print_info "Performing service detection scan..."  
    nmap -sV -p 22,80,443,1514 127.0.0.1 > "$TEST_LOG_DIR/nmap_service.log" 2>&1 &
    
    sleep 3
    
    print_info "Performing UDP scan..."
    sudo nmap -sU -p 53,67,161 127.0.0.1 > "$TEST_LOG_DIR/nmap_udp.log" 2>&1 &
    
    sleep 3
    
    print_info "Performing aggressive scan..."
    nmap -A -T4 -p 1-50 127.0.0.1 > "$TEST_LOG_DIR/nmap_aggressive.log" 2>&1 &
    
    # Wait for scans to complete
    print_info "Waiting for scans to complete..."
    sleep 15
    
    # Kill any remaining nmap processes
    sudo pkill nmap 2>/dev/null || true
    
    print_success "Network scanning tests completed"
    
    # Analyze detection results
    print_info "Analyzing scan detection results..."
    
    # Wait for log processing
    sleep 10
    
    # Check for new log entries
    local final_log_size=0
    local final_alerts=0
    
    if [[ -f "$agent_log" ]]; then
        final_log_size=$(wc -l < "$agent_log")
    fi
    
    if [[ -f "$alerts_log" ]]; then
        final_alerts=$(wc -l < "$alerts_log")
    fi
    
    local new_logs=$((final_log_size - initial_log_size))
    local new_alerts=$((final_alerts - initial_alerts))
    
    print_info "Results - New logs: $new_logs, New alerts: $new_alerts"
    
    # Check for nmap-specific detection
    if [[ $new_logs -gt 0 ]]; then
        print_success "Network activity generated log entries"
        
        # Look for scan-related keywords in logs
        if tail -n $new_logs "$agent_log" 2>/dev/null | grep -i "nmap\|scan\|probe\|port.*scan\|tcp.*connect\|network.*scan" >/dev/null; then
            print_success "Network scanning activity detected in logs!"
            
            print_info "Sample detection entries:"
            tail -n $new_logs "$agent_log" 2>/dev/null | grep -i "nmap\|scan\|probe" | head -3 || true
        else
            print_warning "No explicit nmap detection patterns found in logs"
        fi
    fi
    
    if [[ $new_alerts -gt 0 ]]; then
        print_success "Network scanning triggered $new_alerts alert(s)!"
        
        print_info "Sample alerts:"
        tail -n $new_alerts "$alerts_log" 2>/dev/null | head -3 || true
    else
        print_warning "No alerts generated from network scanning"
    fi
    
    # Generate additional detection patterns
    print_info "Generating additional detectable activities..."
    
    # Port knocking pattern
    for port in 22 80 443 1514 8080; do
        timeout 1 bash -c "</dev/tcp/127.0.0.1/$port" 2>/dev/null || true
    done
    
    # Rapid connection attempts
    for i in {1..5}; do
        timeout 1 telnet 127.0.0.1 22 </dev/null >/dev/null 2>&1 &
        sleep 0.2
    done
    
    print_success "Additional network patterns generated"
    
    # Final detection check
    sleep 5
    
    local final_final_logs=$(wc -l < "$agent_log" 2>/dev/null || echo "$final_log_size")
    local additional_logs=$((final_final_logs - final_log_size))
    
    if [[ $additional_logs -gt 0 ]]; then
        print_success "Additional network activity detected: $additional_logs new log entries"
    fi
}

# Test alert forwarding to manager
test_alert_forwarding() {
    print_header "ALERT FORWARDING TEST"
    
    print_info "Testing alert generation and forwarding to manager..."
    
    # Generate high-priority alerts that should be forwarded
    logger -p local0.alert "WAZUH_TEST: Critical security incident detected"
    logger -p auth.alert "WAZUH_TEST: Multiple failed login attempts from 192.168.1.100"
    logger -p kern.warning "WAZUH_TEST: Unusual network activity detected"
    
    # Create file changes that should trigger FIM alerts
    echo "Test file content" > /tmp/wazuh_manager_test_$$
    chmod 777 /tmp/wazuh_manager_test_$$
    echo "Modified content" >> /tmp/wazuh_manager_test_$$
    rm -f /tmp/wazuh_manager_test_$$
    
    print_success "Test alerts generated"
    
    # Monitor for alert processing and forwarding
    print_info "Monitoring alert processing (30s)..."
    
    sleep 30
    
    # Check local alert logs
    if [[ -f "logs/alerts/alerts.log" ]]; then
        local alert_count=$(grep -c "WAZUH_TEST" logs/alerts/alerts.log 2>/dev/null || echo "0")
        if [[ $alert_count -gt 0 ]]; then
            print_success "Local alert processing: $alert_count alerts detected"
        else
            print_warning "No local alerts found for test messages"
        fi
    fi
    
    # Check if manager received alerts (if accessible)
    if [[ -f "/var/ossec/logs/alerts/alerts.log" ]]; then
        local manager_alerts=$(grep -c "WAZUH_TEST" /var/ossec/logs/alerts/alerts.log 2>/dev/null || echo "0")
        if [[ $manager_alerts -gt 0 ]]; then
            print_success "Manager alert forwarding: $manager_alerts alerts received by manager"
        else
            print_warning "No test alerts found in manager logs"
        fi
    else
        print_info "Manager alert logs not accessible for verification"
    fi
}

# Generate comprehensive test report
generate_test_report() {
    print_header "GENERATING TEST REPORT"
    
    local report_file="$TEST_LOG_DIR/manager_communication_test_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
========================================================
ISOLATED AGENT ↔️ MANAGER COMMUNICATION TEST REPORT
========================================================
Test Date: $(date)
Agent Directory: $AGENT_DIR
Manager: $MANAGER_IP:$MANAGER_PORT

AGENT STATUS
============
$(./wazuh-control status 2>/dev/null || echo "Status check failed")

PROCESS STATUS
==============
$(pgrep -f "wazuh-" | while read pid; do echo "PID $pid: $(ps -p $pid -o comm= 2>/dev/null || echo 'unknown')"; done)

NETWORK CONNECTIVITY
====================
Manager Port Test: $(timeout 2 bash -c "</dev/tcp/$MANAGER_IP/$MANAGER_PORT" 2>/dev/null && echo "SUCCESS" || echo "FAILED")

LOG ANALYSIS
============
Total Agent Log Entries: $(wc -l < "$AGENT_DIR/logs/ossec.log" 2>/dev/null || echo "0")
Total Alert Entries: $(wc -l < "$AGENT_DIR/logs/alerts/alerts.log" 2>/dev/null || echo "0")

CONNECTION LOGS (Last 10):
$(tail -n 10 "$AGENT_DIR/logs/ossec.log" 2>/dev/null | grep -i "connect\|server\|manager" | head -5 || echo "No connection logs found")

DETECTION LOGS (Last 5):
$(tail -n 20 "$AGENT_DIR/logs/ossec.log" 2>/dev/null | grep -i "nmap\|scan\|probe" | head -5 || echo "No detection logs found")

TEST FILES GENERATED
====================
$(find "$TEST_LOG_DIR" -name "*.log" 2>/dev/null | head -10)

RECOMMENDATIONS
===============
EOF

    # Add recommendations based on test results
    if pgrep -f "wazuh-agentd" >/dev/null && timeout 2 bash -c "</dev/tcp/$MANAGER_IP/$MANAGER_PORT" >/dev/null 2>&1; then
        echo "✅ Agent-Manager communication is functional" >> "$report_file"
        echo "✅ Network connectivity is established" >> "$report_file"
    else
        echo "⚠️ Check agent-manager connectivity" >> "$report_file"
    fi
    
    if [[ -f "$AGENT_DIR/logs/ossec.log" ]] && [[ $(wc -l < "$AGENT_DIR/logs/ossec.log") -gt 10 ]]; then
        echo "✅ Agent is generating logs normally" >> "$report_file"
    else
        echo "⚠️ Low or no log activity - check agent configuration" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "For detailed test logs, check: $TEST_LOG_DIR" >> "$report_file"
    
    print_success "Test report generated: $report_file"
    
    # Display key findings
    print_header "TEST RESULTS SUMMARY"
    
    echo -e "${BLUE}🔗 Agent-Manager Connectivity:${NC}"
    if timeout 2 bash -c "</dev/tcp/$MANAGER_IP/$MANAGER_PORT" >/dev/null 2>&1; then
        echo -e "${GREEN}  ✅ Network connection: OK${NC}"
    else
        echo -e "${RED}  ❌ Network connection: FAILED${NC}"
    fi
    
    if pgrep -f "wazuh-agentd" >/dev/null; then
        echo -e "${GREEN}  ✅ Agent daemon: Running${NC}"
    else
        echo -e "${RED}  ❌ Agent daemon: Not running${NC}"
    fi
    
    echo -e "\n${BLUE}📊 Network Scanning Detection:${NC}"
    local scan_logs=$(grep -c "nmap\|scan\|probe" "$AGENT_DIR/logs/ossec.log" 2>/dev/null || echo "0")
    if [[ $scan_logs -gt 0 ]]; then
        echo -e "${GREEN}  ✅ Scan detection: $scan_logs events detected${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Scan detection: No events detected${NC}"
    fi
    
    echo -e "\n${BLUE}📈 Agent Activity:${NC}"
    local log_count=$(wc -l < "$AGENT_DIR/logs/ossec.log" 2>/dev/null || echo "0")
    echo -e "${GREEN}  ℹ️  Total log entries: $log_count${NC}"
    
    local alert_count=$(wc -l < "$AGENT_DIR/logs/alerts/alerts.log" 2>/dev/null || echo "0")
    echo -e "${GREEN}  ℹ️  Total alerts: $alert_count${NC}"
}

# Cleanup function
cleanup() {
    print_header "CLEANUP"
    
    print_info "Cleaning up test environment..."
    
    # Stop nmap processes
    sudo pkill nmap 2>/dev/null || true
    
    # Clean test files
    rm -f /tmp/wazuh_manager_test_* 2>/dev/null || true
    
    print_success "Cleanup completed"
}

# Main execution
main() {
    echo -e "${CYAN}🚀 Starting Manager Communication & Nmap Detection Test${NC}"
    
    # Setup trap for cleanup
    trap cleanup EXIT
    
    # Execute tests
    setup_test_env
    test_manager_availability  
    start_isolated_agent
    sleep 5
    test_agent_manager_communication
    test_nmap_scan_detection
    test_alert_forwarding
    generate_test_report
    
    echo -e "\n${PURPLE}🎯 Testing completed! Check the report for detailed results.${NC}"
}

# Run the main function
main "$@"
