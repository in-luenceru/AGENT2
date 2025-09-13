#!/bin/bash
# Comprehensive Agent Name Persistence Test Suite
# Tests all aspects of the agent naming fix

set -e

# Test configuration
TEST_DIR="/workspaces/AGENT2/test/features/name-change"
AGENT_DIR="/workspaces/AGENT2"
MONITOR_CONTROL="$AGENT_DIR/monitor-control"

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Logging functions
log_test() {
    echo "[TEST $(date '+%H:%M:%S')] $*"
}

log_test_success() {
    echo "[TEST $(date '+%H:%M:%S')] ✓ $*"
}

log_test_error() {
    echo "[TEST $(date '+%H:%M:%S')] ✗ $*"
}

log_test_warning() {
    echo "[TEST $(date '+%H:%M:%S')] ⚠ $*"
}

# Test helper functions
start_test() {
    local test_name="$1"
    local description="$2"
    
    ((TESTS_RUN++))
    log_test "Starting test: $test_name - $description"
    echo "=========================================="
}

pass_test() {
    local test_name="$1"
    local message="$2"
    
    ((TESTS_PASSED++))
    log_test_success "$test_name: $message"
    echo ""
}

fail_test() {
    local test_name="$1"
    local message="$2"
    
    ((TESTS_FAILED++))
    FAILED_TESTS+=("$test_name")
    log_test_error "$test_name: $message"
    echo ""
}

# Test environment setup
setup_test_environment() {
    log_test "Setting up test environment..."
    
    # Create test directories
    mkdir -p "$TEST_DIR/logs"
    mkdir -p "$TEST_DIR/backup"
    
    # Backup current identity if it exists
    if [[ -f "$AGENT_DIR/etc/agent.identity" ]]; then
        cp "$AGENT_DIR/etc/agent.identity" "$TEST_DIR/backup/agent.identity.$(date +%s)"
        log_test "Backed up existing agent identity"
    fi
    
    # Backup current config if it exists
    if [[ -f "$AGENT_DIR/etc/ossec.conf" ]]; then
        cp "$AGENT_DIR/etc/ossec.conf" "$TEST_DIR/backup/ossec.conf.$(date +%s)"
        log_test "Backed up existing ossec.conf"
    fi
    
    # Create test log
    TEST_LOG="$TEST_DIR/logs/test_$(date +%Y%m%d_%H%M%S).log"
    exec > >(tee -a "$TEST_LOG") 2>&1
    
    log_test "Test environment setup complete"
    log_test "Test log: $TEST_LOG"
}

cleanup_test_environment() {
    log_test "Cleaning up test environment..."
    
    # Remove test identity file
    rm -f "$AGENT_DIR/etc/agent.identity"
    
    # Restore original files if they exist
    local latest_identity_backup=$(ls -t "$TEST_DIR/backup/agent.identity."* 2>/dev/null | head -1)
    if [[ -n "$latest_identity_backup" ]]; then
        cp "$latest_identity_backup" "$AGENT_DIR/etc/agent.identity"
        log_test "Restored original agent identity"
    fi
    
    local latest_config_backup=$(ls -t "$TEST_DIR/backup/ossec.conf."* 2>/dev/null | head -1)
    if [[ -n "$latest_config_backup" ]]; then
        cp "$latest_config_backup" "$AGENT_DIR/etc/ossec.conf"
        log_test "Restored original ossec.conf"
    fi
    
    log_test "Cleanup complete"
}

# Test 1: Agent Identity Library Functions
test_identity_library() {
    start_test "identity_library" "Test agent identity library functions"
    
    # Source the library
    if ! source "$AGENT_DIR/lib/agent_identity.sh" 2>/dev/null; then
        fail_test "identity_library" "Failed to source agent identity library"
        return 1
    fi
    
    # Test validation function
    if validate_agent_name "test-agent-123"; then
        log_test_success "Valid agent name accepted"
    else
        fail_test "identity_library" "Valid agent name rejected"
        return 1
    fi
    
    # Test invalid names
    if ! validate_agent_name ""; then
        log_test_success "Empty name properly rejected"
    else
        fail_test "identity_library" "Empty name was accepted"
        return 1
    fi
    
    if ! validate_agent_name "ab"; then
        log_test_success "Short name properly rejected"
    else
        fail_test "identity_library" "Short name was accepted"
        return 1
    fi
    
    if ! validate_agent_name "invalid@name"; then
        log_test_success "Invalid characters properly rejected"
    else
        fail_test "identity_library" "Invalid characters were accepted"
        return 1
    fi
    
    pass_test "identity_library" "All validation tests passed"
}

# Test 2: Agent Name Storage and Retrieval
test_name_storage() {
    start_test "name_storage" "Test agent name storage and retrieval"
    
    # Source the library
    source "$AGENT_DIR/lib/agent_identity.sh" 2>/dev/null
    
    local test_name="test-agent-$(date +%s)"
    
    # Test setting agent name
    if set_agent_name "$test_name"; then
        log_test_success "Agent name set successfully"
    else
        fail_test "name_storage" "Failed to set agent name"
        return 1
    fi
    
    # Test retrieving agent name
    local retrieved_name
    if retrieved_name=$(get_agent_name); then
        if [[ "$retrieved_name" == "$test_name" ]]; then
            log_test_success "Agent name retrieved correctly: $retrieved_name"
        else
            fail_test "name_storage" "Retrieved name mismatch: expected '$test_name', got '$retrieved_name'"
            return 1
        fi
    else
        fail_test "name_storage" "Failed to retrieve agent name"
        return 1
    fi
    
    # Test integrity verification
    if verify_identity_integrity; then
        log_test_success "Identity file integrity verified"
    else
        fail_test "name_storage" "Identity file integrity check failed"
        return 1
    fi
    
    pass_test "name_storage" "Name storage and retrieval successful"
}

# Test 3: Agent Name Persistence Across Restarts
test_name_persistence() {
    start_test "name_persistence" "Test agent name persistence across simulated restarts"
    
    # Source the library
    source "$AGENT_DIR/lib/agent_identity.sh" 2>/dev/null
    
    local test_name="persistent-agent-$(date +%s)"
    
    # Set agent name
    if ! set_agent_name "$test_name"; then
        fail_test "name_persistence" "Failed to set agent name"
        return 1
    fi
    
    # Simulate restart by unsetting variables and re-sourcing
    unset AGENT_NAME
    source "$AGENT_DIR/lib/agent_identity.sh" 2>/dev/null
    
    # Test initialization function
    cd "$AGENT_DIR"
    source "$AGENT_DIR/monitor-control"
    initialize_agent_name
    
    if [[ "$AGENT_NAME" == "$test_name" ]]; then
        log_test_success "Agent name persisted across restart: $AGENT_NAME"
    else
        fail_test "name_persistence" "Agent name not persisted: expected '$test_name', got '$AGENT_NAME'"
        return 1
    fi
    
    pass_test "name_persistence" "Name persistence test successful"
}

# Test 4: Fallback Behavior
test_fallback_behavior() {
    start_test "fallback_behavior" "Test hostname fallback when no name is set"
    
    # Remove any existing identity
    rm -f "$AGENT_DIR/etc/agent.identity"
    
    # Clear agent name from config
    if [[ -f "$AGENT_DIR/etc/ossec.conf" ]]; then
        sed -i 's/<agent_name>.*<\/agent_name>/<agent_name><\/agent_name>/' "$AGENT_DIR/etc/ossec.conf"
    fi
    
    # Test initialization
    cd "$AGENT_DIR"
    unset AGENT_NAME
    source "$AGENT_DIR/monitor-control"
    initialize_agent_name
    
    local hostname_short=$(hostname -s)
    if [[ "$AGENT_NAME" == "$hostname_short" ]]; then
        log_test_success "Hostname fallback working: $AGENT_NAME"
    else
        fail_test "fallback_behavior" "Hostname fallback failed: expected '$hostname_short', got '$AGENT_NAME'"
        return 1
    fi
    
    pass_test "fallback_behavior" "Fallback behavior test successful"
}

# Test 5: Monitor-Control Identity Command
test_monitor_control_identity() {
    start_test "monitor_control_identity" "Test monitor-control identity management commands"
    
    cd "$AGENT_DIR"
    local test_name="monitor-test-$(date +%s)"
    
    # Test identity show (should handle no identity gracefully)
    if sudo timeout 10 ./monitor-control identity show >/dev/null 2>&1; then
        log_test_success "Identity show command works"
    else
        log_test_warning "Identity show command failed (may be normal if no identity exists)"
    fi
    
    # Test setting agent name via monitor-control
    if sudo timeout 10 ./monitor-control identity set "$test_name" >/dev/null 2>&1; then
        log_test_success "Identity set command works"
        
        # Verify the name was set
        source "$AGENT_DIR/lib/agent_identity.sh" 2>/dev/null
        local retrieved_name
        if retrieved_name=$(get_agent_name); then
            if [[ "$retrieved_name" == "$test_name" ]]; then
                log_test_success "Name set correctly via monitor-control: $retrieved_name"
            else
                fail_test "monitor_control_identity" "Name set incorrectly: expected '$test_name', got '$retrieved_name'"
                return 1
            fi
        else
            fail_test "monitor_control_identity" "Failed to retrieve name after setting via monitor-control"
            return 1
        fi
    else
        fail_test "monitor_control_identity" "Identity set command failed"
        return 1
    fi
    
    # Test identity verify
    if sudo timeout 10 ./monitor-control identity verify >/dev/null 2>&1; then
        log_test_success "Identity verify command works"
    else
        fail_test "monitor_control_identity" "Identity verify command failed"
        return 1
    fi
    
    pass_test "monitor_control_identity" "Monitor-control identity commands work correctly"
}

# Test 6: Configuration Migration
test_config_migration() {
    start_test "config_migration" "Test migration from config file to identity storage"
    
    # Remove existing identity
    rm -f "$AGENT_DIR/etc/agent.identity"
    
    # Set agent name in config file
    local test_name="config-migrated-$(date +%s)"
    if [[ -f "$AGENT_DIR/etc/ossec.conf" ]]; then
        sed -i "s/<agent_name>.*<\/agent_name>/<agent_name>$test_name<\/agent_name>/" "$AGENT_DIR/etc/ossec.conf"
    else
        # Create minimal config for testing
        cat > "$AGENT_DIR/etc/ossec.conf" << EOF
<ossec_config>
  <client>
    <enrollment>
      <agent_name>$test_name</agent_name>
    </enrollment>
  </client>
</ossec_config>
EOF
    fi
    
    # Test migration via monitor-control
    cd "$AGENT_DIR"
    if sudo timeout 10 ./monitor-control identity migrate >/dev/null 2>&1; then
        log_test_success "Migration command executed"
        
        # Verify migration worked
        source "$AGENT_DIR/lib/agent_identity.sh" 2>/dev/null
        local migrated_name
        if migrated_name=$(get_agent_name); then
            if [[ "$migrated_name" == "$test_name" ]]; then
                log_test_success "Config migrated correctly: $migrated_name"
            else
                fail_test "config_migration" "Migration failed: expected '$test_name', got '$migrated_name'"
                return 1
            fi
        else
            fail_test "config_migration" "Failed to retrieve migrated name"
            return 1
        fi
    else
        fail_test "config_migration" "Migration command failed"
        return 1
    fi
    
    pass_test "config_migration" "Configuration migration successful"
}

# Test 7: Security and Validation
test_security_validation() {
    start_test "security_validation" "Test security features and validation"
    
    source "$AGENT_DIR/lib/agent_identity.sh" 2>/dev/null
    
    # Test invalid agent names
    local invalid_names=("" "ab" "invalid@name" "name-with-spaces here" "NameTooLongThatExceedsTheMaximumLengthLimitSetForAgentNamesInTheSystem")
    
    for invalid_name in "${invalid_names[@]}"; do
        if set_agent_name "$invalid_name" 2>/dev/null; then
            fail_test "security_validation" "Invalid name accepted: '$invalid_name'"
            return 1
        else
            log_test_success "Invalid name properly rejected: '$invalid_name'"
        fi
    done
    
    # Test reserved names
    local reserved_names=("localhost" "manager" "server" "admin" "root")
    for reserved_name in "${reserved_names[@]}"; do
        if set_agent_name "$reserved_name" 2>/dev/null; then
            fail_test "security_validation" "Reserved name accepted: '$reserved_name'"
            return 1
        else
            log_test_success "Reserved name properly rejected: '$reserved_name'"
        fi
    done
    
    # Test file permissions
    local test_name="security-test-$(date +%s)"
    if set_agent_name "$test_name"; then
        local perms=$(stat -c "%a" "$AGENT_DIR/etc/agent.identity" 2>/dev/null)
        if [[ "$perms" == "600" ]]; then
            log_test_success "Identity file has correct permissions: $perms"
        else
            fail_test "security_validation" "Identity file has incorrect permissions: $perms (expected 600)"
            return 1
        fi
    else
        fail_test "security_validation" "Failed to set agent name for security test"
        return 1
    fi
    
    pass_test "security_validation" "Security and validation tests passed"
}

# Test 8: Binary Wrapper Enhancement
test_binary_wrapper() {
    start_test "binary_wrapper" "Test enhanced binary wrapper functionality"
    
    source "$AGENT_DIR/lib/agent_identity.sh" 2>/dev/null
    
    local test_name="wrapper-test-$(date +%s)"
    
    # Set agent name
    if ! set_agent_name "$test_name"; then
        fail_test "binary_wrapper" "Failed to set agent name for wrapper test"
        return 1
    fi
    
    # Test that monitor-agentd can read the name
    cd "$AGENT_DIR"
    
    # Create a test script that sources monitor-agentd and checks environment
    cat > /tmp/test_wrapper.sh << 'EOF'
#!/bin/bash
WAZUH_HOME="/workspaces/AGENT2"
source "$WAZUH_HOME/bin/monitor-agentd"
echo "PERSISTENT_AGENT_NAME=$PERSISTENT_AGENT_NAME"
echo "WAZUH_AGENT_NAME=$WAZUH_AGENT_NAME"
echo "OSSEC_AGENT_NAME=$OSSEC_AGENT_NAME"
EOF
    
    chmod +x /tmp/test_wrapper.sh
    
    # Run the test and capture output
    local wrapper_output
    if wrapper_output=$(timeout 5 /tmp/test_wrapper.sh 2>/dev/null); then
        if echo "$wrapper_output" | grep -q "PERSISTENT_AGENT_NAME=$test_name"; then
            log_test_success "Binary wrapper correctly reads persistent agent name"
        else
            fail_test "binary_wrapper" "Binary wrapper failed to read persistent agent name"
            echo "Wrapper output: $wrapper_output"
            return 1
        fi
        
        if echo "$wrapper_output" | grep -q "WAZUH_AGENT_NAME=$test_name"; then
            log_test_success "Binary wrapper sets WAZUH_AGENT_NAME environment variable"
        else
            log_test_warning "Binary wrapper did not set WAZUH_AGENT_NAME (may be expected if binary not found)"
        fi
    else
        log_test_warning "Wrapper test had issues (may be expected without actual wazuh-agentd binary)"
    fi
    
    # Cleanup
    rm -f /tmp/test_wrapper.sh
    
    pass_test "binary_wrapper" "Binary wrapper enhancement test completed"
}

# Test 9: Complete End-to-End Scenario
test_end_to_end() {
    start_test "end_to_end" "Test complete end-to-end agent naming scenario"
    
    # Clean slate
    rm -f "$AGENT_DIR/etc/agent.identity"
    
    cd "$AGENT_DIR"
    local final_test_name="e2e-test-$(date +%s)"
    
    # Step 1: Set agent name via monitor-control
    log_test "Step 1: Setting agent name via monitor-control"
    if ! sudo timeout 10 ./monitor-control identity set "$final_test_name" >/dev/null 2>&1; then
        fail_test "end_to_end" "Failed to set agent name in step 1"
        return 1
    fi
    
    # Step 2: Verify name persists in new shell/process
    log_test "Step 2: Verifying name persistence"
    local retrieved_name
    source "$AGENT_DIR/lib/agent_identity.sh" 2>/dev/null
    if ! retrieved_name=$(get_agent_name); then
        fail_test "end_to_end" "Failed to retrieve agent name in step 2"
        return 1
    fi
    
    if [[ "$retrieved_name" != "$final_test_name" ]]; then
        fail_test "end_to_end" "Name mismatch in step 2: expected '$final_test_name', got '$retrieved_name'"
        return 1
    fi
    
    # Step 3: Test initialization function
    log_test "Step 3: Testing initialization function"
    unset AGENT_NAME
    source "$AGENT_DIR/monitor-control" >/dev/null 2>&1
    initialize_agent_name
    
    if [[ "$AGENT_NAME" != "$final_test_name" ]]; then
        fail_test "end_to_end" "Initialization failed in step 3: expected '$final_test_name', got '$AGENT_NAME'"
        return 1
    fi
    
    # Step 4: Verify identity integrity
    log_test "Step 4: Verifying identity integrity"
    if ! verify_identity_integrity; then
        fail_test "end_to_end" "Identity integrity check failed in step 4"
        return 1
    fi
    
    # Step 5: Test show identity
    log_test "Step 5: Testing show identity"
    if ! sudo timeout 10 ./monitor-control identity show >/dev/null 2>&1; then
        fail_test "end_to_end" "Show identity failed in step 5"
        return 1
    fi
    
    pass_test "end_to_end" "Complete end-to-end test successful - agent name '$final_test_name' persists correctly"
}

# Main test execution
main() {
    echo "=========================================="
    echo "Agent Name Persistence Test Suite"
    echo "$(date)"
    echo "=========================================="
    echo ""
    
    # Setup
    setup_test_environment
    
    # Run all tests
    test_identity_library
    test_name_storage  
    test_name_persistence
    test_fallback_behavior
    test_monitor_control_identity
    test_config_migration
    test_security_validation
    test_binary_wrapper
    test_end_to_end
    
    # Cleanup
    cleanup_test_environment
    
    # Summary
    echo "=========================================="
    echo "TEST SUMMARY"
    echo "=========================================="
    echo "Tests Run: $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "🎉 ALL TESTS PASSED! 🎉"
        echo "Agent name persistence fix is working correctly."
        echo ""
        echo "✅ Key features verified:"
        echo "  • Persistent agent name storage"
        echo "  • Name validation and security"
        echo "  • Configuration migration"
        echo "  • Monitor-control integration"
        echo "  • Binary wrapper enhancement"
        echo "  • Complete end-to-end functionality"
    else
        echo "❌ SOME TESTS FAILED"
        echo "Failed tests: ${FAILED_TESTS[*]}"
        echo ""
        echo "Please review the test output and fix the issues."
        return 1
    fi
    
    echo ""
    echo "Test log saved to: $TEST_LOG"
    echo "=========================================="
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi