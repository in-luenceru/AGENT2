#!/bin/bash

# Professional-grade Testing Library for Wazuh Monitoring Agent
# Author: Cybersecurity QA Engineer
# Version: 1.0
# Description: Core testing utilities and shared functions

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Test framework configuration
TEST_FRAMEWORK_VERSION="1.0"
TEST_START_TIME=""
TEST_END_TIME=""
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
WARNINGS=0

# Paths and directories
AGENT_HOME="${AGENT_HOME:-/workspaces/AGENT2}"
MONITOR_CONTROL="$AGENT_HOME/monitor-control"
TEST_ROOT="$AGENT_HOME/test"
LOG_DIR="$TEST_ROOT/logs"
REPORT_DIR="$TEST_ROOT/report"
DATA_DIR="$TEST_ROOT/data"

# Agent configuration
AGENT_CONFIG="$AGENT_HOME/etc/ossec.conf"
AGENT_KEYS="$AGENT_HOME/etc/client.keys"
AGENT_LOGS="$AGENT_HOME/logs"
AGENT_QUEUE="$AGENT_HOME/queue"
AGENT_BIN="$AGENT_HOME/bin"

# Manager configuration
MANAGER_IP="${MANAGER_IP:-172.20.0.2}"
MANAGER_PORT="${MANAGER_PORT:-1514}"
MANAGER_ENROLLMENT_PORT="${MANAGER_ENROLLMENT_PORT:-1515}"
MANAGER_API_PORT="${MANAGER_API_PORT:-55000}"

# Docker manager configuration
DOCKER_MANAGER_NAME="${DOCKER_MANAGER_NAME:-wazuh-manager}"
DOCKER_NETWORK="${DOCKER_NETWORK:-wazuh}"

# Test configuration
TEST_TIMEOUT="${TEST_TIMEOUT:-60}"
ALERT_WAIT_TIME="${ALERT_WAIT_TIME:-30}"
SERVICE_START_TIMEOUT="${SERVICE_START_TIMEOUT:-60}"
MAX_RETRIES="${MAX_RETRIES:-3}"

# Colors for output
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r PURPLE='\033[0;35m'
declare -r CYAN='\033[0;36m'
declare -r WHITE='\033[1;37m'
declare -r NC='\033[0m' # No Color

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

# Initialize logging
init_logging() {
    mkdir -p "$LOG_DIR" "$REPORT_DIR" "$DATA_DIR"
    TEST_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create master test log
    local test_log="$LOG_DIR/test_framework.log"
    {
        echo "================================================================"
        echo "Wazuh Monitoring Agent Test Framework - Version $TEST_FRAMEWORK_VERSION"
        echo "Test Session Started: $TEST_START_TIME"
        echo "Agent Home: $AGENT_HOME"
        echo "Manager: $MANAGER_IP:$MANAGER_PORT"
        echo "================================================================"
    } > "$test_log"
}

# Timestamp function
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Log with level and color
log_with_level() {
    local level="$1"
    local color="$2"
    local message="$3"
    local test_name="${4:-FRAMEWORK}"
    local log_file="${5:-$LOG_DIR/test_framework.log}"
    
    local timestamp="$(timestamp)"
    
    # Console output with color
    echo -e "${color}[$timestamp] [$level] [$test_name]${NC} $message"
    
    # File output without color
    echo "[$timestamp] [$level] [$test_name] $message" >> "$log_file"
}

# Specific logging functions
log_info() {
    log_with_level "INFO" "$BLUE" "$1" "${2:-FRAMEWORK}" "${3:-$LOG_DIR/test_framework.log}"
}

log_success() {
    log_with_level "SUCCESS" "$GREEN" "$1" "${2:-FRAMEWORK}" "${3:-$LOG_DIR/test_framework.log}"
}

log_warning() {
    log_with_level "WARNING" "$YELLOW" "$1" "${2:-FRAMEWORK}" "${3:-$LOG_DIR/test_framework.log}"
    ((WARNINGS++))
}

log_error() {
    log_with_level "ERROR" "$RED" "$1" "${2:-FRAMEWORK}" "${3:-$LOG_DIR/test_framework.log}"
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        log_with_level "DEBUG" "$PURPLE" "$1" "${2:-FRAMEWORK}" "${3:-$LOG_DIR/test_framework.log}"
    fi
}

log_test() {
    log_with_level "TEST" "$CYAN" "$1" "${2:-FRAMEWORK}" "${3:-$LOG_DIR/test_framework.log}"
}

# ============================================================================
# TEST RESULT FUNCTIONS
# ============================================================================

# Test assertion functions
assert_true() {
    local condition="$1"
    local test_name="${2:-assertion}"
    
    if eval "$condition" >/dev/null 2>&1; then
        log_success "PASS: $test_name - Condition '$condition' is true" "$test_name"
        return 0
    else
        log_error "FAIL: $test_name - Condition '$condition' is false" "$test_name"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local test_name="${2:-assertion}"
    
    if ! eval "$condition" >/dev/null 2>&1; then
        log_success "PASS: $test_name - Condition '$condition' is false" "$test_name"
        return 0
    else
        log_error "FAIL: $test_name - Condition '$condition' is true" "$test_name"
        return 1
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="${3:-assertion}"
    
    if [[ "$expected" == "$actual" ]]; then
        log_success "PASS: $test_name - Expected '$expected', got '$actual'" "$test_name"
        return 0
    else
        log_error "FAIL: $test_name - Expected '$expected', got '$actual'" "$test_name"
        return 1
    fi
}

assert_not_equals() {
    local not_expected="$1"
    local actual="$2"
    local test_name="${3:-assertion}"
    
    if [[ "$not_expected" != "$actual" ]]; then
        log_success "PASS: $test_name - Value '$actual' is not '$not_expected'" "$test_name"
        return 0
    else
        log_error "FAIL: $test_name - Value should not be '$not_expected'" "$test_name"
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1"
    local test_name="${2:-file_exists}"
    
    if [[ -f "$file_path" ]]; then
        log_success "PASS: $test_name - File exists: $file_path" "$test_name"
        return 0
    else
        log_error "FAIL: $test_name - File does not exist: $file_path" "$test_name"
        return 1
    fi
}

assert_directory_exists() {
    local dir_path="$1"
    local test_name="${2:-directory_exists}"
    
    if [[ -d "$dir_path" ]]; then
        log_success "PASS: $test_name - Directory exists: $dir_path" "$test_name"
        return 0
    else
        log_error "FAIL: $test_name - Directory does not exist: $dir_path" "$test_name"
        return 1
    fi
}

assert_process_running() {
    local process_name="$1"
    local test_name="${2:-process_running}"
    
    if pgrep -f "$process_name" >/dev/null; then
        log_success "PASS: $test_name - Process running: $process_name" "$test_name"
        return 0
    else
        log_error "FAIL: $test_name - Process not running: $process_name" "$test_name"
        return 1
    fi
}

assert_port_listening() {
    local port="$1"
    local test_name="${2:-port_listening}"
    
    if ss -tlnp 2>/dev/null | grep -q ":$port "; then
        log_success "PASS: $test_name - Port listening: $port" "$test_name"
        return 0
    else
        log_error "FAIL: $test_name - Port not listening: $port" "$test_name"
        return 1
    fi
}

assert_log_contains() {
    local log_file="$1"
    local pattern="$2"
    local test_name="${3:-log_contains}"
    local timeout="${4:-10}"
    
    local count=0
    while [[ $count -lt $timeout ]]; do
        if [[ -f "$log_file" ]] && grep -q "$pattern" "$log_file"; then
            log_success "PASS: $test_name - Log contains pattern: $pattern" "$test_name"
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    log_error "FAIL: $test_name - Log does not contain pattern after ${timeout}s: $pattern" "$test_name"
    return 1
}

# ============================================================================
# TEST EXECUTION FUNCTIONS
# ============================================================================

# Start a test
start_test() {
    local test_name="$1"
    local description="${2:-$test_name}"
    
    ((TOTAL_TESTS++))
    log_test "Starting test: $test_name - $description" "$test_name"
    
    # Create test-specific log file
    local test_log_dir="$LOG_DIR/$test_name"
    mkdir -p "$test_log_dir"
    echo "Test: $test_name" > "$test_log_dir/test.log"
    echo "Description: $description" >> "$test_log_dir/test.log"
    echo "Started: $(timestamp)" >> "$test_log_dir/test.log"
    echo "========================================" >> "$test_log_dir/test.log"
}

# Pass a test
pass_test() {
    local test_name="$1"
    local message="${2:-Test completed successfully}"
    
    ((PASSED_TESTS++))
    log_success "PASS: $test_name - $message" "$test_name"
    
    # Update test log
    local test_log_dir="$LOG_DIR/$test_name"
    if [[ -d "$test_log_dir" ]]; then
        echo "Result: PASS" >> "$test_log_dir/test.log"
        echo "Message: $message" >> "$test_log_dir/test.log"
        echo "Completed: $(timestamp)" >> "$test_log_dir/test.log"
    fi
}

# Fail a test
fail_test() {
    local test_name="$1"
    local message="${2:-Test failed}"
    
    ((FAILED_TESTS++))
    log_error "FAIL: $test_name - $message" "$test_name"
    
    # Update test log
    local test_log_dir="$LOG_DIR/$test_name"
    if [[ -d "$test_log_dir" ]]; then
        echo "Result: FAIL" >> "$test_log_dir/test.log"
        echo "Error: $message" >> "$test_log_dir/test.log"
        echo "Completed: $(timestamp)" >> "$test_log_dir/test.log"
    fi
}

# Skip a test
skip_test() {
    local test_name="$1"
    local reason="${2:-Test skipped}"
    
    ((SKIPPED_TESTS++))
    log_warning "SKIP: $test_name - $reason" "$test_name"
    
    # Update test log
    local test_log_dir="$LOG_DIR/$test_name"
    if [[ -d "$test_log_dir" ]]; then
        echo "Result: SKIP" >> "$test_log_dir/test.log"
        echo "Reason: $reason" >> "$test_log_dir/test.log"
        echo "Completed: $(timestamp)" >> "$test_log_dir/test.log"
    fi
}

# ============================================================================
# AGENT CONTROL FUNCTIONS
# ============================================================================

# Check if agent is running
is_agent_running() {
    "$MONITOR_CONTROL" status >/dev/null 2>&1
}

# Start the agent
start_agent() {
    local timeout="${1:-$SERVICE_START_TIMEOUT}"
    
    log_info "Starting Wazuh agent..." "AGENT"
    
    if "$MONITOR_CONTROL" start; then
        # Wait for services to be fully operational
        local count=0
        while [[ $count -lt $timeout ]]; do
            if is_agent_running; then
                log_success "Agent started successfully" "AGENT"
                return 0
            fi
            sleep 1
            ((count++))
        done
        
        log_error "Agent start timeout after ${timeout}s" "AGENT"
        return 1
    else
        log_error "Failed to start agent" "AGENT"
        return 1
    fi
}

# Stop the agent
stop_agent() {
    log_info "Stopping Wazuh agent..." "AGENT"
    
    if "$MONITOR_CONTROL" stop; then
        log_success "Agent stopped successfully" "AGENT"
        return 0
    else
        log_error "Failed to stop agent" "AGENT"
        return 1
    fi
}

# Restart the agent
restart_agent() {
    local timeout="${1:-$SERVICE_START_TIMEOUT}"
    
    log_info "Restarting Wazuh agent..." "AGENT"
    
    if "$MONITOR_CONTROL" restart; then
        # Wait for services to be fully operational
        local count=0
        while [[ $count -lt $timeout ]]; do
            if is_agent_running; then
                log_success "Agent restarted successfully" "AGENT"
                return 0
            fi
            sleep 1
            ((count++))
        done
        
        log_error "Agent restart timeout after ${timeout}s" "AGENT"
        return 1
    else
        log_error "Failed to restart agent" "AGENT"
        return 1
    fi
}

# Get agent status
get_agent_status() {
    "$MONITOR_CONTROL" status
}

# ============================================================================
# MANAGER INTERACTION FUNCTIONS
# ============================================================================

# Check manager connectivity
check_manager_connectivity() {
    local manager_ip="${1:-$MANAGER_IP}"
    local manager_port="${2:-$MANAGER_PORT}"
    local timeout="${3:-10}"
    
    log_info "Testing manager connectivity: $manager_ip:$manager_port" "MANAGER"
    
    if timeout "$timeout" bash -c "exec 3<>/dev/tcp/$manager_ip/$manager_port" 2>/dev/null; then
        exec 3<&-
        exec 3>&-
        log_success "Manager is reachable" "MANAGER"
        return 0
    else
        log_error "Manager is not reachable" "MANAGER"
        return 1
    fi
}

# Get manager logs (requires Docker access)
get_manager_logs() {
    local lines="${1:-100}"
    
    if command -v docker >/dev/null 2>&1; then
        docker logs --tail "$lines" "$DOCKER_MANAGER_NAME" 2>/dev/null || {
            log_warning "Cannot access manager logs via Docker" "MANAGER"
            return 1
        }
    else
        log_warning "Docker not available for manager log access" "MANAGER"
        return 1
    fi
}

# Check for alerts in manager
check_manager_alerts() {
    local pattern="${1:-.*}"
    local timeout="${2:-$ALERT_WAIT_TIME}"
    
    log_info "Checking for alerts in manager logs (pattern: $pattern)" "MANAGER"
    
    local count=0
    while [[ $count -lt $timeout ]]; do
        local alerts
        alerts=$(get_manager_logs 50 2>/dev/null | grep -E "$pattern" || echo "")
        
        if [[ -n "$alerts" ]]; then
            log_success "Found matching alerts in manager" "MANAGER"
            echo "$alerts" | head -5
            return 0
        fi
        
        sleep 1
        ((count++))
    done
    
    log_error "No matching alerts found within ${timeout}s" "MANAGER"
    return 1
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Wait for condition with timeout
wait_for_condition() {
    local condition="$1"
    local timeout="${2:-30}"
    local check_interval="${3:-1}"
    local description="${4:-condition}"
    
    log_info "Waiting for $description (timeout: ${timeout}s)" "UTIL"
    
    local count=0
    while [[ $count -lt $timeout ]]; do
        if eval "$condition"; then
            log_success "$description met" "UTIL"
            return 0
        fi
        sleep "$check_interval"
        ((count++))
    done
    
    log_error "$description not met within ${timeout}s" "UTIL"
    return 1
}

# Create test data file
create_test_file() {
    local file_path="$1"
    local content="${2:-Test data created at $(timestamp)}"
    
    mkdir -p "$(dirname "$file_path")"
    echo "$content" > "$file_path"
    log_info "Created test file: $file_path" "UTIL"
}

# Generate random test data
generate_random_data() {
    local length="${1:-32}"
    head -c "$length" /dev/urandom | base64 | tr -d '\n='
}

# Create malicious log entry
create_malicious_log() {
    local log_file="$1"
    local attack_type="${2:-generic}"
    
    local timestamp="$(date '+%b %d %H:%M:%S')"
    local hostname="$(hostname)"
    local malicious_entry=""
    
    case "$attack_type" in
        "failed_login")
            malicious_entry="$timestamp $hostname sshd[12345]: Failed password for invalid user admin from 192.168.1.100 port 22 ssh2"
            ;;
        "privilege_escalation")
            malicious_entry="$timestamp $hostname sudo: testuser : TTY=pts/0 ; PWD=/tmp ; USER=root ; COMMAND=/bin/bash"
            ;;
        "file_access")
            malicious_entry="$timestamp $hostname kernel: [12345.678] audit: type=1400 audit(1234567890.123:456): avc: denied { read } for pid=1234 comm=\"cat\" name=\"shadow\" dev=\"sda1\" ino=123456"
            ;;
        *)
            malicious_entry="$timestamp $hostname test[$$]: SECURITY_TEST_ALERT: Simulated attack pattern for testing"
            ;;
    esac
    
    echo "$malicious_entry" >> "$log_file"
    log_info "Added malicious log entry: $attack_type" "UTIL"
}

# ============================================================================
# CLEANUP FUNCTIONS
# ============================================================================

# Cleanup test environment
cleanup_test_env() {
    log_info "Cleaning up test environment..." "CLEANUP"
    
    # Remove test files from data directory
    if [[ -d "$DATA_DIR" ]]; then
        find "$DATA_DIR" -name "test_*" -type f -delete 2>/dev/null || true
    fi
    
    # Clean up temporary files
    rm -f /tmp/wazuh_test_* 2>/dev/null || true
    
    log_success "Test environment cleaned up" "CLEANUP"
}

# ============================================================================
# REPORTING FUNCTIONS
# ============================================================================

# Generate test summary
generate_test_summary() {
    TEST_END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    
    local summary_file="$REPORT_DIR/test_summary.txt"
    local duration=$(($(date -d "$TEST_END_TIME" +%s) - $(date -d "$TEST_START_TIME" +%s)))
    
    {
        echo "================================================================"
        echo "Wazuh Monitoring Agent Test Summary"
        echo "================================================================"
        echo "Framework Version: $TEST_FRAMEWORK_VERSION"
        echo "Test Session: $TEST_START_TIME to $TEST_END_TIME"
        echo "Duration: ${duration}s"
        echo ""
        echo "Results:"
        echo "  Total Tests: $TOTAL_TESTS"
        echo "  Passed: $PASSED_TESTS"
        echo "  Failed: $FAILED_TESTS"
        echo "  Skipped: $SKIPPED_TESTS"
        echo "  Warnings: $WARNINGS"
        echo ""
        echo "Success Rate: $(( TOTAL_TESTS > 0 ? (PASSED_TESTS * 100) / TOTAL_TESTS : 0 ))%"
        echo ""
        
        if [[ $FAILED_TESTS -eq 0 ]]; then
            echo "Overall Status: PASS ✓"
        else
            echo "Overall Status: FAIL ✗"
        fi
        
        echo ""
        echo "Logs Location: $LOG_DIR"
        echo "Reports Location: $REPORT_DIR"
        echo "================================================================"
    } > "$summary_file"
    
    # Also output to console
    cat "$summary_file"
}

# ============================================================================
# INITIALIZATION
# ============================================================================

# Initialize the test framework
init_test_framework() {
    echo -e "${CYAN}Initializing Wazuh Agent Test Framework v$TEST_FRAMEWORK_VERSION${NC}"
    
    # Check required commands
    local missing_commands=()
    for cmd in timeout grep awk sed curl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}" "INIT"
        return 1
    fi
    
    # Initialize logging
    init_logging
    
    # Check agent installation
    if [[ ! -f "$MONITOR_CONTROL" ]]; then
        log_error "Agent control script not found: $MONITOR_CONTROL" "INIT"
        return 1
    fi
    
    if [[ ! -x "$MONITOR_CONTROL" ]]; then
        log_error "Agent control script not executable: $MONITOR_CONTROL" "INIT"
        return 1
    fi
    
    log_success "Test framework initialized successfully" "INIT"
    return 0
}

# Export functions for use in test scripts
export -f log_info log_success log_warning log_error log_debug log_test
export -f start_test pass_test fail_test skip_test
export -f assert_true assert_false assert_equals assert_not_equals assert_file_exists assert_directory_exists
export -f assert_process_running assert_port_listening assert_log_contains
export -f start_agent stop_agent restart_agent is_agent_running get_agent_status
export -f check_manager_connectivity get_manager_logs check_manager_alerts
export -f wait_for_condition create_test_file generate_random_data create_malicious_log
export -f cleanup_test_env generate_test_summary

# Export variables
export TEST_ROOT LOG_DIR REPORT_DIR DATA_DIR AGENT_HOME MONITOR_CONTROL
export MANAGER_IP MANAGER_PORT MANAGER_ENROLLMENT_PORT MANAGER_API_PORT
export TEST_TIMEOUT ALERT_WAIT_TIME SERVICE_START_TIMEOUT MAX_RETRIES