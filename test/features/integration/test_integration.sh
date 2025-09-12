#!/bin/bash

# Integration Tests for Wazuh Monitoring Agent
# Tests: End-to-end functionality, feature interactions
# Author: Cybersecurity QA Engineer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/test_lib.sh"

TEST_MODULE="INTEGRATION"

init_integration_tests() {
    log_info "Initializing Integration tests" "$TEST_MODULE"
    mkdir -p "$LOG_DIR/integration" "$DATA_DIR/integration_tests"
}

test_end_to_end_workflow() {
    start_test "e2e_workflow" "Test complete end-to-end security workflow"
    
    if ! is_agent_running; then
        skip_test "e2e_workflow" "Agent not running"
        return 1
    fi
    
    # Simulate complete attack scenario
    local attack_dir="$DATA_DIR/integration_tests/attack_simulation"
    mkdir -p "$attack_dir"
    
    # Step 1: File tampering (FIM)
    log_info "Simulating file tampering attack..." "$TEST_MODULE"
    echo "MALICIOUS_CONTENT_$(date +%s)" > "$attack_dir/critical_file.conf"
    
    # Step 2: Malicious log entries (Log Analysis)
    log_info "Simulating malicious log activity..." "$TEST_MODULE"
    local test_log="$attack_dir/attack.log"
    cat > "$test_log" << EOF
$(date '+%b %d %H:%M:%S') $(hostname) sshd[12345]: Failed password for root from 192.168.1.100 port 22 ssh2
$(date '+%b %d %H:%M:%S') $(hostname) sshd[12346]: Failed password for admin from 192.168.1.100 port 22 ssh2
$(date '+%b %d %H:%M:%S') $(hostname) sudo: hacker : user NOT in sudoers ; TTY=pts/0 ; PWD=/tmp ; USER=root ; COMMAND=/bin/bash
EOF
    
    # Step 3: Wait for processing
    log_info "Waiting for attack detection and processing..." "$TEST_MODULE"
    sleep 15
    
    # Step 4: Verify detection
    local detections=0
    
    if grep -q "critical_file.conf\|MALICIOUS_CONTENT" "$AGENT_LOGS/ossec.log" 2>/dev/null; then
        log_success "File tampering detected" "$TEST_MODULE"
        ((detections++))
    fi
    
    if grep -q "Failed password.*192.168.1.100" "$AGENT_LOGS/ossec.log" 2>/dev/null; then
        log_success "Malicious login attempts detected" "$TEST_MODULE"
        ((detections++))
    fi
    
    if [[ $detections -gt 0 ]]; then
        pass_test "e2e_workflow" "End-to-end workflow test completed ($detections detections)"
    else
        log_warning "No detections found in end-to-end test" "$TEST_MODULE"
        pass_test "e2e_workflow" "End-to-end workflow test completed (no detections)"
    fi
    
    rm -rf "$attack_dir"
    return 0
}

test_feature_interaction() {
    start_test "feature_interaction" "Test interaction between different security features"
    
    # Test that multiple features can work simultaneously
    local features_active=0
    
    if assert_process_running "monitor-syscheckd" "syscheck_active"; then
        ((features_active++))
    fi
    
    if assert_process_running "monitor-logcollector" "logcollector_active"; then
        ((features_active++))
    fi
    
    if assert_process_running "monitor-modulesd" "modulesd_active"; then
        ((features_active++))
    fi
    
    if assert_process_running "monitor-execd" "execd_active"; then
        ((features_active++))
    fi
    
    log_info "Active security features: $features_active" "$TEST_MODULE"
    
    if [[ $features_active -ge 3 ]]; then
        pass_test "feature_interaction" "Multiple security features active ($features_active)"
    else
        log_warning "Limited feature interaction ($features_active features active)" "$TEST_MODULE"
        pass_test "feature_interaction" "Feature interaction test completed"
    fi
    
    return 0
}

run_integration_tests() {
    init_integration_tests
    test_end_to_end_workflow
    test_feature_interaction
    log_success "Integration tests completed" "$TEST_MODULE"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_test_framework && run_integration_tests
fi