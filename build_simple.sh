#!/bin/bash

# Simple Wazuh Agent Build Script (No External Downloads)
# This script builds core agent components using system libraries

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
INSTALL_PREFIX="${INSTALL_PREFIX:-/var/ossec}"

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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check for essential build tools and libraries
check_dependencies() {
    log_info "Checking build dependencies..."
    
    local missing_deps=()
    
    if ! command -v gcc &> /dev/null; then
        missing_deps+=("gcc")
    fi
    
    if ! command -v make &> /dev/null; then
        missing_deps+=("make")
    fi
    
    if ! ldconfig -p | grep -q libssl; then
        missing_deps+=("libssl-dev")
    fi
    
    if ! ldconfig -p | grep -q libz; then
        missing_deps+=("zlib1g-dev")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install with: sudo apt-get install gcc make libssl-dev zlib1g-dev"
        exit 1
    fi
    
    log_success "All dependencies satisfied"
}

# Build using Make instead of CMake to avoid external dependencies
build_simple() {
    log_info "Building Wazuh Agent using simplified Makefile..."
    
    cd "$SCRIPT_DIR"
    
    # Create build directory
    mkdir -p "$BUILD_DIR"/{bin,lib}
    
    # Build shared utilities first
    log_info "Building shared utilities..."
    cd src/shared
    make clean 2>/dev/null || true
    gcc -fPIC -O2 -Wall -c *.c -I../headers -I../util
    ar rcs "$BUILD_DIR/lib/libwazuhshared.a" *.o
    cd ../..
    
    # Build client-agent (main daemon)
    log_info "Building wazuh-agentd..."
    cd src/client-agent
    gcc -O2 -Wall -I../headers -I../shared -I../util -I../os_net -I../os_crypto \
        -c agentd.c agcom.c buffer.c config.c event-forward.c notify.c \
        receiver.c reload_agent.c request.c rotate_log.c sendmsg.c start_agent.c state.c
    gcc -o "$BUILD_DIR/bin/wazuh-agentd" *.o \
        "$BUILD_DIR/lib/libwazuhshared.a" -lpthread -lssl -lcrypto -lz -lm
    cd ../..
    
    # Build logcollector
    log_info "Building wazuh-logcollector..."
    cd src/logcollector
    gcc -O2 -Wall -I../headers -I../shared -I../util \
        -c config.c logcollector.c main.c read_audit.c read_command.c \
        read_djb_multilog.c read_fullcommand.c read_json.c read_multiline.c \
        read_mysql_log.c read_nmapg.c read_ossecalert.c read_postgresql_log.c \
        read_snortfull.c read_syslog.c state.c 2>/dev/null || gcc -O2 -Wall -I../headers -I../shared -I../util -c *.c 2>/dev/null || true
    gcc -o "$BUILD_DIR/bin/wazuh-logcollector" *.o \
        "$BUILD_DIR/lib/libwazuhshared.a" -lpthread -lssl -lcrypto -lz -lm 2>/dev/null || log_error "Failed to build logcollector (some components may be missing)"
    cd ../..
    
    # Build execd
    log_info "Building wazuh-execd..."
    cd src/os_execd
    gcc -O2 -Wall -I../headers -I../shared -I../util \
        -c config.c exec.c execd.c main.c wcom.c
    gcc -o "$BUILD_DIR/bin/wazuh-execd" *.o \
        "$BUILD_DIR/lib/libwazuhshared.a" -lpthread -lssl -lcrypto -lz -lm
    cd ../..
    
    log_success "Build completed successfully!"
    
    # Show what was built
    log_info "Built binaries:"
    ls -la "$BUILD_DIR/bin/"
    
    log_info "Build Summary:"
    echo "  Built core agent daemons"
    echo "  Note: Some advanced modules may not be included in this simplified build"
    echo "  For full functionality, use the CMake build with proper dependencies"
    echo ""
    echo "To test: $BUILD_DIR/bin/wazuh-agentd --help"
    echo "To install: sudo cp $BUILD_DIR/bin/* /var/ossec/bin/"
}

# Main execution
main() {
    log_info "Starting Simplified Wazuh Agent Build"
    log_info "====================================="
    
    check_dependencies
    build_simple
    
    log_success "Build process completed!"
}

main "$@"
