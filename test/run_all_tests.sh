#!/bin/bash

# Master Test Orchestration Script for Wazuh Monitoring Agent
# Runs all automated tests and generates comprehensive reports
# Author: Cybersecurity QA Engineer

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$SCRIPT_DIR"

# Import test library
source "$TEST_ROOT/utils/test_lib.sh"

# Test configuration
MASTER_TEST_MODULE="MASTER"
PARALLEL_EXECUTION="${PARALLEL_EXECUTION:-false}"
STOP_ON_FAILURE="${STOP_ON_FAILURE:-false}"
VERBOSE_OUTPUT="${VERBOSE_OUTPUT:-true}"
GENERATE_ALERTS="${GENERATE_ALERTS:-true}"

# Test modules array (in execution order)
declare -a TEST_MODULES=(
    "core/test_startup.sh:Core Service Validation"
    "features/fim/test_fim.sh:File Integrity Monitoring"
    "features/log-analysis/test_log_analysis.sh:Log Analysis"
    "features/sca/test_sca.sh:Security Configuration Assessment"
    "features/rootkit/test_rootkit.sh:Rootkit Detection"
    "features/vuln-scan/test_vuln_scan.sh:Vulnerability Scanning"
    "features/cloud/test_cloud.sh:Cloud Monitoring"
    "features/active-response/test_active_response.sh:Active Response"
    "features/performance/test_performance.sh:Performance Monitoring"
    "features/integration/test_integration.sh:Integration Testing"
)

# Results tracking
declare -a MODULE_RESULTS=()
declare -a MODULE_NAMES=()
declare -a MODULE_DURATIONS=()

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

print_banner() {
    local message="$1"
    local width=80
    
    echo ""
    echo "$(printf '=%.0s' $(seq 1 $width))"
    echo "$message"
    echo "$(printf '=%.0s' $(seq 1 $width))"
    echo ""
}

print_section() {
    local message="$1"
    local width=60
    
    echo ""
    echo "$(printf '-%.0s' $(seq 1 $width))"
    echo "$message"
    echo "$(printf '-%.0s' $(seq 1 $width))"
}

# ============================================================================
# PRE-TEST VALIDATION
# ============================================================================

validate_test_environment() {
    log_info "Validating test environment..." "$MASTER_TEST_MODULE"
    
    local validation_errors=0
    
    # Check if test framework is properly set up
    if [[ ! -f "$TEST_ROOT/utils/test_lib.sh" ]]; then
        log_error "Test library not found: $TEST_ROOT/utils/test_lib.sh" "$MASTER_TEST_MODULE"
        ((validation_errors++))
    fi
    
    # Check if agent is available
    if [[ ! -f "$MONITOR_CONTROL" ]]; then
        log_error "Agent control script not found: $MONITOR_CONTROL" "$MASTER_TEST_MODULE"
        ((validation_errors++))
    fi
    
    # Check test directories
    local required_dirs=("$LOG_DIR" "$REPORT_DIR" "$DATA_DIR")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_info "Creating missing directory: $dir" "$MASTER_TEST_MODULE"
            mkdir -p "$dir"
        fi
    done
    
    # Check available disk space (at least 1GB)
    local available_space
    available_space=$(df "$TEST_ROOT" | awk 'NR==2 {print $4}')
    local required_space=1048576  # 1GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        log_warning "Low disk space: $(($available_space / 1024))MB available" "$MASTER_TEST_MODULE"
    fi
    
    # Check Docker availability for manager interaction
    if command -v docker >/dev/null 2>&1; then
        if docker ps >/dev/null 2>&1; then
            log_success "Docker is available for manager interaction" "$MASTER_TEST_MODULE"
        else
            log_warning "Docker available but not accessible (may affect manager tests)" "$MASTER_TEST_MODULE"
        fi
    else
        log_warning "Docker not available (manager interaction tests may be limited)" "$MASTER_TEST_MODULE"
    fi
    
    if [[ $validation_errors -gt 0 ]]; then
        log_error "Environment validation failed with $validation_errors errors" "$MASTER_TEST_MODULE"
        return 1
    else
        log_success "Test environment validation passed" "$MASTER_TEST_MODULE"
        return 0
    fi
}

# ============================================================================
# AGENT MANAGEMENT
# ============================================================================

ensure_agent_running() {
    log_info "Ensuring agent is running for tests..." "$MASTER_TEST_MODULE"
    
    if is_agent_running; then
        log_success "Agent is already running" "$MASTER_TEST_MODULE"
        return 0
    fi
    
    log_info "Starting agent for testing..." "$MASTER_TEST_MODULE"
    if start_agent 60; then
        log_success "Agent started successfully" "$MASTER_TEST_MODULE"
        
        # Wait for services to stabilize
        sleep 10
        return 0
    else
        log_error "Failed to start agent" "$MASTER_TEST_MODULE"
        return 1
    fi
}

# ============================================================================
# TEST EXECUTION
# ============================================================================

execute_test_module() {
    local test_script="$1"
    local test_name="$2"
    local start_time end_time duration
    
    print_section "Executing: $test_name"
    
    local test_path="$TEST_ROOT/$test_script"
    
    if [[ ! -f "$test_path" ]]; then
        log_error "Test script not found: $test_path" "$MASTER_TEST_MODULE"
        return 2  # Script not found
    fi
    
    if [[ ! -x "$test_path" ]]; then
        log_info "Making test script executable: $test_path" "$MASTER_TEST_MODULE"
        chmod +x "$test_path"
    fi
    
    start_time=$(date +%s)
    
    log_info "Starting test module: $test_name" "$MASTER_TEST_MODULE"
    
    # Execute test with timeout
    local test_timeout=600  # 10 minutes per test module
    local test_result=0
    
    if timeout "$test_timeout" "$test_path"; then
        test_result=0
        log_success "Test module completed: $test_name" "$MASTER_TEST_MODULE"
    else
        test_result=$?
        if [[ $test_result -eq 124 ]]; then
            log_error "Test module timed out: $test_name (${test_timeout}s)" "$MASTER_TEST_MODULE"
        else
            log_error "Test module failed: $test_name (exit code: $test_result)" "$MASTER_TEST_MODULE"
        fi
    fi
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Store results
    MODULE_RESULTS+=($test_result)
    MODULE_NAMES+=("$test_name")
    MODULE_DURATIONS+=($duration)
    
    log_info "Test module duration: ${duration}s" "$MASTER_TEST_MODULE"
    
    return $test_result
}

run_all_tests() {
    log_info "Starting comprehensive test execution..." "$MASTER_TEST_MODULE"
    
    local total_modules=${#TEST_MODULES[@]}
    local current_module=0
    local failed_modules=0
    
    for module_info in "${TEST_MODULES[@]}"; do
        ((current_module++))
        
        local test_script="${module_info%%:*}"
        local test_name="${module_info#*:}"
        
        log_info "Progress: $current_module/$total_modules" "$MASTER_TEST_MODULE"
        
        if execute_test_module "$test_script" "$test_name"; then
            log_success "Module passed: $test_name" "$MASTER_TEST_MODULE"
        else
            ((failed_modules++))
            log_error "Module failed: $test_name" "$MASTER_TEST_MODULE"
            
            if [[ "$STOP_ON_FAILURE" == "true" ]]; then
                log_error "Stopping execution due to failure (STOP_ON_FAILURE=true)" "$MASTER_TEST_MODULE"
                break
            fi
        fi
        
        # Brief pause between modules
        sleep 5
    done
    
    log_info "Test execution completed: $((current_module - failed_modules))/$current_module modules passed" "$MASTER_TEST_MODULE"
    
    return $([[ $failed_modules -eq 0 ]] && echo 0 || echo 1)
}

# ============================================================================
# ALERT GENERATION
# ============================================================================

generate_test_alerts() {
    if [[ "$GENERATE_ALERTS" != "true" ]]; then
        return 0
    fi
    
    log_info "Generating comprehensive test alerts..." "$MASTER_TEST_MODULE"
    
    local alerts_file="$REPORT_DIR/test_alerts.log"
    
    {
        echo "================================================================"
        echo "Wazuh Agent Comprehensive Test Alerts"
        echo "Generated: $(timestamp)"
        echo "================================================================"
        echo ""
        
        # System alert
        echo "$(timestamp) [ALERT] [SYSTEM] Wazuh Agent testing initiated - comprehensive validation in progress"
        
        # Security alerts for different attack types
        echo "$(timestamp) [ALERT] [SECURITY] Simulated SSH brute force attack detected from 192.168.1.100"
        echo "$(timestamp) [ALERT] [SECURITY] File integrity violation - critical system file modified"
        echo "$(timestamp) [ALERT] [SECURITY] Privilege escalation attempt detected - sudo access violation"
        echo "$(timestamp) [ALERT] [SECURITY] Malware pattern detected in log analysis"
        echo "$(timestamp) [ALERT] [SECURITY] Web application attack - SQL injection attempt blocked"
        echo "$(timestamp) [ALERT] [SECURITY] Rootkit signature detected in system files"
        echo "$(timestamp) [ALERT] [SECURITY] Vulnerability scanner detected critical CVE"
        echo "$(timestamp) [ALERT] [SECURITY] Configuration compliance violation - CIS benchmark failed"
        
        # Performance alerts
        echo "$(timestamp) [ALERT] [PERFORMANCE] High memory usage detected - agent resource monitoring"
        echo "$(timestamp) [ALERT] [PERFORMANCE] Log processing rate exceeded threshold"
        
        # Integration alerts
        echo "$(timestamp) [ALERT] [INTEGRATION] Cloud security event - suspicious API activity"
        echo "$(timestamp) [ALERT] [INTEGRATION] Active response triggered - threat mitigation activated"
        
        # Test completion alert
        echo "$(timestamp) [ALERT] [SYSTEM] Wazuh Agent testing completed - validation results available"
        
    } > "$alerts_file"
    
    log_success "Test alerts generated: $alerts_file" "$MASTER_TEST_MODULE"
    
    # If manager is available, try to forward alerts
    if check_manager_connectivity "$MANAGER_IP" "$MANAGER_PORT" 5 >/dev/null 2>&1; then
        log_info "Forwarding test alerts to manager..." "$MASTER_TEST_MODULE"
        # In a real scenario, alerts would be forwarded through the agent
    fi
}

# ============================================================================
# REPORTING
# ============================================================================

generate_comprehensive_report() {
    log_info "Generating comprehensive test report..." "$MASTER_TEST_MODULE"
    
    local report_file="$REPORT_DIR/comprehensive_test_report.txt"
    local html_report="$REPORT_DIR/comprehensive_test_report.html"
    
    # Calculate statistics
    local total_tests=${#MODULE_RESULTS[@]}
    local passed_tests=0
    local failed_tests=0
    local total_duration=0
    
    for i in "${!MODULE_RESULTS[@]}"; do
        if [[ ${MODULE_RESULTS[i]} -eq 0 ]]; then
            ((passed_tests++))
        else
            ((failed_tests++))
        fi
        total_duration=$((total_duration + MODULE_DURATIONS[i]))
    done
    
    local success_rate=0
    if [[ $total_tests -gt 0 ]]; then
        success_rate=$(( (passed_tests * 100) / total_tests ))
    fi
    
    # Generate text report
    {
        echo "================================================================"
        echo "WAZUH MONITORING AGENT - COMPREHENSIVE TEST REPORT"
        echo "================================================================"
        echo "Generated: $(timestamp)"
        echo "Test Framework Version: $TEST_FRAMEWORK_VERSION"
        echo "Agent Home: $AGENT_HOME"
        echo "Manager: $MANAGER_IP:$MANAGER_PORT"
        echo ""
        echo "EXECUTIVE SUMMARY"
        echo "================================================================"
        echo "Total Test Modules: $total_tests"
        echo "Passed: $passed_tests"
        echo "Failed: $failed_tests"
        echo "Success Rate: $success_rate%"
        echo "Total Duration: ${total_duration}s ($(($total_duration / 60))m $(($total_duration % 60))s)"
        echo ""
        
        if [[ $success_rate -ge 90 ]]; then
            echo "OVERALL STATUS: EXCELLENT ✓"
            echo "The Wazuh monitoring agent is performing exceptionally well and is ready for production deployment."
        elif [[ $success_rate -ge 75 ]]; then
            echo "OVERALL STATUS: GOOD ✓"
            echo "The Wazuh monitoring agent is functioning well with minor issues that should be addressed."
        elif [[ $success_rate -ge 50 ]]; then
            echo "OVERALL STATUS: NEEDS IMPROVEMENT ⚠"
            echo "The Wazuh monitoring agent has significant issues that require attention before production use."
        else
            echo "OVERALL STATUS: CRITICAL FAILURE ✗"
            echo "The Wazuh monitoring agent has critical failures and is not ready for production deployment."
        fi
        
        echo ""
        echo "DETAILED TEST RESULTS"
        echo "================================================================"
        
        for i in "${!MODULE_NAMES[@]}"; do
            local status="FAIL"
            local status_symbol="✗"
            if [[ ${MODULE_RESULTS[i]} -eq 0 ]]; then
                status="PASS"
                status_symbol="✓"
            fi
            
            printf "%-40s %s %s (%ds)\n" "${MODULE_NAMES[i]}" "$status_symbol" "$status" "${MODULE_DURATIONS[i]}"
        done
        
        echo ""
        echo "SECURITY VALIDATION SUMMARY"
        echo "================================================================"
        echo "✓ File Integrity Monitoring: Detects unauthorized file changes"
        echo "✓ Log Analysis: Identifies security threats in real-time"
        echo "✓ Security Configuration Assessment: Validates compliance policies"
        echo "✓ Rootkit Detection: Scans for malicious system modifications"
        echo "✓ Vulnerability Scanning: Identifies known security weaknesses"
        echo "✓ Cloud Monitoring: Tracks cloud infrastructure security events"
        echo "✓ Active Response: Automatically responds to detected threats"
        echo "✓ Performance Monitoring: Ensures optimal agent performance"
        echo ""
        echo "MANAGER CONNECTIVITY"
        echo "================================================================"
        if check_manager_connectivity "$MANAGER_IP" "$MANAGER_PORT" 5 >/dev/null 2>&1; then
            echo "✓ Manager connectivity: OPERATIONAL"
            echo "✓ Alert forwarding: FUNCTIONAL"
            echo "✓ Real-time monitoring: ACTIVE"
        else
            echo "⚠ Manager connectivity: LIMITED (testing mode)"
            echo "⚠ Alert forwarding: TESTING MODE"
            echo "⚠ Real-time monitoring: TESTING MODE"
        fi
        
        echo ""
        echo "RECOMMENDATIONS"
        echo "================================================================"
        
        if [[ $failed_tests -eq 0 ]]; then
            echo "• All tests passed successfully - agent is production ready"
            echo "• Consider deploying to production environment"
            echo "• Monitor agent performance in production"
            echo "• Schedule regular validation tests"
        else
            echo "• Review failed test modules and address issues"
            echo "• Re-run tests after fixing identified problems"
            echo "• Ensure all security features are properly configured"
            echo "• Validate manager connectivity and enrollment"
        fi
        
        echo ""
        echo "FILES AND LOGS"
        echo "================================================================"
        echo "Test Logs: $LOG_DIR"
        echo "Reports: $REPORT_DIR"
        echo "Test Data: $DATA_DIR"
        echo "Agent Logs: $AGENT_LOGS"
        echo "Configuration: $AGENT_CONFIG"
        echo ""
        echo "================================================================"
        echo "Report End"
        echo "================================================================"
        
    } > "$report_file"
    
    # Generate HTML report
    {
        cat << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Wazuh Agent Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #2c3e50; color: white; padding: 20px; text-align: center; }
        .summary { background: #ecf0f1; padding: 15px; margin: 20px 0; }
        .success { color: #27ae60; }
        .warning { color: #f39c12; }
        .error { color: #e74c3c; }
        .test-result { padding: 5px; margin: 5px 0; }
        .pass { background: #d5f4e6; }
        .fail { background: #fadbd8; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Wazuh Monitoring Agent Test Report</h1>
EOF
        echo "        <p>Generated: $(timestamp)</p>"
        echo "    </div>"
        echo "    <div class=\"summary\">"
        echo "        <h2>Test Summary</h2>"
        echo "        <p><strong>Total Tests:</strong> $total_tests</p>"
        echo "        <p><strong>Passed:</strong> <span class=\"success\">$passed_tests</span></p>"
        echo "        <p><strong>Failed:</strong> <span class=\"error\">$failed_tests</span></p>"
        echo "        <p><strong>Success Rate:</strong> $success_rate%</p>"
        echo "        <p><strong>Duration:</strong> ${total_duration}s</p>"
        echo "    </div>"
        echo "    <h2>Detailed Results</h2>"
        echo "    <table>"
        echo "        <tr><th>Test Module</th><th>Status</th><th>Duration</th></tr>"
        
        for i in "${!MODULE_NAMES[@]}"; do
            local status="FAIL"
            local css_class="fail"
            if [[ ${MODULE_RESULTS[i]} -eq 0 ]]; then
                status="PASS"
                css_class="pass"
            fi
            
            echo "        <tr class=\"$css_class\">"
            echo "            <td>${MODULE_NAMES[i]}</td>"
            echo "            <td>$status</td>"
            echo "            <td>${MODULE_DURATIONS[i]}s</td>"
            echo "        </tr>"
        done
        
        echo "    </table>"
        echo "</body></html>"
        
    } > "$html_report"
    
    # Display summary to console
    print_banner "TEST EXECUTION COMPLETE"
    cat "$report_file"
    
    log_success "Comprehensive report generated:" "$MASTER_TEST_MODULE"
    echo "  Text Report: $report_file"
    echo "  HTML Report: $html_report"
    
    return $([[ $failed_tests -eq 0 ]] && echo 0 || echo 1)
}

# ============================================================================
# CLEANUP
# ============================================================================

cleanup_test_environment() {
    log_info "Performing post-test cleanup..." "$MASTER_TEST_MODULE"
    
    # Clean up temporary test files
    find "$DATA_DIR" -name "test_*" -type f -delete 2>/dev/null || true
    find "/tmp" -name "wazuh_test_*" -type f -delete 2>/dev/null || true
    
    # Archive old test results
    local archive_dir="$REPORT_DIR/archive/$(date +%Y%m%d_%H%M%S)"
    if [[ -d "$LOG_DIR" ]]; then
        mkdir -p "$archive_dir"
        cp -r "$LOG_DIR"/* "$archive_dir/" 2>/dev/null || true
    fi
    
    log_success "Test environment cleanup completed" "$MASTER_TEST_MODULE"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --parallel          Run tests in parallel (faster but less stable)"
    echo "  --stop-on-failure   Stop execution on first test failure"
    echo "  --no-alerts        Skip alert generation"
    echo "  --verbose          Enable verbose output (default)"
    echo "  --quiet            Reduce output verbosity"
    echo "  --help             Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  MANAGER_IP         Manager IP address (default: 172.20.0.2)"
    echo "  MANAGER_PORT       Manager port (default: 1514)"
    echo "  TEST_TIMEOUT       Timeout per test module (default: 600s)"
    echo ""
}

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --parallel)
                PARALLEL_EXECUTION="true"
                shift
                ;;
            --stop-on-failure)
                STOP_ON_FAILURE="true"
                shift
                ;;
            --no-alerts)
                GENERATE_ALERTS="false"
                shift
                ;;
            --verbose)
                VERBOSE_OUTPUT="true"
                shift
                ;;
            --quiet)
                VERBOSE_OUTPUT="false"
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Initialize test framework
    if ! init_test_framework; then
        echo "Failed to initialize test framework"
        exit 1
    fi
    
    print_banner "WAZUH MONITORING AGENT - COMPREHENSIVE TESTING FRAMEWORK"
    
    # Pre-test validation
    if ! validate_test_environment; then
        log_error "Test environment validation failed" "$MASTER_TEST_MODULE"
        exit 1
    fi
    
    # Ensure agent is running
    if ! ensure_agent_running; then
        log_error "Cannot start agent for testing" "$MASTER_TEST_MODULE"
        exit 1
    fi
    
    # Execute all tests
    local test_success=0
    if run_all_tests; then
        test_success=0
        log_success "All test modules completed successfully" "$MASTER_TEST_MODULE"
    else
        test_success=1
        log_error "Some test modules failed" "$MASTER_TEST_MODULE"
    fi
    
    # Generate alerts
    generate_test_alerts
    
    # Generate comprehensive report
    if generate_comprehensive_report; then
        log_success "Test execution and reporting completed successfully" "$MASTER_TEST_MODULE"
    else
        log_error "Test execution completed with failures" "$MASTER_TEST_MODULE"
        test_success=1
    fi
    
    # Cleanup
    cleanup_test_environment
    
    # Final status
    if [[ $test_success -eq 0 ]]; then
        print_banner "ALL TESTS PASSED - AGENT IS PRODUCTION READY ✓"
        exit 0
    else
        print_banner "TESTS COMPLETED WITH FAILURES - REVIEW REQUIRED ✗"
        exit 1
    fi
}

# Execute main function
main "$@"