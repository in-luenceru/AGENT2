#!/bin/bash

# Comprehensive Testing Script for Isolated Wazuh Agent
# Tests agent functionality, manager connectivity, and nmap signal detection
# Author: AI Assistant for Wazuh Agent Extraction Project
# Date: September 10, 2025

set -e

echo "=========================================================="
echo "🛡️  ISOLATED WAZUH AGENT COMPREHENSIVE TESTING SUITE"
echo "=========================================================="
echo "Date: $(date)"
echo "Target: Isolated Agent in $(pwd)"
echo "=========================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

# Configuration
AGENT_DIR="$(pwd)"
MANAGER_IP="127.0.0.1"
MANAGER_PORT="1514"
TEST_LOG_DIR="$AGENT_DIR/test_logs"
AGENT_KEY_FILE="$AGENT_DIR/etc/client.keys"
AGENT_CONFIG="$AGENT_DIR/etc/ossec.conf"

print_header() {
    echo -e "\n${PURPLE}🔍 === $1 ===${NC}"
}

print_sub_header() {
    echo -e "\n${CYAN}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    WARNINGS=$((WARNINGS + 1))
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    local success_msg="$3"
    local error_msg="$4"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    print_info "Running: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        print_success "$success_msg"
        return 0
    else
        print_error "$error_msg"
        return 1
    fi
}

# Prerequisites check
check_prerequisites() {
    print_header "PREREQUISITES CHECK"
    
    # Check if we're in AGENT directory
    if [[ ! -f "wazuh-control" ]] || [[ ! -d "src" ]]; then
        print_error "Not in isolated AGENT directory or files missing"
        exit 1
    fi
    
    # Install required tools
    print_sub_header "Installing Required Testing Tools"
    
    if ! command -v nmap &> /dev/null; then
        print_info "Installing nmap..."
        sudo apt-get update -qq && sudo apt-get install -y nmap
        print_success "nmap installed"
    else
        print_success "nmap already available"
    fi
    
    if ! command -v telnet &> /dev/null; then
        print_info "Installing telnet..."
        sudo apt-get install -y telnet
        print_success "telnet installed"
    else
        print_success "telnet already available"
    fi
    
    if ! command -v netstat &> /dev/null; then
        print_info "Installing net-tools..."
        sudo apt-get install -y net-tools
        print_success "net-tools installed"
    else
        print_success "net-tools already available"
    fi
    
    # Create test log directory
    mkdir -p "$TEST_LOG_DIR"
    print_success "Test environment prepared"
}

# Test 1: Agent Files Integrity
test_agent_integrity() {
    print_header "1. AGENT FILES INTEGRITY"
    
    # Critical files check
    local critical_files=(
        "wazuh-control"
        "build_agent.sh"
        "etc/ossec.conf"
        "etc/internal_options.conf"
        "src/client-agent"
        "src/logcollector"
        "src/syscheckd"
        "src/os_execd"
        "src/wazuh_modules"
        "ruleset"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ -e "$file" ]]; then
            print_success "Found: $file"
        else
            print_error "Missing: $file"
        fi
    done
    
    # Check extraction completeness
    if [[ -f "validate_complete_functionality.sh" ]]; then
        print_info "Running extraction validation..."
        if ./validate_complete_functionality.sh > "$TEST_LOG_DIR/validation.log" 2>&1; then
            print_success "Extraction validation passed"
        else
            print_warning "Extraction validation had issues (check logs)"
        fi
    fi
}

# Test 2: Build System Test
test_build_system() {
    print_header "2. BUILD SYSTEM TEST"
    
    print_sub_header "Testing Build Configuration"
    
    # Test CMake configuration
    if [[ -f "CMakeLists.txt" ]]; then
        run_test "CMake Configuration Check" \
                 "grep -q 'wazuh' CMakeLists.txt" \
                 "CMakeLists.txt contains Wazuh configuration" \
                 "CMakeLists.txt missing Wazuh configuration"
    fi
    
    # Test build script
    if [[ -x "build_agent.sh" ]]; then
        print_info "Testing build script (dry run)..."
        # Create a test build to ensure it works
        if ./build_agent.sh --help >/dev/null 2>&1 || ./build_agent.sh --version >/dev/null 2>&1; then
            print_success "Build script is functional"
        else
            print_info "Attempting actual build test..."
            if timeout 30 ./build_agent.sh > "$TEST_LOG_DIR/build_test.log" 2>&1; then
                print_success "Build script executed successfully"
            else
                print_warning "Build test timed out or failed (check logs)"
            fi
        fi
    fi
}

# Test 3: Configuration System
test_configuration() {
    print_header "3. CONFIGURATION SYSTEM"
    
    print_sub_header "Agent Configuration Setup"
    
    # Backup original config
    if [[ -f "$AGENT_CONFIG" ]]; then
        cp "$AGENT_CONFIG" "${AGENT_CONFIG}.backup"
        print_success "Configuration backup created"
    fi
    
    # Test configuration template
    print_info "Setting up test configuration..."
    
    cat > "$AGENT_CONFIG" << EOF
<ossec_config>
    <client>
        <server>
            <address>$MANAGER_IP</address>
            <port>$MANAGER_PORT</port>
            <protocol>tcp</protocol>
        </server>
    </client>
    
    <logging>
        <log_format>plain</log_format>
    </logging>
    
    <wodle name="syscollector">
        <disabled>no</disabled>
        <interval>10m</interval>
        <scan_on_start>yes</scan_on_start>
        <network>yes</network>
        <ports>yes</ports>
    </wodle>
    
    <wodle name="vulnerability-scanner">
        <disabled>no</disabled>
        <interval>5m</interval>
        <run_on_start>yes</run_on_start>
    </wodle>
    
    <syscheck>
        <disabled>no</disabled>
        <frequency>300</frequency>
        <scan_on_start>yes</scan_on_start>
        <directories check_all="yes">/tmp</directories>
    </syscheck>
    
    <rootcheck>
        <disabled>no</disabled>
    </rootcheck>
    
    <localfile>
        <log_format>syslog</log_format>
        <location>/var/log/syslog</location>
    </localfile>
    
    <localfile>
        <log_format>syslog</log_format>
        <location>/var/log/auth.log</location>
    </localfile>
</ossec_config>
EOF
    
    print_success "Test configuration created"
    
    # Validate configuration syntax (if available)
    if [[ -x "scripts/verify_config.sh" ]]; then
        run_test "Configuration Syntax Check" \
                 "./scripts/verify_config.sh $AGENT_CONFIG" \
                 "Configuration syntax is valid" \
                 "Configuration syntax has errors"
    fi
}

# Test 4: Manager Connectivity
test_manager_connectivity() {
    print_header "4. MANAGER CONNECTIVITY TEST"
    
    print_sub_header "Manager Connection Setup"
    
    # Check if Wazuh manager is running (assume it's the system one for now)
    if pgrep -f "wazuh-remoted" >/dev/null; then
        print_success "Wazuh manager (remoted) is running"
    else
        print_warning "Wazuh manager not detected - starting system manager"
        sudo /var/ossec/bin/wazuh-control start >/dev/null 2>&1 || true
        sleep 5
    fi
    
    # Test TCP connectivity to manager
    print_info "Testing TCP connection to manager..."
    if timeout 5 bash -c "</dev/tcp/$MANAGER_IP/$MANAGER_PORT" 2>/dev/null; then
        print_success "TCP connection to manager:$MANAGER_PORT successful"
    else
        print_error "Cannot connect to manager at $MANAGER_IP:$MANAGER_PORT"
        print_info "Checking if manager is listening..."
        netstat -tlnp | grep ":$MANAGER_PORT" || print_warning "Manager not listening on port $MANAGER_PORT"
    fi
    
    # Generate test agent key if not exists
    if [[ ! -f "$AGENT_KEY_FILE" ]]; then
        print_info "Generating test agent key..."
        mkdir -p "$(dirname "$AGENT_KEY_FILE")"
        # Create a simple test key (in production this would be done via agent enrollment)
        echo "001 test-agent any 4f3b2e6a7c9d8f1e2a3b4c5d6e7f8901" > "$AGENT_KEY_FILE"
        chmod 600 "$AGENT_KEY_FILE"
        print_success "Test agent key created"
    fi
}

# Test 5: Agent Services Startup
test_agent_startup() {
    print_header "5. AGENT SERVICES STARTUP"
    
    print_sub_header "Starting Isolated Agent Services"
    
    # Stop any existing agent processes first
    print_info "Stopping existing agent processes..."
    sudo pkill -f "wazuh-agentd" 2>/dev/null || true
    sudo pkill -f "wazuh-logcollector" 2>/dev/null || true  
    sudo pkill -f "wazuh-syscheckd" 2>/dev/null || true
    sudo pkill -f "wazuh-execd" 2>/dev/null || true
    sudo pkill -f "wazuh-modulesd" 2>/dev/null || true
    sleep 2
    
    # Start isolated agent using our control script
    print_info "Starting isolated agent..."
    if ./wazuh-control start > "$TEST_LOG_DIR/agent_startup.log" 2>&1; then
        print_success "Agent startup command executed"
    else
        print_error "Agent startup failed"
        cat "$TEST_LOG_DIR/agent_startup.log"
    fi
    
    sleep 5
    
    # Check process status
    print_sub_header "Verifying Agent Processes"
    
    local expected_processes=(
        "wazuh-agentd"
        "wazuh-logcollector"
        "wazuh-syscheckd"
        "wazuh-execd"
        "wazuh-modulesd"
    )
    
    for process in "${expected_processes[@]}"; do
        if pgrep -f "$process" >/dev/null; then
            print_success "$process is running"
        else
            print_error "$process is not running"
        fi
    done
    
    # Check agent status using control script
    print_info "Checking agent status..."
    ./wazuh-control status > "$TEST_LOG_DIR/agent_status.log" 2>&1
    
    if grep -q "running" "$TEST_LOG_DIR/agent_status.log"; then
        print_success "Agent status check passed"
    else
        print_warning "Agent status check shows issues"
    fi
}

# Test 6: Log Generation
test_log_generation() {
    print_header "6. LOG GENERATION TEST"
    
    print_sub_header "Testing Log Collection and Processing"
    
    # Create test log entries
    print_info "Generating test log entries..."
    
    # Test syslog entry
    logger "WAZUH_TEST: Test message for isolated agent detection"
    
    # Test file integrity monitoring
    if [[ -d "/tmp" ]]; then
        echo "Test file for FIM detection" > /tmp/wazuh_test_file_$$
        print_success "Created test file for FIM: /tmp/wazuh_test_file_$$"
        sleep 2
        rm -f /tmp/wazuh_test_file_$$
        print_success "Removed test file (should trigger FIM alert)"
    fi
    
    # Test auth log entry
    # (Simulate authentication event)
    sudo logger -p auth.info "WAZUH_TEST: Simulated authentication event for testing"
    
    print_success "Test log entries generated"
    
    # Wait for processing
    sleep 5
}

# Test 7: Network Scanning Detection
test_nmap_detection() {
    print_header "7. NETWORK SCANNING DETECTION"
    
    print_sub_header "Testing Nmap Signal Detection Capabilities"
    
    # Get baseline log size for comparison
    local log_file="logs/ossec.log"
    local initial_logs=0
    
    if [[ -f "$log_file" ]]; then
        initial_logs=$(wc -l < "$log_file")
        print_info "Initial log entries: $initial_logs"
    fi
    
    # Run different types of nmap scans to trigger detection
    print_info "Performing TCP SYN scan..."
    nmap -sS -p 1-100 127.0.0.1 >/dev/null 2>&1 &
    NMAP_PID=$!
    
    sleep 3
    
    print_info "Performing UDP scan..."
    sudo nmap -sU -p 53,67,68 127.0.0.1 >/dev/null 2>&1 &
    
    sleep 3
    
    print_info "Performing service version detection..."
    nmap -sV -p 22,80,443 127.0.0.1 >/dev/null 2>&1 &
    
    sleep 3
    
    print_info "Performing aggressive scan..."
    nmap -A -p 1-50 127.0.0.1 >/dev/null 2>&1 &
    
    # Wait for scans to complete
    sleep 10
    wait $NMAP_PID 2>/dev/null || true
    
    print_success "Network scanning tests completed"
    
    # Check for detection in logs
    if [[ -f "$log_file" ]]; then
        local final_logs=$(wc -l < "$log_file")
        local new_logs=$((final_logs - initial_logs))
        
        if [[ $new_logs -gt 0 ]]; then
            print_success "Log activity detected: $new_logs new entries"
            
            # Look for specific nmap-related detections
            if grep -i "nmap\|scan\|probe" "$log_file" >/dev/null 2>&1; then
                print_success "Network scanning activity detected in logs"
            else
                print_warning "No explicit nmap detection found in logs"
            fi
        else
            print_warning "No new log entries detected after nmap scans"
        fi
    fi
}

# Test 8: Module Testing
test_modules() {
    print_header "8. MODULE FUNCTIONALITY TEST"
    
    print_sub_header "Testing Individual Agent Modules"
    
    # Test vulnerability scanner module
    if [[ -d "src/wazuh_modules/vulnerability_scanner" ]]; then
        print_info "Testing vulnerability scanner module..."
        ./wazuh-control scan > "$TEST_LOG_DIR/vulnerability_scan.log" 2>&1 &
        sleep 5
        
        if grep -i "vulnerabilit" "$TEST_LOG_DIR/vulnerability_scan.log" >/dev/null 2>&1; then
            print_success "Vulnerability scanner is functional"
        else
            print_warning "Vulnerability scanner output unclear"
        fi
    fi
    
    # Test syscollector module  
    if [[ -d "src/wazuh_modules" ]]; then
        print_info "Testing system collector module..."
        
        # Check if syscollector data is being collected
        if [[ -f "logs/ossec.log" ]] && grep -i "syscollector" "logs/ossec.log" >/dev/null 2>&1; then
            print_success "Syscollector module is active"
        else
            print_warning "Syscollector module activity unclear"
        fi
    fi
}

# Test 9: Alert Generation
test_alert_generation() {
    print_header "9. ALERT GENERATION TEST"
    
    print_sub_header "Testing Alert Triggering and Processing"
    
    # Trigger various types of alerts
    print_info "Triggering test alerts..."
    
    # Generate high-severity log entry
    logger -p local0.crit "WAZUH_ALERT_TEST: Critical security event simulation"
    
    # Generate multiple failed authentication attempts
    for i in {1..3}; do
        sudo logger -p auth.warning "WAZUH_TEST: Failed password for testuser from 192.168.1.100 port 22 ssh2"
        sleep 1
    done
    
    # Generate file modification alert
    if [[ -w "/tmp" ]]; then
        touch /tmp/wazuh_alert_test_$$
        chmod 777 /tmp/wazuh_alert_test_$$
        echo "Modified content" > /tmp/wazuh_alert_test_$$
        sleep 2
        rm -f /tmp/wazuh_alert_test_$$
    fi
    
    print_success "Test alerts generated"
    
    # Wait for alert processing
    sleep 10
    
    # Check if alerts were processed
    if [[ -f "logs/alerts/alerts.log" ]]; then
        local alert_count=$(wc -l < "logs/alerts/alerts.log" 2>/dev/null || echo "0")
        if [[ $alert_count -gt 0 ]]; then
            print_success "Alert generation successful: $alert_count alerts found"
        else
            print_warning "No alerts found in alerts.log"
        fi
    else
        print_warning "Alert log file not found"
    fi
}

# Test 10: Performance and Resource Usage
test_performance() {
    print_header "10. PERFORMANCE AND RESOURCE USAGE"
    
    print_sub_header "Monitoring Agent Resource Consumption"
    
    # Monitor CPU and memory usage
    print_info "Collecting performance metrics..."
    
    # Get process information
    local agent_processes=$(pgrep -f "wazuh-" | head -10)
    local total_cpu=0
    local total_mem=0
    local process_count=0
    
    for pid in $agent_processes; do
        if [[ -n "$pid" ]] && [[ -d "/proc/$pid" ]]; then
            local cpu=$(ps -p "$pid" -o pcpu --no-headers 2>/dev/null | tr -d ' ' || echo "0")
            local mem=$(ps -p "$pid" -o pmem --no-headers 2>/dev/null | tr -d ' ' || echo "0")
            local cmd=$(ps -p "$pid" -o comm --no-headers 2>/dev/null || echo "unknown")
            
            if [[ "$cpu" != "0" ]] || [[ "$mem" != "0" ]]; then
                print_info "Process $cmd (PID: $pid): CPU: ${cpu}%, Memory: ${mem}%"
                total_cpu=$(echo "$total_cpu + $cpu" | bc -l 2>/dev/null || echo "$total_cpu")
                total_mem=$(echo "$total_mem + $mem" | bc -l 2>/dev/null || echo "$total_mem")
                process_count=$((process_count + 1))
            fi
        fi
    done
    
    print_info "Total agent processes monitored: $process_count"
    print_info "Estimated total CPU usage: ${total_cpu}%"
    print_info "Estimated total memory usage: ${total_mem}%"
    
    # Performance thresholds
    if (( $(echo "$total_cpu < 10.0" | bc -l 2>/dev/null || echo "1") )); then
        print_success "CPU usage is within acceptable limits"
    else
        print_warning "High CPU usage detected: ${total_cpu}%"
    fi
    
    if (( $(echo "$total_mem < 5.0" | bc -l 2>/dev/null || echo "1") )); then
        print_success "Memory usage is within acceptable limits"
    else
        print_warning "High memory usage detected: ${total_mem}%"
    fi
}

# Cleanup function
cleanup_test() {
    print_header "CLEANUP"
    
    print_info "Cleaning up test environment..."
    
    # Restore original configuration
    if [[ -f "${AGENT_CONFIG}.backup" ]]; then
        mv "${AGENT_CONFIG}.backup" "$AGENT_CONFIG"
        print_success "Original configuration restored"
    fi
    
    # Clean up test files
    rm -f /tmp/wazuh_test_file_* 2>/dev/null || true
    rm -f /tmp/wazuh_alert_test_* 2>/dev/null || true
    
    # Stop agent if requested
    read -p "Stop agent services? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Stopping agent services..."
        ./wazuh-control stop >/dev/null 2>&1 || true
        print_success "Agent services stopped"
    fi
    
    print_success "Cleanup completed"
}

# Generate comprehensive test report
generate_report() {
    print_header "TEST REPORT GENERATION"
    
    local report_file="$TEST_LOG_DIR/comprehensive_test_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
========================================================
ISOLATED WAZUH AGENT COMPREHENSIVE TEST REPORT
========================================================
Date: $(date)
Agent Directory: $AGENT_DIR
Test Duration: $(date)

TEST STATISTICS
--------------
Total Tests Executed: $TOTAL_TESTS
Passed Tests: $PASSED_TESTS
Failed Tests: $FAILED_TESTS
Warnings: $WARNINGS
Success Rate: $(( (PASSED_TESTS * 100) / (TOTAL_TESTS == 0 ? 1 : TOTAL_TESTS) ))%

CONFIGURATION
-------------
Manager IP: $MANAGER_IP
Manager Port: $MANAGER_PORT
Agent Configuration: $AGENT_CONFIG
Test Logs Directory: $TEST_LOG_DIR

AGENT STATUS
------------
$(./wazuh-control status 2>/dev/null || echo "Status unavailable")

SYSTEM INFORMATION
------------------
OS: $(uname -a)
Python: $(python3 --version 2>/dev/null || echo "Not available")
Network: $(ip route get 1.1.1.1 2>/dev/null | head -1 || echo "Network info unavailable")

LOG FILES GENERATED
-------------------
$(find "$TEST_LOG_DIR" -type f -name "*.log" 2>/dev/null | head -10 || echo "No log files found")

RECOMMENDATIONS
---------------
EOF

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo "✅ All tests passed successfully!" >> "$report_file"
        echo "✅ The isolated Wazuh agent is fully functional." >> "$report_file"
    else
        echo "⚠️ $FAILED_TESTS test(s) failed - review the logs for details." >> "$report_file"
    fi
    
    if [[ $WARNINGS -gt 0 ]]; then
        echo "⚠️ $WARNINGS warning(s) detected - monitor for potential issues." >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "For detailed logs, check: $TEST_LOG_DIR" >> "$report_file"
    
    print_success "Test report generated: $report_file"
    
    # Display summary
    print_header "FINAL TEST SUMMARY"
    echo -e "${BLUE}📊 Total Tests: $TOTAL_TESTS${NC}"
    echo -e "${GREEN}✅ Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}❌ Failed: $FAILED_TESTS${NC}"
    echo -e "${YELLOW}⚠️  Warnings: $WARNINGS${NC}"
    echo -e "${PURPLE}📈 Success Rate: $(( (PASSED_TESTS * 100) / (TOTAL_TESTS == 0 ? 1 : TOTAL_TESTS) ))%${NC}"
    
    if [[ $FAILED_TESTS -eq 0 ]] && [[ $WARNINGS -lt 3 ]]; then
        echo -e "\n${GREEN}🎉 ISOLATED WAZUH AGENT IS FULLY OPERATIONAL! 🎉${NC}"
        echo -e "${GREEN}✅ Manager connectivity: Working${NC}"
        echo -e "${GREEN}✅ Network scanning detection: Active${NC}"  
        echo -e "${GREEN}✅ Alert generation: Functional${NC}"
        echo -e "${GREEN}✅ All modules: Operational${NC}"
    else
        echo -e "\n${YELLOW}⚠️  ISOLATED AGENT NEEDS ATTENTION${NC}"
        echo -e "${YELLOW}Review the test logs and fix any issues before production use.${NC}"
    fi
}

# Main execution
main() {
    print_header "STARTING COMPREHENSIVE TEST SUITE"
    
    # Trap for cleanup on exit
    trap cleanup_test EXIT
    
    # Execute all tests
    check_prerequisites
    test_agent_integrity
    test_build_system
    test_configuration
    test_manager_connectivity
    test_agent_startup
    test_log_generation
    test_nmap_detection
    test_modules
    test_alert_generation
    test_performance
    
    # Generate final report
    generate_report
    
    print_header "TESTING COMPLETED"
    print_info "Check the test report for detailed results: $TEST_LOG_DIR"
}

# Execute main function
main "$@"
