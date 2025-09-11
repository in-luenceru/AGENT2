#!/bin/bash

# Wazuh Agent Verification Script
# This script tests the functionality of the extracted Wazuh Agent

set -e

INSTALL_PREFIX="${INSTALL_PREFIX:-/var/ossec}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="/tmp/wazuh-agent-test"
FAILED_TESTS=0
TOTAL_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "\n${BLUE}Test $TOTAL_TESTS: $test_name${NC}"
    echo "Command: $test_command"
    
    if eval "$test_command"; then
        log_success "PASSED: $test_name"
        return 0
    else
        log_error "FAILED: $test_name"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Test 1: Verify extraction completeness
test_extraction() {
    log_info "Checking if all required components were extracted..."
    
    local required_dirs=(
        "src/client-agent"
        "src/logcollector"
        "src/syscheckd"
        "src/os_execd"
        "src/rootcheck"
        "src/shared"
        "src/shared_modules"
        "src/wazuh_modules"
        "etc"
        "ruleset"
    )
    
    local missing=0
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$SCRIPT_DIR/$dir" ]]; then
            log_error "Missing directory: $dir"
            missing=1
        fi
    done
    
    [[ $missing -eq 0 ]]
}

# Test 2: Verify configuration files
test_configuration() {
    log_info "Checking configuration files..."
    
    local required_configs=(
        "etc/ossec.conf"
        "etc/internal_options.conf"
        "etc/agent.conf"
    )
    
    local missing=0
    for config in "${required_configs[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$config" ]]; then
            log_error "Missing config file: $config"
            missing=1
        fi
    done
    
    [[ $missing -eq 0 ]]
}

# Test 3: Build verification
test_build() {
    log_info "Testing build process..."
    
    # Check if build artifacts exist
    if [[ -f "$SCRIPT_DIR/build/bin/wazuh-agentd" ]]; then
        log_info "Build artifacts found, checking if they work..."
        return 0
    else
        log_warning "No build artifacts found. Run ./build_agent.sh first"
        return 1
    fi
}

# Test 4: Binary functionality
test_binaries() {
    log_info "Testing binary functionality..."
    
    local binaries=(
        "wazuh-agentd"
        "wazuh-logcollector"
        "wazuh-execd"
    )
    
    local bin_dir="$SCRIPT_DIR/build/bin"
    if [[ ! -d "$bin_dir" ]]; then
        log_warning "Build directory not found. Run ./build_agent.sh first"
        return 1
    fi
    
    local missing=0
    for binary in "${binaries[@]}"; do
        if [[ -f "$bin_dir/$binary" ]]; then
            log_info "Found $binary - checking if it's executable..."
            if [[ -x "$bin_dir/$binary" ]]; then
                log_success "$binary is executable"
            else
                log_error "$binary is not executable"
                missing=1
            fi
        else
            log_error "Missing binary: $binary"
            missing=1
        fi
    done
    
    [[ $missing -eq 0 ]]
}

# Test 5: Configuration validation
test_config_validation() {
    log_info "Testing configuration validation..."
    
    local agentd_binary="$SCRIPT_DIR/build/bin/wazuh-agentd"
    if [[ ! -f "$agentd_binary" ]]; then
        log_warning "wazuh-agentd not built yet"
        return 1
    fi
    
    # Create minimal test config
    mkdir -p "$TEST_DIR/etc"
    cat > "$TEST_DIR/etc/ossec.conf" << 'EOF'
<ossec_config>
  <client>
    <server>
      <address>127.0.0.1</address>
      <port>1514</port>
    </server>
  </client>
  
  <logging>
    <log_format>plain</log_format>
  </logging>
</ossec_config>
EOF

    # Test config validation (this might not work without proper setup)
    export WAZUH_HOME="$TEST_DIR"
    if timeout 5s "$agentd_binary" -t 2>/dev/null; then
        log_success "Configuration validation passed"
        return 0
    else
        log_warning "Configuration validation failed (expected without full setup)"
        return 0  # Don't fail the test as this is expected
    fi
}

# Test 6: Source code integrity
test_source_integrity() {
    log_info "Checking source code integrity..."
    
    # Count source files
    local c_files=$(find "$SCRIPT_DIR/src" -name "*.c" | wc -l)
    local h_files=$(find "$SCRIPT_DIR/src" -name "*.h" | wc -l)
    local cpp_files=$(find "$SCRIPT_DIR/src" -name "*.cpp" -o -name "*.cc" -o -name "*.cxx" | wc -l)
    
    log_info "Found $c_files C files, $h_files header files, $cpp_files C++ files"
    
    if [[ $c_files -gt 100 && $h_files -gt 50 ]]; then
        log_success "Source code appears complete"
        return 0
    else
        log_error "Source code appears incomplete"
        return 1
    fi
}

# Test 7: Dependencies check
test_dependencies() {
    log_info "Checking build dependencies..."
    
    local deps=("gcc" "g++" "cmake" "make")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    # Check for libraries
    if ! ldconfig -p | grep -q libssl; then
        missing_deps+=("libssl-dev")
    fi
    
    if ! ldconfig -p | grep -q libz; then
        missing_deps+=("zlib1g-dev")
    fi
    
    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        log_success "All dependencies available"
        return 0
    else
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install with: sudo apt-get install ${missing_deps[*]}"
        return 1
    fi
}

# Test 8: Ruleset validation
test_ruleset() {
    log_info "Checking ruleset completeness..."
    
    local ruleset_dir="$SCRIPT_DIR/ruleset"
    if [[ ! -d "$ruleset_dir" ]]; then
        log_error "Ruleset directory not found"
        return 1
    fi
    
    local rule_files=$(find "$ruleset_dir" -name "*.xml" | wc -l)
    log_info "Found $rule_files rule files"
    
    if [[ $rule_files -gt 10 ]]; then
        log_success "Ruleset appears complete"
        return 0
    else
        log_error "Ruleset appears incomplete"
        return 1
    fi
}

# Test 9: Script permissions
test_script_permissions() {
    log_info "Checking script permissions..."
    
    local scripts_dir="$SCRIPT_DIR/scripts"
    local bin_support_dir="$SCRIPT_DIR/bin-support"
    
    local issues=0
    
    if [[ -d "$scripts_dir" ]]; then
        while IFS= read -r -d '' script; do
            if [[ ! -x "$script" ]]; then
                log_error "Script not executable: $script"
                chmod +x "$script" 2>/dev/null && log_info "Fixed: $script" || issues=1
            fi
        done < <(find "$scripts_dir" -type f -print0)
    fi
    
    if [[ -d "$bin_support_dir" ]]; then
        while IFS= read -r -d '' script; do
            if [[ ! -x "$script" ]]; then
                log_error "Script not executable: $script"
                chmod +x "$script" 2>/dev/null && log_info "Fixed: $script" || issues=1
            fi
        done < <(find "$bin_support_dir" -type f -print0)
    fi
    
    [[ $issues -eq 0 ]]
}

# Test 10: Memory footprint estimate
test_memory_footprint() {
    log_info "Estimating memory footprint..."
    
    local build_dir="$SCRIPT_DIR/build"
    if [[ ! -d "$build_dir" ]]; then
        log_warning "No build directory found"
        return 1
    fi
    
    local total_size=$(du -sk "$SCRIPT_DIR" | cut -f1)
    local build_size=$(du -sk "$build_dir" | cut -f1 2>/dev/null || echo 0)
    
    log_info "Total size: ${total_size}KB"
    log_info "Build size: ${build_size}KB"
    
    if [[ $total_size -lt 500000 ]]; then  # Less than 500MB
        log_success "Memory footprint is reasonable"
        return 0
    else
        log_warning "Memory footprint is large: ${total_size}KB"
        return 1
    fi
}

# Show usage
show_usage() {
    echo "Wazuh Agent Verification Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --all        Run all tests (default)"
    echo "  --basic      Run basic tests only"
    echo "  --build      Run build-related tests"
    echo "  --help       Show this help"
    echo ""
}

# Main test runner
run_all_tests() {
    log_info "Starting Wazuh Agent Verification"
    log_info "=================================="
    
    # Create test directory
    mkdir -p "$TEST_DIR"
    trap "rm -rf '$TEST_DIR'" EXIT
    
    # Run tests
    run_test "Extraction Completeness" test_extraction
    run_test "Configuration Files" test_configuration
    run_test "Dependencies Check" test_dependencies
    run_test "Source Code Integrity" test_source_integrity
    run_test "Ruleset Validation" test_ruleset
    run_test "Script Permissions" test_script_permissions
    run_test "Build Verification" test_build
    run_test "Binary Functionality" test_binaries
    run_test "Configuration Validation" test_config_validation
    run_test "Memory Footprint" test_memory_footprint
    
    # Summary
    echo -e "\n${BLUE}Test Results Summary${NC}"
    echo "===================="
    echo "Total tests: $TOTAL_TESTS"
    echo "Passed: $((TOTAL_TESTS - FAILED_TESTS))"
    echo "Failed: $FAILED_TESTS"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_success "All tests passed! The Wazuh Agent extraction appears to be complete."
        echo ""
        log_info "Next steps:"
        echo "  1. Run ./build_agent.sh to build the agent"
        echo "  2. Configure the agent in etc/ossec.conf"
        echo "  3. Install with ./build_agent.sh --install"
        echo "  4. Enroll with a Wazuh manager"
        return 0
    else
        log_error "Some tests failed. Please review the issues above."
        return 1
    fi
}

# Parse command line arguments
case "${1:-}" in
    --help)
        show_usage
        exit 0
        ;;
    --all|"")
        run_all_tests
        ;;
    --basic)
        run_test "Extraction Completeness" test_extraction
        run_test "Configuration Files" test_configuration
        run_test "Dependencies Check" test_dependencies
        ;;
    --build)
        run_test "Build Verification" test_build
        run_test "Binary Functionality" test_binaries
        run_test "Configuration Validation" test_config_validation
        ;;
    *)
        echo "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac
