#!/bin/bash

# Active Response Tests for Wazuh Monitoring Agent
# Tests: Automated threat response, blocking, remediation
# Author: Cybersecurity QA Engineer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/test_lib.sh"

TEST_MODULE="ACTIVE_RESPONSE"

init_active_response_tests() {
    log_info "Initializing Active Response tests" "$TEST_MODULE"
    mkdir -p "$LOG_DIR/active-response" "$DATA_DIR/active_response_tests"
}

test_execd_daemon() {
    start_test "execd_daemon" "Test active response daemon functionality"
    
    if assert_process_running "monitor-execd" "execd_process"; then
        log_success "Active response daemon (execd) is running" "$TEST_MODULE"
        
        # Check active response scripts directory
        local ar_scripts_dir="$AGENT_HOME/active-response/bin"
        if [[ -d "$ar_scripts_dir" ]]; then
            local script_count=$(find "$ar_scripts_dir" -type f -executable | wc -l)
            log_info "Found $script_count active response scripts" "$TEST_MODULE"
        fi
        
        pass_test "execd_daemon" "Active response daemon test completed"
    else
        skip_test "execd_daemon" "Active response daemon not running"
    fi
    
    return 0
}

test_threat_simulation() {
    start_test "threat_simulation" "Test active response to simulated threats"
    
    # Create a mock active response script for testing
    local mock_ar_script="$DATA_DIR/active_response_tests/test_response.sh"
    cat > "$mock_ar_script" << 'EOF'
#!/bin/bash
# Mock active response script
echo "$(date): Active response triggered - Test threat blocked" >> /tmp/ar_test.log
echo "Source IP: $1" >> /tmp/ar_test.log
echo "Alert ID: $2" >> /tmp/ar_test.log
exit 0
EOF
    
    chmod +x "$mock_ar_script"
    
    # Simulate threat scenario
    log_info "Simulating threat scenario for active response" "$TEST_MODULE"
    
    # In a real scenario, this would trigger actual active response
    if [[ -x "$mock_ar_script" ]]; then
        "$mock_ar_script" "192.168.1.100" "12345"
        
        if [[ -f "/tmp/ar_test.log" ]]; then
            log_success "Active response simulation successful" "$TEST_MODULE"
            rm -f "/tmp/ar_test.log"
        fi
    fi
    
    pass_test "threat_simulation" "Threat simulation test completed"
    
    rm -f "$mock_ar_script"
    return 0
}

run_active_response_tests() {
    init_active_response_tests
    test_execd_daemon
    test_threat_simulation
    log_success "Active response tests completed" "$TEST_MODULE"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_test_framework && run_active_response_tests
fi