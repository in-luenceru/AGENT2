#!/bin/bash

# Framework Validation Script
# Validates the complete automated testing framework installation
# Author: Cybersecurity QA Engineer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$SCRIPT_DIR"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation counters
TOTAL_CHECKS=0
PASSED_CHECKS=0

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

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

check_item() {
    local description="$1"
    local test_command="$2"
    
    ((TOTAL_CHECKS++))
    
    echo -n "Checking $description... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((PASSED_CHECKS++))
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

validate_framework_structure() {
    log_info "Validating framework structure..."
    
    # Core directories
    check_item "test root directory" "[[ -d '$TEST_ROOT' ]]"
    check_item "utils directory" "[[ -d '$TEST_ROOT/utils' ]]"
    check_item "core directory" "[[ -d '$TEST_ROOT/core' ]]"
    check_item "features directory" "[[ -d '$TEST_ROOT/features' ]]"
    check_item "alerts directory" "[[ -d '$TEST_ROOT/alerts' ]]"
    
    # Feature subdirectories
    local features=(
        "fim"
        "sca" 
        "log-analysis"
        "rootkit"
        "vuln-scan"
        "cloud"
        "active-response"
        "performance"
        "integration"
    )
    
    for feature in "${features[@]}"; do
        check_item "$feature feature directory" "[[ -d '$TEST_ROOT/features/$feature' ]]"
    done
}

validate_test_scripts() {
    log_info "Validating test scripts..."
    
    # Core scripts
    check_item "test library" "[[ -f '$TEST_ROOT/utils/test_lib.sh' ]]"
    check_item "startup tests" "[[ -f '$TEST_ROOT/core/test_startup.sh' ]]"
    check_item "master orchestrator" "[[ -f '$TEST_ROOT/run_all_tests.sh' ]]"
    check_item "alert validation" "[[ -f '$TEST_ROOT/alerts/test_alerts.sh' ]]"
    
    # Feature test scripts
    local features=(
        "fim/test_fim.sh"
        "sca/test_sca.sh"
        "log-analysis/test_log_analysis.sh"
        "rootkit/test_rootkit.sh"
        "vuln-scan/test_vuln_scan.sh"
        "cloud/test_cloud.sh"
        "active-response/test_active_response.sh"
        "performance/test_performance.sh"
        "integration/test_integration.sh"
    )
    
    for feature in "${features[@]}"; do
        check_item "$feature test script" "[[ -f '$TEST_ROOT/features/$feature' ]]"
    done
}

validate_script_permissions() {
    log_info "Validating script permissions..."
    
    # Find all shell scripts and check if they're executable
    while IFS= read -r script; do
        local script_name=$(basename "$script")
        check_item "$script_name executable" "[[ -x '$script' ]]"
    done < <(find "$TEST_ROOT" -name "*.sh" -type f)
}

validate_script_syntax() {
    log_info "Validating script syntax..."
    
    local syntax_errors=0
    
    while IFS= read -r script; do
        local script_name=$(basename "$script")
        if ! bash -n "$script" 2>/dev/null; then
            log_error "Syntax error in $script_name"
            ((syntax_errors++))
        else
            check_item "$script_name syntax" "true"
        fi
    done < <(find "$TEST_ROOT" -name "*.sh" -type f)
    
    if [[ $syntax_errors -gt 0 ]]; then
        log_error "Found $syntax_errors scripts with syntax errors"
        return 1
    fi
}

validate_documentation() {
    log_info "Validating documentation..."
    
    check_item "framework README" "[[ -f '$TEST_ROOT/README.md' ]]"
    
    # Check if README has required sections
    if [[ -f "$TEST_ROOT/README.md" ]]; then
        check_item "README has overview section" "grep -q '## Overview' '$TEST_ROOT/README.md'"
        check_item "README has architecture section" "grep -q 'Framework Architecture' '$TEST_ROOT/README.md'"
        check_item "README has quick start section" "grep -q 'Quick Start' '$TEST_ROOT/README.md'"
        check_item "README has troubleshooting section" "grep -q 'Troubleshooting' '$TEST_ROOT/README.md'"
    fi
}

validate_dependencies() {
    log_info "Validating system dependencies..."
    
    # Core system tools
    check_item "bash shell" "command -v bash"
    check_item "grep tool" "command -v grep"
    check_item "awk tool" "command -v awk"
    check_item "sed tool" "command -v sed"
    check_item "netcat tool" "command -v nc || command -v netcat"
    
    # Optional tools
    if command -v jq >/dev/null 2>&1; then
        check_item "jq tool (optional)" "true"
    else
        log_warning "jq not found (recommended for JSON processing)"
    fi
    
    if command -v docker >/dev/null 2>&1; then
        check_item "docker tool (optional)" "true"
    else
        log_warning "docker not found (required for manager testing)"
    fi
}

validate_agent_environment() {
    log_info "Validating agent environment..."
    
    local agent_home="/workspaces/AGENT2"
    
    check_item "agent home directory" "[[ -d '$agent_home' ]]"
    check_item "agent bin directory" "[[ -d '$agent_home/bin' ]]"
    check_item "agent etc directory" "[[ -d '$agent_home/etc' ]]"
    check_item "agent logs directory" "[[ -d '$agent_home/logs' ]]"
    
    # Check for agent binaries
    if [[ -d "$agent_home/bin" ]]; then
        check_item "wazuh-control script" "[[ -f '$agent_home/bin/wazuh-control' || -f '$agent_home/wazuh-control-simple' ]]"
        check_item "agent configuration" "[[ -f '$agent_home/etc/ossec.conf' ]]"
    fi
}

validate_test_library() {
    log_info "Validating test library functionality..."
    
    local test_lib="$TEST_ROOT/utils/test_lib.sh"
    
    if [[ -f "$test_lib" ]]; then
        # Check for required functions
        check_item "init_test_framework function" "grep -q 'init_test_framework()' '$test_lib'"
        check_item "assertion functions" "grep -q 'assert_true()' '$test_lib'"
        check_item "logging functions" "grep -q 'log_info()' '$test_lib'"
        check_item "agent control functions" "grep -q 'is_agent_running()' '$test_lib'"
        check_item "manager check functions" "grep -q 'check_manager_connectivity()' '$test_lib'"
    else
        log_error "Test library not found: $test_lib"
    fi
}

# ============================================================================
# MAIN VALIDATION
# ============================================================================

run_framework_validation() {
    echo "================================================================"
    echo "Wazuh Monitoring Agent - Testing Framework Validation"
    echo "================================================================"
    echo ""
    
    # Run all validation functions
    validate_framework_structure
    echo ""
    
    validate_test_scripts
    echo ""
    
    validate_script_permissions
    echo ""
    
    validate_script_syntax
    echo ""
    
    validate_documentation
    echo ""
    
    validate_dependencies
    echo ""
    
    validate_agent_environment
    echo ""
    
    validate_test_library
    echo ""
    
    # Generate summary
    echo "================================================================"
    echo "VALIDATION SUMMARY"
    echo "================================================================"
    
    local success_rate=0
    if [[ $TOTAL_CHECKS -gt 0 ]]; then
        success_rate=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
    fi
    
    echo "Total Checks: $TOTAL_CHECKS"
    echo "Passed Checks: $PASSED_CHECKS"
    echo "Success Rate: $success_rate%"
    echo ""
    
    if [[ $PASSED_CHECKS -eq $TOTAL_CHECKS ]]; then
        log_success "All validation checks passed! Framework is ready for use."
        echo ""
        echo "To run the complete test suite:"
        echo "  cd /workspaces/AGENT2"
        echo "  ./test/run_all_tests.sh"
        echo ""
        echo "To run individual test modules:"
        echo "  ./test/core/test_startup.sh"
        echo "  ./test/features/fim/test_fim.sh"
        echo "  ./test/alerts/test_alerts.sh"
        echo ""
        return 0
    else
        local failed_checks=$((TOTAL_CHECKS - PASSED_CHECKS))
        log_error "$failed_checks validation checks failed. Please review and fix issues before using the framework."
        echo ""
        return 1
    fi
}

# ============================================================================
# SCRIPT EXECUTION
# ============================================================================

main() {
    if run_framework_validation; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi