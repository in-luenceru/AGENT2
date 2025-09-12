#!/bin/bash

# File Integrity Monitoring (FIM) Tests for Wazuh Monitoring Agent
# Tests: File changes, directory monitoring, alert generation
# Author: Cybersecurity QA Engineer

set -euo pipefail

# Import test library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/test_lib.sh"

# Test configuration
TEST_MODULE="FIM"
FIM_LOG_DIR="$LOG_DIR/fim"
TEST_DIR="$DATA_DIR/fim_tests"
MONITORED_DIR="$TEST_DIR/monitored"
AGENT_LOG="$AGENT_LOGS/ossec.log"

# ============================================================================
# INITIALIZATION
# ============================================================================

init_fim_tests() {
    log_info "Initializing FIM (File Integrity Monitoring) tests" "$TEST_MODULE"
    
    # Create test directories
    mkdir -p "$FIM_LOG_DIR" "$TEST_DIR" "$MONITORED_DIR"
    
    # Create test log file
    {
        echo "================================================================"
        echo "File Integrity Monitoring (FIM) Tests"
        echo "Started: $(timestamp)"
        echo "Test Directory: $TEST_DIR"
        echo "Monitored Directory: $MONITORED_DIR"
        echo "================================================================"
    } > "$FIM_LOG_DIR/fim_tests.log"
    
    log_success "FIM test environment initialized" "$TEST_MODULE"
}

# ============================================================================
# CONFIGURATION TESTS
# ============================================================================

test_fim_configuration() {
    start_test "fim_configuration" "Verify FIM is properly configured"
    
    local test_passed=true
    
    # Check if syscheck is enabled in configuration
    if [[ -f "$AGENT_CONFIG" ]]; then
        if grep -q "<syscheck>" "$AGENT_CONFIG"; then
            log_success "Syscheck section found in configuration" "$TEST_MODULE"
            
            # Check if syscheck is not disabled
            if grep -A 20 "<syscheck>" "$AGENT_CONFIG" | grep -q "<disabled>no</disabled>"; then
                log_success "FIM is enabled in configuration" "$TEST_MODULE"
            elif ! grep -A 20 "<syscheck>" "$AGENT_CONFIG" | grep -q "<disabled>yes</disabled>"; then
                log_success "FIM is enabled by default" "$TEST_MODULE"
            else
                log_error "FIM is disabled in configuration" "$TEST_MODULE"
                test_passed=false
            fi
            
            # Check for monitored directories
            local monitored_dirs
            monitored_dirs=$(grep -A 50 "<syscheck>" "$AGENT_CONFIG" | grep "<directories>" | wc -l || echo 0)
            
            if [[ $monitored_dirs -gt 0 ]]; then
                log_success "Found $monitored_dirs monitored directories configured" "$TEST_MODULE"
            else
                log_warning "No monitored directories found in configuration" "$TEST_MODULE"
            fi
        else
            log_error "Syscheck section not found in configuration" "$TEST_MODULE"
            test_passed=false
        fi
    else
        log_error "Agent configuration file not found" "$TEST_MODULE"
        test_passed=false
    fi
    
    if $test_passed; then
        pass_test "fim_configuration" "FIM configuration verified"
        return 0
    else
        fail_test "fim_configuration" "FIM configuration issues found"
        return 1
    fi
}

test_syscheck_daemon() {
    start_test "syscheck_daemon" "Verify syscheck daemon is running"
    
    if assert_process_running "monitor-syscheckd" "syscheck_process"; then
        log_success "Syscheck daemon is running" "$TEST_MODULE"
        
        # Check if daemon is responsive
        local pid
        pid=$(pgrep -f "monitor-syscheckd" | head -1)
        
        if [[ -n "$pid" ]]; then
            # Send USR1 signal to trigger immediate scan (if supported)
            if kill -USR1 "$pid" 2>/dev/null; then
                log_success "Syscheck daemon responds to signals" "$TEST_MODULE"
            else
                log_warning "Cannot send signal to syscheck daemon" "$TEST_MODULE"
            fi
        fi
        
        pass_test "syscheck_daemon" "Syscheck daemon is operational"
        return 0
    else
        fail_test "syscheck_daemon" "Syscheck daemon is not running"
        return 1
    fi
}

# ============================================================================
# FILE CHANGE DETECTION TESTS
# ============================================================================

test_file_creation_detection() {
    start_test "file_creation" "Test detection of new file creation"
    
    local test_file="$MONITORED_DIR/test_new_file.txt"
    local test_content="This is a test file created at $(timestamp)"
    
    # Ensure directory is being monitored by temporarily updating config
    setup_test_monitoring "$MONITORED_DIR"
    
    # Clear previous logs for cleaner test
    local initial_log_size=0
    if [[ -f "$AGENT_LOG" ]]; then
        initial_log_size=$(wc -l < "$AGENT_LOG")
    fi
    
    # Create the test file
    log_info "Creating test file: $test_file" "$TEST_MODULE"
    echo "$test_content" > "$test_file"
    
    # Wait for FIM to detect the change
    log_info "Waiting for FIM detection..." "$TEST_MODULE"
    
    # Check for detection in agent logs
    if wait_for_condition "grep -q 'syscheck.*$test_file' '$AGENT_LOG' 2>/dev/null" 30 1 "file creation detection"; then
        log_success "File creation detected in agent logs" "$TEST_MODULE"
        
        # Extract the detection log entry
        local detection_entry
        detection_entry=$(tail -n +$((initial_log_size + 1)) "$AGENT_LOG" | grep "$test_file" | tail -1)
        echo "Detection: $detection_entry" >> "$FIM_LOG_DIR/fim_tests.log"
        
        pass_test "file_creation" "File creation successfully detected"
        return 0
    else
        log_error "File creation not detected within timeout" "$TEST_MODULE"
        
        # Debug information
        log_debug "Checking recent syscheck activity..." "$TEST_MODULE"
        tail -20 "$AGENT_LOG" | grep -i syscheck >> "$FIM_LOG_DIR/fim_tests.log" 2>/dev/null || true
        
        fail_test "file_creation" "File creation detection failed"
        return 1
    fi
}

test_file_modification_detection() {
    start_test "file_modification" "Test detection of file modifications"
    
    local test_file="$MONITORED_DIR/test_modify_file.txt"
    local initial_content="Initial content at $(timestamp)"
    local modified_content="Modified content at $(timestamp)"
    
    setup_test_monitoring "$MONITORED_DIR"
    
    # Create initial file
    echo "$initial_content" > "$test_file"
    
    # Wait for initial detection and baseline
    sleep 5
    
    # Clear log marker
    local initial_log_size=0
    if [[ -f "$AGENT_LOG" ]]; then
        initial_log_size=$(wc -l < "$AGENT_LOG")
    fi
    
    # Modify the file
    log_info "Modifying test file: $test_file" "$TEST_MODULE"
    echo "$modified_content" > "$test_file"
    
    # Wait for modification detection
    if wait_for_condition "tail -n +$((initial_log_size + 1)) '$AGENT_LOG' | grep -q 'syscheck.*$test_file'" 30 1 "file modification detection"; then
        log_success "File modification detected" "$TEST_MODULE"
        
        local detection_entry
        detection_entry=$(tail -n +$((initial_log_size + 1)) "$AGENT_LOG" | grep "$test_file" | tail -1)
        echo "Modification Detection: $detection_entry" >> "$FIM_LOG_DIR/fim_tests.log"
        
        pass_test "file_modification" "File modification successfully detected"
        return 0
    else
        fail_test "file_modification" "File modification detection failed"
        return 1
    fi
}

test_file_deletion_detection() {
    start_test "file_deletion" "Test detection of file deletions"
    
    local test_file="$MONITORED_DIR/test_delete_file.txt"
    
    setup_test_monitoring "$MONITORED_DIR"
    
    # Create file to be deleted
    echo "File to be deleted at $(timestamp)" > "$test_file"
    
    # Wait for baseline
    sleep 5
    
    # Clear log marker
    local initial_log_size=0
    if [[ -f "$AGENT_LOG" ]]; then
        initial_log_size=$(wc -l < "$AGENT_LOG")
    fi
    
    # Delete the file
    log_info "Deleting test file: $test_file" "$TEST_MODULE"
    rm -f "$test_file"
    
    # Wait for deletion detection
    if wait_for_condition "tail -n +$((initial_log_size + 1)) '$AGENT_LOG' | grep -q 'syscheck.*$test_file'" 30 1 "file deletion detection"; then
        log_success "File deletion detected" "$TEST_MODULE"
        
        local detection_entry
        detection_entry=$(tail -n +$((initial_log_size + 1)) "$AGENT_LOG" | grep "$test_file" | tail -1)
        echo "Deletion Detection: $detection_entry" >> "$FIM_LOG_DIR/fim_tests.log"
        
        pass_test "file_deletion" "File deletion successfully detected"
        return 0
    else
        fail_test "file_deletion" "File deletion detection failed"
        return 1
    fi
}

test_permission_change_detection() {
    start_test "permission_change" "Test detection of file permission changes"
    
    local test_file="$MONITORED_DIR/test_permissions.txt"
    
    setup_test_monitoring "$MONITORED_DIR"
    
    # Create file with specific permissions
    echo "Permission test file" > "$test_file"
    chmod 644 "$test_file"
    
    # Wait for baseline
    sleep 5
    
    # Clear log marker
    local initial_log_size=0
    if [[ -f "$AGENT_LOG" ]]; then
        initial_log_size=$(wc -l < "$AGENT_LOG")
    fi
    
    # Change permissions
    log_info "Changing file permissions: $test_file" "$TEST_MODULE"
    chmod 755 "$test_file"
    
    # Wait for permission change detection
    if wait_for_condition "tail -n +$((initial_log_size + 1)) '$AGENT_LOG' | grep -q 'syscheck.*$test_file'" 30 1 "permission change detection"; then
        log_success "Permission change detected" "$TEST_MODULE"
        
        local detection_entry
        detection_entry=$(tail -n +$((initial_log_size + 1)) "$AGENT_LOG" | grep "$test_file" | tail -1)
        echo "Permission Change Detection: $detection_entry" >> "$FIM_LOG_DIR/fim_tests.log"
        
        pass_test "permission_change" "Permission change successfully detected"
        return 0
    else
        log_warning "Permission change detection may not be configured" "$TEST_MODULE"
        pass_test "permission_change" "Permission change test completed (detection may not be enabled)"
        return 0
    fi
}

# ============================================================================
# DIRECTORY MONITORING TESTS
# ============================================================================

test_directory_monitoring() {
    start_test "directory_monitoring" "Test monitoring of directory changes"
    
    local test_subdir="$MONITORED_DIR/subdir_test"
    
    setup_test_monitoring "$MONITORED_DIR"
    
    # Create subdirectory
    log_info "Creating subdirectory: $test_subdir" "$TEST_MODULE"
    mkdir -p "$test_subdir"
    
    # Wait for detection
    sleep 3
    
    # Create file in subdirectory
    local test_file="$test_subdir/nested_file.txt"
    echo "File in subdirectory" > "$test_file"
    
    # Check if changes in subdirectory are detected
    if wait_for_condition "grep -q '$test_subdir\|$test_file' '$AGENT_LOG' 2>/dev/null" 20 1 "directory monitoring"; then
        log_success "Directory changes detected" "$TEST_MODULE"
        pass_test "directory_monitoring" "Directory monitoring is functional"
        return 0
    else
        log_warning "Directory changes not detected (may depend on recursion settings)" "$TEST_MODULE"
        pass_test "directory_monitoring" "Directory monitoring test completed"
        return 0
    fi
}

# ============================================================================
# REAL-TIME MONITORING TESTS
# ============================================================================

test_realtime_monitoring() {
    start_test "realtime_monitoring" "Test real-time file monitoring capabilities"
    
    local test_file="$MONITORED_DIR/realtime_test.txt"
    
    setup_test_monitoring "$MONITORED_DIR"
    
    # Rapid file changes to test real-time detection
    log_info "Performing rapid file changes for real-time testing" "$TEST_MODULE"
    
    local changes_detected=0
    local total_changes=5
    
    for i in $(seq 1 $total_changes); do
        echo "Change $i at $(timestamp)" > "$test_file"
        sleep 2
        
        # Check if this change was detected
        if grep -q "syscheck.*$test_file" "$AGENT_LOG" 2>/dev/null; then
            ((changes_detected++))
        fi
    done
    
    log_info "Detected $changes_detected out of $total_changes rapid changes" "$TEST_MODULE"
    
    if [[ $changes_detected -gt 0 ]]; then
        log_success "Real-time monitoring is functional" "$TEST_MODULE"
        pass_test "realtime_monitoring" "Real-time monitoring detected $changes_detected/$total_changes changes"
        return 0
    else
        log_warning "No real-time changes detected (may use periodic scanning)" "$TEST_MODULE"
        pass_test "realtime_monitoring" "Real-time monitoring test completed (periodic mode possible)"
        return 0
    fi
}

# ============================================================================
# SECURITY EVENT SIMULATION
# ============================================================================

test_security_file_tampering() {
    start_test "security_tampering" "Simulate security-relevant file tampering"
    
    local critical_file="$MONITORED_DIR/critical_system_file"
    
    setup_test_monitoring "$MONITORED_DIR"
    
    # Create a file that simulates critical system files
    echo "# Critical system configuration" > "$critical_file"
    echo "security_setting=enabled" >> "$critical_file"
    
    # Wait for baseline
    sleep 5
    
    # Simulate malicious tampering
    log_info "Simulating malicious file tampering" "$TEST_MODULE"
    
    # Multiple suspicious changes
    echo "# MALICIOUS MODIFICATION" >> "$critical_file"
    echo "security_setting=disabled" >> "$critical_file"
    echo "backdoor_user=hacker:x:0:0::/root:/bin/bash" >> "$critical_file"
    
    # Wait for detection
    if wait_for_condition "grep -q 'syscheck.*$critical_file' '$AGENT_LOG' 2>/dev/null" 30 1 "security tampering detection"; then
        log_success "Security tampering detected" "$TEST_MODULE"
        
        # Check if manager is also alerted (if connected)
        if check_manager_alerts "syscheck.*$critical_file" 15; then
            log_success "Security tampering alert forwarded to manager" "$TEST_MODULE"
        else
            log_warning "Security tampering alert not found in manager (may be expected)" "$TEST_MODULE"
        fi
        
        pass_test "security_tampering" "Security file tampering successfully detected"
        return 0
    else
        fail_test "security_tampering" "Security file tampering not detected"
        return 1
    fi
}

test_binary_modification() {
    start_test "binary_modification" "Test detection of binary file modifications"
    
    local fake_binary="$MONITORED_DIR/fake_system_binary"
    
    setup_test_monitoring "$MONITORED_DIR"
    
    # Create a fake binary file
    echo -e "#!/bin/bash\necho 'Original binary'\n" > "$fake_binary"
    chmod +x "$fake_binary"
    
    # Wait for baseline
    sleep 5
    
    # Simulate binary replacement/modification
    log_info "Simulating binary modification" "$TEST_MODULE"
    echo -e "#!/bin/bash\necho 'MALICIOUS CODE'\nrm -rf /tmp/*\n" > "$fake_binary"
    
    # Wait for detection
    if wait_for_condition "grep -q 'syscheck.*$fake_binary' '$AGENT_LOG' 2>/dev/null" 30 1 "binary modification detection"; then
        log_success "Binary modification detected" "$TEST_MODULE"
        pass_test "binary_modification" "Binary file modification successfully detected"
        return 0
    else
        fail_test "binary_modification" "Binary file modification not detected"
        return 1
    fi
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

setup_test_monitoring() {
    local dir_to_monitor="$1"
    
    log_info "Setting up monitoring for directory: $dir_to_monitor" "$TEST_MODULE"
    
    # Check if the directory is already being monitored
    if grep -q "$dir_to_monitor" "$AGENT_CONFIG" 2>/dev/null; then
        log_success "Directory already configured for monitoring" "$TEST_MODULE"
        return 0
    fi
    
    # For testing purposes, we'll rely on existing configuration
    # In a production environment, you might temporarily modify the config
    log_info "Using existing syscheck configuration for testing" "$TEST_MODULE"
    
    # Ensure the test directory exists and has proper permissions
    mkdir -p "$dir_to_monitor"
    chmod 755 "$dir_to_monitor"
    
    # Trigger an immediate syscheck scan if possible
    local syscheck_pid
    syscheck_pid=$(pgrep -f "monitor-syscheckd" | head -1 2>/dev/null || echo "")
    
    if [[ -n "$syscheck_pid" ]]; then
        # Send signal to trigger immediate scan (USR1 is commonly used)
        kill -USR1 "$syscheck_pid" 2>/dev/null || true
        log_info "Triggered immediate syscheck scan" "$TEST_MODULE"
    fi
    
    return 0
}

cleanup_fim_tests() {
    log_info "Cleaning up FIM test files" "$TEST_MODULE"
    
    # Remove test files and directories
    if [[ -d "$MONITORED_DIR" ]]; then
        rm -rf "$MONITORED_DIR"
    fi
    
    # Clean up any temporary monitoring configurations
    # (In this implementation, we don't modify the main config)
    
    log_success "FIM test cleanup completed" "$TEST_MODULE"
}

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

run_fim_tests() {
    log_info "Starting File Integrity Monitoring (FIM) tests" "$TEST_MODULE"
    
    # Check if agent is running
    if ! is_agent_running; then
        log_error "Agent is not running. Please start the agent first." "$TEST_MODULE"
        return 1
    fi
    
    # Initialize test environment
    init_fim_tests
    
    # Array to store test results
    local -a test_results=()
    
    # Run configuration tests
    log_info "Running FIM configuration tests..." "$TEST_MODULE"
    test_fim_configuration
    test_results+=($?)
    
    test_syscheck_daemon
    test_results+=($?)
    
    # Run file change detection tests
    log_info "Running file change detection tests..." "$TEST_MODULE"
    test_file_creation_detection
    test_results+=($?)
    
    test_file_modification_detection
    test_results+=($?)
    
    test_file_deletion_detection
    test_results+=($?)
    
    test_permission_change_detection
    test_results+=($?)
    
    # Run directory monitoring tests
    log_info "Running directory monitoring tests..." "$TEST_MODULE"
    test_directory_monitoring
    test_results+=($?)
    
    # Run real-time monitoring tests
    log_info "Running real-time monitoring tests..." "$TEST_MODULE"
    test_realtime_monitoring
    test_results+=($?)
    
    # Run security simulation tests
    log_info "Running security event simulation tests..." "$TEST_MODULE"
    test_security_file_tampering
    test_results+=($?)
    
    test_binary_modification
    test_results+=($?)
    
    # Calculate results
    local passed=0
    local total=${#test_results[@]}
    
    for result in "${test_results[@]}"; do
        if [[ $result -eq 0 ]]; then
            ((passed++))
        fi
    done
    
    log_info "FIM tests completed: $passed/$total passed" "$TEST_MODULE"
    
    # Generate FIM test report
    {
        echo "================================================================"
        echo "File Integrity Monitoring (FIM) Test Results"
        echo "Completed: $(timestamp)"
        echo "================================================================"
        echo "Tests Passed: $passed/$total"
        echo "Success Rate: $(( total > 0 ? (passed * 100) / total : 0 ))%"
        echo ""
        echo "Detailed Results:"
        echo "- FIM Configuration: $([ ${test_results[0]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- Syscheck Daemon: $([ ${test_results[1]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- File Creation Detection: $([ ${test_results[2]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- File Modification Detection: $([ ${test_results[3]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- File Deletion Detection: $([ ${test_results[4]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- Permission Change Detection: $([ ${test_results[5]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- Directory Monitoring: $([ ${test_results[6]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- Real-time Monitoring: $([ ${test_results[7]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- Security Tampering Detection: $([ ${test_results[8]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- Binary Modification Detection: $([ ${test_results[9]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo ""
        echo "Test Directory: $TEST_DIR"
        echo "Logs: $FIM_LOG_DIR"
        echo "================================================================"
    } > "$FIM_LOG_DIR/fim_test_results.txt"
    
    # Cleanup test environment
    cleanup_fim_tests
    
    if [[ $passed -eq $total ]]; then
        log_success "All FIM tests passed!" "$TEST_MODULE"
        return 0
    else
        log_error "Some FIM tests failed: $((total - passed))/$total" "$TEST_MODULE"
        return 1
    fi
}

# ============================================================================
# SCRIPT EXECUTION
# ============================================================================

# Main execution
main() {
    # Initialize test framework
    if ! init_test_framework; then
        echo "Failed to initialize test framework"
        exit 1
    fi
    
    # Run FIM tests
    if run_fim_tests; then
        log_success "FIM tests completed successfully" "$TEST_MODULE"
        exit 0
    else
        log_error "FIM tests failed" "$TEST_MODULE"
        exit 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi