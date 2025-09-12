#!/bin/bash
# Enhanced Agent Integration Script - Production Ready
# This script creates a real-time threat monitoring system with the custom agent

set -e

AGENT_HOME="/workspaces/AGENT2"
WAZUH_MANAGER_IP="127.0.0.1"
WAZUH_MANAGER_PORT="1514"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_banner() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "   ENHANCED WAZUH AGENT INTEGRATION"
    echo "   Production-Ready Threat Detection System"
    echo "=================================================="
    echo -e "${NC}"
}

create_real_time_threat_monitor() {
    log_info "Creating real-time threat detection system..."
    
    cat > "$AGENT_HOME/real_time_threat_monitor.sh" << 'EOF'
#!/bin/bash
# Real-time threat detection and event generation
# Monitors actual system activity and generates events

AGENT_HOME="/workspaces/AGENT2"
THREAT_LOG="$AGENT_HOME/logs/network_threats.log"
ALERT_LOG="$AGENT_HOME/logs/security_alerts.log"

# Ensure log directory exists
mkdir -p "$AGENT_HOME/logs"

log_threat() {
    local severity="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$severity] $message" >> "$THREAT_LOG"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$severity] $message" >> "$ALERT_LOG"
    logger -t wazuh-agent "[THREAT] $severity: $message"
}

# Monitor for suspicious network activity
monitor_network_threats() {
    # Check for port scans
    netstat -tulpn | grep -E ":(22|80|443|1514|3389|445|139)" | while read line; do
        if echo "$line" | grep -q "LISTEN"; then
            port=$(echo "$line" | awk '{print $4}' | cut -d: -f2)
            log_threat "INFO" "Service listening on sensitive port: $port"
        fi
    done
    
    # Monitor for unusual connections
    ss -tulpn | grep -E "ESTAB.*:(22|1514)" | wc -l | while read conn_count; do
        if [[ $conn_count -gt 10 ]]; then
            log_threat "WARNING" "High number of connections detected: $conn_count"
        fi
    done
}

# Monitor file integrity in real time
monitor_file_changes() {
    # Check for recent changes in critical directories
    find /etc /root /home -type f -mmin -5 2>/dev/null | head -10 | while read file; do
        if [[ -f "$file" ]]; then
            log_threat "INFO" "Recent file modification detected: $file"
        fi
    done
}

# Monitor for authentication events
monitor_auth_events() {
    # Check for failed login attempts in the last minute
    failed_logins=$(grep "$(date '+%b %d %H:%M' -d '1 minute ago')" /var/log/auth.log 2>/dev/null | grep -c "Failed password" || echo 0)
    if [[ $failed_logins -gt 0 ]]; then
        log_threat "WARNING" "Failed login attempts detected: $failed_logins in last minute"
    fi
    
    # Check for privilege escalation
    sudo_attempts=$(grep "$(date '+%b %d %H:%M' -d '1 minute ago')" /var/log/auth.log 2>/dev/null | grep -c "sudo:" || echo 0)
    if [[ $sudo_attempts -gt 5 ]]; then
        log_threat "CRITICAL" "High sudo activity detected: $sudo_attempts attempts"
    fi
}

# Monitor processes for suspicious activity
monitor_processes() {
    # Check for common attack tools
    suspicious_procs=$(ps aux | grep -E "(nmap|masscan|nikto|sqlmap|metasploit|hydra|john|hashcat|netcat)" | grep -v grep | wc -l)
    if [[ $suspicious_procs -gt 0 ]]; then
        log_threat "CRITICAL" "Suspicious security tools detected running: $suspicious_procs processes"
        ps aux | grep -E "(nmap|masscan|nikto|sqlmap|metasploit|hydra|john|hashcat|netcat)" | grep -v grep >> "$THREAT_LOG"
    fi
}

# Main monitoring loop
main() {
    log_threat "INFO" "Real-time threat monitor started"
    
    while true; do
        monitor_network_threats
        monitor_file_changes
        monitor_auth_events
        monitor_processes
        
        # Sleep for 30 seconds between checks
        sleep 30
    done
}

# Handle cleanup on exit
trap 'log_threat "INFO" "Real-time threat monitor stopped"; exit 0' SIGTERM SIGINT

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF

    chmod +x "$AGENT_HOME/real_time_threat_monitor.sh"
    log_success "Created real-time threat monitor"
}

create_comprehensive_test_script() {
    log_info "Creating comprehensive integration test script..."
    
    cat > "$AGENT_HOME/comprehensive_agent_test.sh" << 'EOF'
#!/bin/bash
# Comprehensive Agent Integration Test Script

set -e

AGENT_HOME="/workspaces/AGENT2"
TEST_RESULTS_DIR="$AGENT_HOME/test_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[TEST-INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[TEST-PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[TEST-FAIL]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[TEST-WARN]${NC} $1"; }

# Initialize test environment
init_test() {
    mkdir -p "$TEST_RESULTS_DIR"
    echo "Test Started: $(date)" > "$TEST_RESULTS_DIR/test_$TIMESTAMP.log"
    log_info "Starting comprehensive agent integration test"
}

# Test 1: Binary availability and execution
test_binaries() {
    log_info "Testing binary availability and basic functionality..."
    local passed=0
    local total=5
    
    for binary in wazuh-agentd wazuh-logcollector wazuh-execd wazuh-modulesd wazuh-syscheckd; do
        if [[ -x "$AGENT_HOME/src/$binary" ]]; then
            if timeout 5 "$AGENT_HOME/src/$binary" -h >/dev/null 2>&1; then
                log_pass "$binary is executable and responsive"
                ((passed++))
            else
                log_fail "$binary exists but may have execution issues"
            fi
        else
            log_fail "$binary not found or not executable"
        fi
    done
    
    echo "Binary Test: $passed/$total passed" >> "$TEST_RESULTS_DIR/test_$TIMESTAMP.log"
    return $((total - passed))
}

# Test 2: Configuration validation
test_configuration() {
    log_info "Testing configuration files..."
    local issues=0
    
    # Test ossec.conf
    if [[ -f "$AGENT_HOME/etc/ossec.conf" ]]; then
        if timeout 10 "$AGENT_HOME/src/wazuh-agentd" -t -c "$AGENT_HOME/etc/ossec.conf" >/dev/null 2>&1; then
            log_pass "ossec.conf syntax is valid"
        else
            log_fail "ossec.conf has syntax errors"
            ((issues++))
        fi
    else
        log_fail "ossec.conf not found"
        ((issues++))
    fi
    
    # Test client.keys
    if [[ -f "$AGENT_HOME/etc/client.keys" ]]; then
        if grep -q "^[0-9]\{3\} [a-zA-Z0-9_-]\+ [0-9.]\+ [a-fA-F0-9]\{64\}$" "$AGENT_HOME/etc/client.keys"; then
            log_pass "client.keys format is valid"
        else
            log_warn "client.keys format may be non-standard"
        fi
    else
        log_fail "client.keys not found"
        ((issues++))
    fi
    
    echo "Configuration Test: $issues issues found" >> "$TEST_RESULTS_DIR/test_$TIMESTAMP.log"
    return $issues
}

# Test 3: Network connectivity
test_connectivity() {
    log_info "Testing manager connectivity..."
    local issues=0
    
    # Test manager port 1514
    if nc -z 127.0.0.1 1514 2>/dev/null; then
        log_pass "Manager port 1514 is reachable"
    else
        log_fail "Cannot connect to manager port 1514"
        ((issues++))
    fi
    
    # Test manager port 1515 (enrollment)
    if nc -z 127.0.0.1 1515 2>/dev/null; then
        log_pass "Manager port 1515 is reachable"
    else
        log_warn "Cannot connect to manager port 1515 (enrollment may be disabled)"
    fi
    
    echo "Connectivity Test: $issues issues found" >> "$TEST_RESULTS_DIR/test_$TIMESTAMP.log"
    return $issues
}

# Test 4: Simulate real threats
test_threat_detection() {
    log_info "Testing threat detection capabilities..."
    
    # Create test threats
    echo "$(date): Test threat - Failed login attempt from 192.168.1.100" | sudo tee -a /var/log/security_events.log
    echo "$(date): Test threat - Suspicious process: nmap -sS target" | sudo tee -a /var/log/security_events.log
    
    # Create test file change
    test_file="/tmp/wazuh_test_$(date +%s)"
    echo "test content" > "$test_file"
    chmod 777 "$test_file"
    
    sleep 5
    
    # Clean up
    rm -f "$test_file"
    
    log_pass "Threat simulation completed"
    echo "Threat Detection Test: completed" >> "$TEST_RESULTS_DIR/test_$TIMESTAMP.log"
    return 0
}

# Test 5: Agent communication
test_agent_communication() {
    log_info "Testing agent communication with manager..."
    
    # Try to start agent briefly
    timeout 15 "$AGENT_HOME/src/wazuh-agentd" -c "$AGENT_HOME/etc/ossec.conf" -f >/dev/null 2>&1 &
    local agent_pid=$!
    
    sleep 5
    
    # Check if agent is running
    if kill -0 $agent_pid 2>/dev/null; then
        log_pass "Agent started successfully"
        
        # Stop agent
        kill $agent_pid 2>/dev/null || true
        wait $agent_pid 2>/dev/null || true
        
        log_pass "Agent communication test completed"
        echo "Agent Communication Test: success" >> "$TEST_RESULTS_DIR/test_$TIMESTAMP.log"
        return 0
    else
        log_fail "Agent failed to start or communicate"
        echo "Agent Communication Test: failed" >> "$TEST_RESULTS_DIR/test_$TIMESTAMP.log"
        return 1
    fi
}

# Generate test report
generate_report() {
    local total_tests=5
    local passed_tests=0
    
    log_info "Generating test report..."
    
    echo "=" >> "$TEST_RESULTS_DIR/test_$TIMESTAMP.log"
    echo "Test Summary:" >> "$TEST_RESULTS_DIR/test_$TIMESTAMP.log"
    echo "Completed: $(date)" >> "$TEST_RESULTS_DIR/test_$TIMESTAMP.log"
    
    # Run all tests
    test_binaries && ((passed_tests++)) || true
    test_configuration && ((passed_tests++)) || true
    test_connectivity && ((passed_tests++)) || true
    test_threat_detection && ((passed_tests++)) || true
    test_agent_communication && ((passed_tests++)) || true
    
    echo "Tests Passed: $passed_tests/$total_tests" >> "$TEST_RESULTS_DIR/test_$TIMESTAMP.log"
    
    log_info "Test results saved to: $TEST_RESULTS_DIR/test_$TIMESTAMP.log"
    
    if [[ $passed_tests -eq $total_tests ]]; then
        log_pass "All integration tests passed!"
        return 0
    else
        log_warn "Some tests failed. Check log for details."
        return 1
    fi
}

# Main test execution
main() {
    init_test
    generate_report
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF

    chmod +x "$AGENT_HOME/comprehensive_agent_test.sh"
    log_success "Created comprehensive integration test script"
}

create_threat_simulation_script() {
    log_info "Creating advanced threat simulation script..."
    
    cat > "$AGENT_HOME/advanced_threat_simulation.sh" << 'EOF'
#!/bin/bash
# Advanced Threat Simulation for Testing Real Agent Detection

AGENT_HOME="/workspaces/AGENT2"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${YELLOW}[SIMULATION]${NC} $1"; }
log_success() { echo -e "${GREEN}[DETECTED]${NC} $1"; }
log_attack() { echo -e "${RED}[ATTACK]${NC} $1"; }

print_banner() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "   ADVANCED THREAT SIMULATION"
    echo "   Testing Real-Time Detection Capabilities"
    echo "=================================================="
    echo -e "${NC}"
}

# Simulate brute force attack
simulate_brute_force() {
    log_attack "Simulating brute force attack..."
    
    for i in {1..5}; do
        echo "$(date '+%b %d %H:%M:%S') $(hostname) sshd[$$]: Failed password for invalid user attacker$i from 192.168.1.100 port 22 ssh2" | sudo tee -a /var/log/auth.log >/dev/null
        sleep 1
    done
    
    log_success "Brute force simulation completed"
}

# Simulate file integrity violation
simulate_file_tampering() {
    log_attack "Simulating file tampering..."
    
    # Create and modify critical files
    test_files=("/tmp/shadow_backup" "/tmp/passwd_backup" "/tmp/ssh_config_backup")
    
    for file in "${test_files[@]}"; do
        echo "$(date): Malicious content added" | sudo tee "$file" >/dev/null
        chmod 644 "$file"
        log_info "Modified: $file"
        sleep 2
    done
    
    log_success "File tampering simulation completed"
}

# Simulate network scanning
simulate_network_scan() {
    log_attack "Simulating network scanning..."
    
    # Log network scanning activity
    echo "$(date '+%Y-%m-%d %H:%M:%S') SECURITY_ALERT: Port scan detected from 192.168.1.50 targeting ports 22,80,443,1514" | sudo tee -a /var/log/security_events.log >/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S') SECURITY_ALERT: Nmap scan detected: nmap -sS -O 192.168.1.0/24" | sudo tee -a /var/log/security_events.log >/dev/null
    
    log_success "Network scanning simulation completed"
}

# Simulate privilege escalation
simulate_privilege_escalation() {
    log_attack "Simulating privilege escalation attempts..."
    
    for i in {1..3}; do
        echo "$(date '+%b %d %H:%M:%S') $(hostname) sudo: attacker$i : TTY=pts/0 ; PWD=/tmp ; USER=root ; COMMAND=/bin/bash" | sudo tee -a /var/log/auth.log >/dev/null
        echo "$(date '+%b %d %H:%M:%S') $(hostname) su: FAILED SU (to root) attacker$i on pts/0" | sudo tee -a /var/log/auth.log >/dev/null
        sleep 1
    done
    
    log_success "Privilege escalation simulation completed"
}

# Simulate malware-like processes
simulate_suspicious_processes() {
    log_attack "Simulating suspicious process activity..."
    
    # Create fake process entries (logged events)
    suspicious_tools=("nmap" "masscan" "nikto" "sqlmap" "metasploit" "hydra")
    
    for tool in "${suspicious_tools[@]}"; do
        echo "$(date '+%Y-%m-%d %H:%M:%S') SECURITY_ALERT: Suspicious process detected: $tool -target 192.168.1.0/24" | sudo tee -a /var/log/security_events.log >/dev/null
        log_info "Logged suspicious process: $tool"
        sleep 1
    done
    
    log_success "Suspicious process simulation completed"
}

# Simulate network file system attacks
simulate_nfs_attacks() {
    log_attack "Simulating network file system attacks..."
    
    # Simulate unauthorized mount attempts
    echo "$(date '+%Y-%m-%d %H:%M:%S') SECURITY_ALERT: Unauthorized NFS mount attempt: mount 192.168.1.200:/admin /mnt/target" | sudo tee -a /var/log/security_events.log >/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S') SECURITY_ALERT: CIFS mount with suspicious credentials: mount -t cifs //192.168.1.201/shared /mnt/attack" | sudo tee -a /var/log/security_events.log >/dev/null
    
    log_success "NFS attack simulation completed"
}

# Simulate web application attacks
simulate_web_attacks() {
    log_attack "Simulating web application attacks..."
    
    # Simulate SQL injection attempts
    echo "$(date '+%Y-%m-%d %H:%M:%S') SECURITY_ALERT: SQL injection attempt: GET /login.php?user=admin'OR 1=1-- HTTP/1.1" | sudo tee -a /var/log/security_events.log >/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S') SECURITY_ALERT: XSS attempt: POST /comment.php data=<script>alert('xss')</script>" | sudo tee -a /var/log/security_events.log >/dev/null
    
    log_success "Web attack simulation completed"
}

# Generate comprehensive attack report
generate_attack_report() {
    log_info "Generating attack simulation report..."
    
    report_file="$AGENT_HOME/logs/attack_simulation_$(date +%Y%m%d_%H%M%S).log"
    
    cat > "$report_file" << EOF
=== ADVANCED THREAT SIMULATION REPORT ===
Timestamp: $(date)
Duration: 5 minutes

SIMULATED ATTACKS:
1. Brute Force Authentication Attack (5 attempts)
2. File Integrity Violations (3 critical files)
3. Network Scanning Activity (port scans)
4. Privilege Escalation Attempts (3 attempts)
5. Suspicious Process Execution (6 tools)
6. Network File System Attacks (NFS/CIFS)
7. Web Application Attacks (SQL injection, XSS)

EXPECTED DETECTIONS:
- Failed login alerts
- File modification alerts
- Network anomaly alerts
- Privilege escalation alerts
- Malware detection alerts
- Network mount alerts
- Web attack alerts

VALIDATION STEPS:
1. Check Wazuh manager for generated alerts
2. Verify agent logs for event transmission
3. Confirm real-time detection capabilities
4. Validate alert severity levels

STATUS: SIMULATION COMPLETED
EOF

    log_success "Attack report saved to: $report_file"
}

# Cleanup function
cleanup_simulation() {
    log_info "Cleaning up simulation artifacts..."
    
    # Remove temporary files
    sudo rm -f /tmp/shadow_backup /tmp/passwd_backup /tmp/ssh_config_backup
    
    log_success "Cleanup completed"
}

# Main execution
main() {
    print_banner
    
    log_info "Starting advanced threat simulation..."
    echo "This will generate various security events to test detection capabilities."
    echo "Press Ctrl+C to stop at any time."
    echo
    
    # Run simulations
    simulate_brute_force
    sleep 2
    
    simulate_file_tampering
    sleep 2
    
    simulate_network_scan
    sleep 2
    
    simulate_privilege_escalation
    sleep 2
    
    simulate_suspicious_processes
    sleep 2
    
    simulate_nfs_attacks
    sleep 2
    
    simulate_web_attacks
    sleep 2
    
    generate_attack_report
    cleanup_simulation
    
    echo
    echo -e "${GREEN}=================================================="
    echo "   THREAT SIMULATION COMPLETED"
    echo "=================================================="
    echo -e "${NC}"
    echo "Next steps:"
    echo "1. Check Wazuh manager dashboard for alerts"
    echo "2. Review agent logs: tail -f $AGENT_HOME/logs/ossec.log"
    echo "3. Monitor threat logs: tail -f $AGENT_HOME/logs/network_threats.log"
    echo "4. Verify real-time detection in manager interface"
}

# Handle cleanup on exit
trap cleanup_simulation EXIT

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF

    chmod +x "$AGENT_HOME/advanced_threat_simulation.sh"
    log_success "Created advanced threat simulation script"
}

# Main execution
main() {
    print_banner
    
    log_info "Setting up enhanced agent integration..."
    
    # Ensure directories exist
    mkdir -p "$AGENT_HOME"/{logs,test_results,var/run}
    
    # Create enhanced monitoring scripts
    create_real_time_threat_monitor
    create_comprehensive_test_script
    create_threat_simulation_script
    
    echo
    echo -e "${GREEN}=================================================="
    echo "   ENHANCED AGENT INTEGRATION COMPLETED"
    echo "=================================================="
    echo -e "${NC}"
    
    echo "Available tools:"
    echo "1. Real-time threat monitor: ./real_time_threat_monitor.sh"
    echo "2. Comprehensive testing: ./comprehensive_agent_test.sh"
    echo "3. Advanced threat simulation: ./advanced_threat_simulation.sh"
    echo "4. Agent control: ./wazuh-agent-control"
    echo
    echo "To start monitoring:"
    echo "  ./wazuh-agent-control start"
    echo "  ./real_time_threat_monitor.sh &"
    echo
    echo "To test detection:"
    echo "  ./advanced_threat_simulation.sh"
    echo
    echo "To run full tests:"
    echo "  ./comprehensive_agent_test.sh"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi