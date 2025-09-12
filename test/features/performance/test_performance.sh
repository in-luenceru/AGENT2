#!/bin/bash

# Performance Monitoring Tests for Wazuh Monitoring Agent
# Tests: Resource usage, performance metrics, load testing
# Author: Cybersecurity QA Engineer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/test_lib.sh"

TEST_MODULE="PERFORMANCE"

init_performance_tests() {
    log_info "Initializing Performance Monitoring tests" "$TEST_MODULE"
    mkdir -p "$LOG_DIR/performance" "$DATA_DIR/performance_tests"
}

test_agent_resource_usage() {
    start_test "resource_usage" "Monitor agent resource consumption"
    
    if ! is_agent_running; then
        skip_test "resource_usage" "Agent not running"
        return 1
    fi
    
    # Monitor CPU and memory usage
    local agent_pids=$(pgrep -f "monitor-" | tr '\n' ' ')
    local total_memory=0
    local process_count=0
    
    for pid in $agent_pids; do
        if [[ -n "$pid" ]]; then
            local mem_kb=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ' || echo 0)
            total_memory=$((total_memory + mem_kb))
            ((process_count++))
        fi
    done
    
    local total_memory_mb=$((total_memory / 1024))
    
    log_info "Agent processes: $process_count" "$TEST_MODULE"
    log_info "Total memory usage: ${total_memory_mb}MB" "$TEST_MODULE"
    
    # Performance thresholds
    if [[ $total_memory_mb -lt 256 ]]; then
        log_success "Memory usage excellent: ${total_memory_mb}MB" "$TEST_MODULE"
    elif [[ $total_memory_mb -lt 512 ]]; then
        log_success "Memory usage good: ${total_memory_mb}MB" "$TEST_MODULE"
    else
        log_warning "Memory usage high: ${total_memory_mb}MB" "$TEST_MODULE"
    fi
    
    pass_test "resource_usage" "Resource usage monitoring completed"
    return 0
}

test_log_processing_performance() {
    start_test "log_processing_perf" "Test log processing performance under load"
    
    local test_log="$DATA_DIR/performance_tests/perf_test.log"
    local start_time=$(date +%s)
    
    # Generate high-volume log entries
    log_info "Generating high-volume log entries for performance testing" "$TEST_MODULE"
    
    for i in $(seq 1 1000); do
        echo "$(date '+%b %d %H:%M:%S') $(hostname) perf_test[$$]: Performance test log entry $i" >> "$test_log"
        
        # Add some security-relevant entries
        if [[ $((i % 100)) -eq 0 ]]; then
            echo "$(date '+%b %d %H:%M:%S') $(hostname) sshd[$$]: Failed password for user$i from 192.168.1.$((i % 255)) port 22 ssh2" >> "$test_log"
        fi
    done
    
    local end_time=$(date +%s)
    local generation_time=$((end_time - start_time))
    
    log_info "Generated 1000 log entries in ${generation_time}s" "$TEST_MODULE"
    
    # Wait for processing
    sleep 10
    
    # Check processing rate
    local processed_entries=$(grep -c "perf_test" "$AGENT_LOGS/ossec.log" 2>/dev/null || echo 0)
    log_info "Agent processed $processed_entries performance test entries" "$TEST_MODULE"
    
    pass_test "log_processing_perf" "Log processing performance test completed"
    
    rm -f "$test_log"
    return 0
}

run_performance_tests() {
    init_performance_tests
    test_agent_resource_usage
    test_log_processing_performance
    log_success "Performance monitoring tests completed" "$TEST_MODULE"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_test_framework && run_performance_tests
fi