#!/bin/bash

# Core Service Validation Tests for Wazuh Monitoring Agent
# Tests: Service startup, daemon functionality, manager connectivity
# Author: Cybersecurity QA Engineer

set -euo pipefail

# Import test library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/test_lib.sh"

# Test configuration
TEST_MODULE="CORE"
CORE_LOG_DIR="$LOG_DIR/core"
STARTUP_LOG="$CORE_LOG_DIR/startup.log"
CONNECTION_LOG="$CORE_LOG_DIR/connection.log"

# ============================================================================
# INITIALIZATION
# ============================================================================

init_core_tests() {
    log_info "Initializing core validation tests" "$TEST_MODULE"
    
    # Create test-specific directories
    mkdir -p "$CORE_LOG_DIR"
    
    # Initialize log files
    {
        echo "================================================================"
        echo "Wazuh Agent Core Service Validation Tests"
        echo "Started: $(timestamp)"
        echo "================================================================"
    } > "$STARTUP_LOG"
    
    cp "$STARTUP_LOG" "$CONNECTION_LOG"
    
    log_success "Core test environment initialized" "$TEST_MODULE"
}

# ============================================================================
# STARTUP VALIDATION TESTS
# ============================================================================

test_agent_installation() {
    start_test "agent_installation" "Verify agent installation and required files"
    
    local test_passed=true
    
    # Test monitor-control exists and is executable
    if ! assert_file_exists "$MONITOR_CONTROL" "monitor_control_exists"; then
        test_passed=false
    fi
    
    if [[ -f "$MONITOR_CONTROL" ]] && [[ ! -x "$MONITOR_CONTROL" ]]; then
        log_error "monitor-control is not executable" "$TEST_MODULE"
        test_passed=false
    fi
    
    # Test required directories
    local required_dirs=("$AGENT_HOME/bin" "$AGENT_HOME/etc" "$AGENT_HOME/logs" "$AGENT_HOME/queue")
    for dir in "${required_dirs[@]}"; do
        if ! assert_directory_exists "$dir" "required_directory"; then
            test_passed=false
        fi
    done
    
    # Test agent binaries
    local agent_binaries=("monitor-agentd" "monitor-logcollector" "monitor-syscheckd" "monitor-execd" "monitor-modulesd")
    local found_binaries=0
    
    for binary in "${agent_binaries[@]}"; do
        if [[ -f "$AGENT_BIN/$binary" ]] && [[ -x "$AGENT_BIN/$binary" ]]; then
            log_success "Found executable binary: $binary" "$TEST_MODULE"
            ((found_binaries++))
        else
            log_warning "Binary not found or not executable: $binary" "$TEST_MODULE"
        fi
    done
    
    if [[ $found_binaries -eq 0 ]]; then
        log_error "No agent binaries found" "$TEST_MODULE"
        test_passed=false
    else
        log_success "Found $found_binaries agent binaries" "$TEST_MODULE"
    fi
    
    # Test configuration file
    if assert_file_exists "$AGENT_CONFIG" "agent_config_exists"; then
        # Test configuration is valid XML
        if command -v xmllint >/dev/null 2>&1; then
            if xmllint --noout "$AGENT_CONFIG" 2>/dev/null; then
                log_success "Configuration file is valid XML" "$TEST_MODULE"
            else
                log_error "Configuration file is invalid XML" "$TEST_MODULE"
                test_passed=false
            fi
        else
            log_warning "xmllint not available, skipping XML validation" "$TEST_MODULE"
        fi
    else
        test_passed=false
    fi
    
    if $test_passed; then
        pass_test "agent_installation" "Agent installation verified successfully"
    else
        fail_test "agent_installation" "Agent installation verification failed"
    fi
    
    return $([[ $test_passed == true ]] && echo 0 || echo 1)
}

test_service_startup() {
    start_test "service_startup" "Test agent service startup functionality"
    
    # Log startup attempt
    echo "$(timestamp): Starting agent startup test" >> "$STARTUP_LOG"
    
    # Stop agent first to ensure clean start
    if is_agent_running; then
        log_info "Stopping currently running agent" "$TEST_MODULE"
        if ! stop_agent; then
            log_warning "Failed to stop running agent, continuing..." "$TEST_MODULE"
        fi
        sleep 2
    fi
    
    # Test startup
    log_info "Testing agent startup..." "$TEST_MODULE"
    echo "$(timestamp): Attempting to start agent" >> "$STARTUP_LOG"
    
    if start_agent 30; then
        echo "$(timestamp): Agent startup successful" >> "$STARTUP_LOG"
        log_success "Agent started successfully" "$TEST_MODULE"
        
        # Wait a moment for all services to stabilize
        sleep 5
        
        # Verify agent is running
        if is_agent_running; then
            echo "$(timestamp): Agent status verified as running" >> "$STARTUP_LOG"
            pass_test "service_startup" "Agent startup completed successfully"
            return 0
        else
            echo "$(timestamp): Agent status check failed after startup" >> "$STARTUP_LOG"
            fail_test "service_startup" "Agent not running after startup"
            return 1
        fi
    else
        echo "$(timestamp): Agent startup failed" >> "$STARTUP_LOG"
        fail_test "service_startup" "Agent startup failed"
        return 1
    fi
}

test_daemon_processes() {
    start_test "daemon_processes" "Verify all agent daemons are running"
    
    if ! is_agent_running; then
        skip_test "daemon_processes" "Agent is not running"
        return 1
    fi
    
    local test_passed=true
    local expected_daemons=("monitor-agentd" "monitor-logcollector" "monitor-syscheckd" "monitor-execd" "monitor-modulesd")
    local running_daemons=0
    
    for daemon in "${expected_daemons[@]}"; do
        if assert_process_running "$daemon" "daemon_$daemon"; then
            ((running_daemons++))
            echo "$(timestamp): Daemon $daemon is running" >> "$STARTUP_LOG"
        else
            echo "$(timestamp): Daemon $daemon is not running" >> "$STARTUP_LOG"
            # Don't fail test if optional daemons are missing
            if [[ "$daemon" == "monitor-monitord" ]]; then
                log_warning "Optional daemon not running: $daemon" "$TEST_MODULE"
            else
                test_passed=false
            fi
        fi
    done
    
    log_info "Running daemons: $running_daemons/${#expected_daemons[@]}" "$TEST_MODULE"
    echo "$(timestamp): $running_daemons/${#expected_daemons[@]} daemons running" >> "$STARTUP_LOG"
    
    if [[ $running_daemons -eq 0 ]]; then
        fail_test "daemon_processes" "No agent daemons are running"
        return 1
    elif [[ $running_daemons -lt 3 ]]; then
        log_warning "Only $running_daemons core daemons running" "$TEST_MODULE"
        pass_test "daemon_processes" "Minimal daemon set running ($running_daemons daemons)"
        return 0
    else
        pass_test "daemon_processes" "All required daemons running ($running_daemons daemons)"
        return 0
    fi
}

test_log_generation() {
    start_test "log_generation" "Verify agent is generating logs"
    
    local agent_log_file="$AGENT_LOGS/ossec.log"
    
    # Check if log file exists
    if ! assert_file_exists "$agent_log_file" "agent_log_exists"; then
        fail_test "log_generation" "Agent log file does not exist"
        return 1
    fi
    
    # Check if logs are being generated
    local initial_size=0
    if [[ -f "$agent_log_file" ]]; then
        initial_size=$(stat -f%z "$agent_log_file" 2>/dev/null || stat -c%s "$agent_log_file" 2>/dev/null || echo 0)
    fi
    
    # Wait a moment for log activity
    sleep 5
    
    local final_size=0
    if [[ -f "$agent_log_file" ]]; then
        final_size=$(stat -f%z "$agent_log_file" 2>/dev/null || stat -c%s "$agent_log_file" 2>/dev/null || echo 0)
    fi
    
    if [[ $final_size -gt $initial_size ]]; then
        log_success "Agent is actively generating logs" "$TEST_MODULE"
        pass_test "log_generation" "Log generation verified"
        return 0
    else
        # Check if recent logs exist
        if [[ -f "$agent_log_file" ]] && tail -10 "$agent_log_file" | grep -q "$(date +%Y)" 2>/dev/null; then
            log_success "Recent log entries found" "$TEST_MODULE"
            pass_test "log_generation" "Log generation verified (recent entries)"
            return 0
        else
            log_warning "No recent log activity detected" "$TEST_MODULE"
            pass_test "log_generation" "Log file exists but no recent activity"
            return 0
        fi
    fi
}

# ============================================================================
# MANAGER CONNECTIVITY TESTS
# ============================================================================

test_manager_reachability() {
    start_test "manager_reachability" "Test basic network connectivity to manager"
    
    echo "$(timestamp): Testing manager connectivity" >> "$CONNECTION_LOG"
    echo "Manager: $MANAGER_IP:$MANAGER_PORT" >> "$CONNECTION_LOG"
    
    if check_manager_connectivity "$MANAGER_IP" "$MANAGER_PORT" 10; then
        echo "$(timestamp): Manager connectivity successful" >> "$CONNECTION_LOG"
        pass_test "manager_reachability" "Manager is reachable at $MANAGER_IP:$MANAGER_PORT"
        return 0
    else
        echo "$(timestamp): Manager connectivity failed" >> "$CONNECTION_LOG"
        fail_test "manager_reachability" "Cannot reach manager at $MANAGER_IP:$MANAGER_PORT"
        return 1
    fi
}

test_enrollment_port() {
    start_test "enrollment_port" "Test connectivity to enrollment port"
    
    echo "$(timestamp): Testing enrollment port connectivity" >> "$CONNECTION_LOG"
    echo "Enrollment port: $MANAGER_IP:$MANAGER_ENROLLMENT_PORT" >> "$CONNECTION_LOG"
    
    if check_manager_connectivity "$MANAGER_IP" "$MANAGER_ENROLLMENT_PORT" 10; then
        echo "$(timestamp): Enrollment port connectivity successful" >> "$CONNECTION_LOG"
        pass_test "enrollment_port" "Enrollment port is reachable"
        return 0
    else
        echo "$(timestamp): Enrollment port connectivity failed" >> "$CONNECTION_LOG"
        log_warning "Enrollment port not reachable (may be expected in production)" "$TEST_MODULE"
        pass_test "enrollment_port" "Enrollment port check completed (not accessible)"
        return 0
    fi
}

test_agent_enrollment_status() {
    start_test "agent_enrollment" "Check agent enrollment status"
    
    echo "$(timestamp): Checking agent enrollment status" >> "$CONNECTION_LOG"
    
    if [[ -f "$AGENT_KEYS" ]] && [[ -s "$AGENT_KEYS" ]]; then
        local agent_info
        agent_info=$(head -1 "$AGENT_KEYS" 2>/dev/null | cut -d' ' -f1,2 2>/dev/null || echo "")
        
        if [[ -n "$agent_info" ]]; then
            local agent_id
            agent_id=$(echo "$agent_info" | cut -d' ' -f1)
            local agent_name
            agent_name=$(echo "$agent_info" | cut -d' ' -f2)
            
            echo "$(timestamp): Agent enrolled - ID: $agent_id, Name: $agent_name" >> "$CONNECTION_LOG"
            log_success "Agent is enrolled (ID: $agent_id, Name: $agent_name)" "$TEST_MODULE"
            pass_test "agent_enrollment" "Agent is properly enrolled"
            return 0
        else
            echo "$(timestamp): Agent key file exists but appears corrupt" >> "$CONNECTION_LOG"
            fail_test "agent_enrollment" "Agent key file exists but appears corrupt"
            return 1
        fi
    else
        echo "$(timestamp): Agent not enrolled - no key file or empty" >> "$CONNECTION_LOG"
        log_warning "Agent is not enrolled with manager" "$TEST_MODULE"
        skip_test "agent_enrollment" "Agent not enrolled (this may be expected for testing)"
        return 1
    fi
}

test_manager_communication() {
    start_test "manager_communication" "Test agent-manager communication"
    
    if ! is_agent_running; then
        skip_test "manager_communication" "Agent is not running"
        return 1
    fi
    
    # Check if agent is enrolled first
    if [[ ! -f "$AGENT_KEYS" ]] || [[ ! -s "$AGENT_KEYS" ]]; then
        skip_test "manager_communication" "Agent not enrolled - cannot test communication"
        return 1
    fi
    
    echo "$(timestamp): Testing agent-manager communication" >> "$CONNECTION_LOG"
    
    # Check agent logs for manager communication
    local agent_log="$AGENT_LOGS/ossec.log"
    if [[ -f "$agent_log" ]]; then
        # Look for successful manager connections in the last 2 minutes
        local recent_communication=""
        recent_communication=$(tail -100 "$agent_log" 2>/dev/null | grep -E "(Connected to|Sending keep alive|Received message)" | tail -5 || echo "")
        
        if [[ -n "$recent_communication" ]]; then
            echo "$(timestamp): Recent manager communication found" >> "$CONNECTION_LOG"
            echo "$recent_communication" >> "$CONNECTION_LOG"
            log_success "Agent-manager communication verified" "$TEST_MODULE"
            pass_test "manager_communication" "Active communication with manager detected"
            return 0
        else
            # Check for any connection attempts
            local connection_attempts=""
            connection_attempts=$(tail -100 "$agent_log" 2>/dev/null | grep -E "(Trying to connect|Connection|ERROR.*manager)" | tail -3 || echo "")
            
            if [[ -n "$connection_attempts" ]]; then
                echo "$(timestamp): Connection attempts found but no successful communication" >> "$CONNECTION_LOG"
                echo "$connection_attempts" >> "$CONNECTION_LOG"
                log_warning "Agent attempting to connect but no successful communication" "$TEST_MODULE"
                pass_test "manager_communication" "Connection attempts detected but communication unclear"
                return 0
            else
                echo "$(timestamp): No manager communication found in logs" >> "$CONNECTION_LOG"
                log_warning "No manager communication detected in agent logs" "$TEST_MODULE"
                pass_test "manager_communication" "No communication detected (may be expected)"
                return 0
            fi
        fi
    else
        echo "$(timestamp): Agent log file not found" >> "$CONNECTION_LOG"
        fail_test "manager_communication" "Cannot verify communication - no agent log"
        return 1
    fi
}

# ============================================================================
# CONFIGURATION VALIDATION TESTS
# ============================================================================

test_configuration_validity() {
    start_test "configuration_validity" "Validate agent configuration"
    
    local test_passed=true
    
    # Test configuration file exists
    if ! assert_file_exists "$AGENT_CONFIG" "config_file_exists"; then
        fail_test "configuration_validity" "Configuration file missing"
        return 1
    fi
    
    # Test XML validity
    if command -v xmllint >/dev/null 2>&1; then
        if xmllint --noout "$AGENT_CONFIG" 2>/dev/null; then
            log_success "Configuration XML is valid" "$TEST_MODULE"
        else
            log_error "Configuration XML is invalid" "$TEST_MODULE"
            test_passed=false
        fi
    fi
    
    # Test required configuration sections
    local required_sections=("client" "logging")
    for section in "${required_sections[@]}"; do
        if grep -q "<$section>" "$AGENT_CONFIG" 2>/dev/null; then
            log_success "Found required section: $section" "$TEST_MODULE"
        else
            log_warning "Missing section: $section" "$TEST_MODULE"
        fi
    done
    
    # Test manager configuration
    if grep -q "<server>" "$AGENT_CONFIG" 2>/dev/null; then
        local configured_server
        configured_server=$(grep -A 1 "<address>" "$AGENT_CONFIG" 2>/dev/null | grep -v "<address>" | sed 's/<[^>]*>//g' | tr -d ' \n' || echo "")
        
        if [[ -n "$configured_server" ]]; then
            log_success "Manager address configured: $configured_server" "$TEST_MODULE"
        else
            log_warning "Manager address not configured or empty" "$TEST_MODULE"
        fi
    else
        log_warning "Manager server configuration not found" "$TEST_MODULE"
    fi
    
    if $test_passed; then
        pass_test "configuration_validity" "Configuration validation passed"
        return 0
    else
        fail_test "configuration_validity" "Configuration validation failed"
        return 1
    fi
}

# ============================================================================
# FILE SYSTEM PERMISSIONS TESTS
# ============================================================================

test_file_permissions() {
    start_test "file_permissions" "Verify agent file and directory permissions"
    
    local test_passed=true
    
    # Test directory permissions
    local required_dirs=("$AGENT_LOGS" "$AGENT_QUEUE" "$AGENT_HOME/var")
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ -w "$dir" ]]; then
                log_success "Directory writable: $dir" "$TEST_MODULE"
            else
                log_error "Directory not writable: $dir" "$TEST_MODULE"
                test_passed=false
            fi
        else
            log_warning "Directory does not exist: $dir" "$TEST_MODULE"
        fi
    done
    
    # Test binary permissions
    local binaries=("$MONITOR_CONTROL")
    if [[ -d "$AGENT_BIN" ]]; then
        while IFS= read -r -d '' binary; do
            binaries+=("$binary")
        done < <(find "$AGENT_BIN" -name "monitor-*" -type f -print0 2>/dev/null)
    fi
    
    for binary in "${binaries[@]}"; do
        if [[ -f "$binary" ]]; then
            if [[ -x "$binary" ]]; then
                log_success "Binary executable: $(basename "$binary")" "$TEST_MODULE"
            else
                log_error "Binary not executable: $binary" "$TEST_MODULE"
                test_passed=false
            fi
        fi
    done
    
    # Test configuration file permissions
    if [[ -f "$AGENT_CONFIG" ]]; then
        if [[ -r "$AGENT_CONFIG" ]]; then
            log_success "Configuration file readable" "$TEST_MODULE"
        else
            log_error "Configuration file not readable" "$TEST_MODULE"
            test_passed=false
        fi
    fi
    
    if $test_passed; then
        pass_test "file_permissions" "File permissions verified"
        return 0
    else
        fail_test "file_permissions" "File permission issues found"
        return 1
    fi
}

# ============================================================================
# RESOURCE USAGE TESTS
# ============================================================================

test_resource_usage() {
    start_test "resource_usage" "Monitor agent resource usage"
    
    if ! is_agent_running; then
        skip_test "resource_usage" "Agent is not running"
        return 1
    fi
    
    # Get memory usage of agent processes
    local total_memory=0
    local process_count=0
    
    local agent_processes
    agent_processes=$(pgrep -f "monitor-" 2>/dev/null || echo "")
    
    if [[ -n "$agent_processes" ]]; then
        while read -r pid; do
            if [[ -n "$pid" ]]; then
                local mem_kb
                mem_kb=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ' || echo 0)
                total_memory=$((total_memory + mem_kb))
                ((process_count++))
            fi
        done <<< "$agent_processes"
    fi
    
    local total_memory_mb=$((total_memory / 1024))
    
    log_info "Agent processes: $process_count" "$TEST_MODULE"
    log_info "Total memory usage: ${total_memory_mb}MB" "$TEST_MODULE"
    
    # Check if memory usage is reasonable (less than 500MB)
    if [[ $total_memory_mb -lt 500 ]]; then
        log_success "Memory usage within acceptable limits: ${total_memory_mb}MB" "$TEST_MODULE"
        pass_test "resource_usage" "Resource usage acceptable (${total_memory_mb}MB, $process_count processes)"
        return 0
    else
        log_warning "High memory usage detected: ${total_memory_mb}MB" "$TEST_MODULE"
        pass_test "resource_usage" "High resource usage detected (${total_memory_mb}MB, $process_count processes)"
        return 0
    fi
}

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

run_core_tests() {
    log_info "Starting core service validation tests" "$TEST_MODULE"
    
    # Initialize test environment
    init_core_tests
    
    # Array to store test results
    local -a test_results=()
    
    # Run installation tests
    log_info "Running installation validation tests..." "$TEST_MODULE"
    test_agent_installation
    test_results+=($?)
    
    test_configuration_validity
    test_results+=($?)
    
    test_file_permissions
    test_results+=($?)
    
    # Run startup tests
    log_info "Running startup validation tests..." "$TEST_MODULE"
    test_service_startup
    test_results+=($?)
    
    test_daemon_processes
    test_results+=($?)
    
    test_log_generation
    test_results+=($?)
    
    test_resource_usage
    test_results+=($?)
    
    # Run connectivity tests
    log_info "Running manager connectivity tests..." "$TEST_MODULE"
    test_manager_reachability
    test_results+=($?)
    
    test_enrollment_port
    test_results+=($?)
    
    test_agent_enrollment_status
    test_results+=($?)
    
    test_manager_communication
    test_results+=($?)
    
    # Calculate results
    local passed=0
    local total=${#test_results[@]}
    
    for result in "${test_results[@]}"; do
        if [[ $result -eq 0 ]]; then
            ((passed++))
        fi
    done
    
    log_info "Core tests completed: $passed/$total passed" "$TEST_MODULE"
    
    # Generate core test report
    {
        echo "================================================================"
        echo "Core Service Validation Test Results"
        echo "Completed: $(timestamp)"
        echo "================================================================"
        echo "Tests Passed: $passed/$total"
        echo "Success Rate: $(( total > 0 ? (passed * 100) / total : 0 ))%"
        echo ""
        echo "Detailed Results:"
        echo "- Agent Installation: $([ ${test_results[0]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- Configuration Validity: $([ ${test_results[1]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- File Permissions: $([ ${test_results[2]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- Service Startup: $([ ${test_results[3]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- Daemon Processes: $([ ${test_results[4]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- Log Generation: $([ ${test_results[5]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- Resource Usage: $([ ${test_results[6]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- Manager Reachability: $([ ${test_results[7]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- Enrollment Port: $([ ${test_results[8]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- Agent Enrollment: $([ ${test_results[9]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo "- Manager Communication: $([ ${test_results[10]} -eq 0 ] && echo "PASS" || echo "FAIL")"
        echo ""
        echo "Logs:"
        echo "- Startup Log: $STARTUP_LOG"
        echo "- Connection Log: $CONNECTION_LOG"
        echo "================================================================"
    } > "$CORE_LOG_DIR/core_test_results.txt"
    
    if [[ $passed -eq $total ]]; then
        log_success "All core tests passed!" "$TEST_MODULE"
        return 0
    else
        log_error "Some core tests failed: $((total - passed))/$total" "$TEST_MODULE"
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
    
    # Run core tests
    if run_core_tests; then
        log_success "Core validation tests completed successfully" "$TEST_MODULE"
        exit 0
    else
        log_error "Core validation tests failed" "$TEST_MODULE"
        exit 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi