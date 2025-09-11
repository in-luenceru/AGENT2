#!/bin/bash

# Wazuh Agent Build Script
# This script configures and builds the extracted Wazuh Agent components
#
# Usage: ./build_agent.sh [options]
# Options:
#   --clean        Clean previous build
#   --debug        Build with debug symbols
#   --install      Install after building
#   --help         Show this help

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
INSTALL_PREFIX="${INSTALL_PREFIX:-/var/ossec}"
BUILD_TYPE="Release"
CLEAN_BUILD=false
INSTALL_AFTER=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --clean)
      CLEAN_BUILD=true
      shift
      ;;
    --debug)
      BUILD_TYPE="Debug"
      shift
      ;;
    --install)
      INSTALL_AFTER=true
      shift
      ;;
    --help)
      echo "Wazuh Agent Build Script"
      echo ""
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --clean        Clean previous build"
      echo "  --debug        Build with debug symbols"
      echo "  --install      Install after building"
      echo "  --help         Show this help"
      echo ""
      echo "Environment Variables:"
      echo "  INSTALL_PREFIX Default installation prefix (default: /var/ossec)"
      echo "  CMAKE_ARGS     Additional cmake arguments"
      echo ""
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

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

# Check dependencies
check_dependencies() {
    log_info "Checking build dependencies..."
    
    local missing_deps=()
    
    # Check for cmake
    if ! command -v cmake &> /dev/null; then
        missing_deps+=("cmake")
    fi
    
    # Check for gcc/clang
    if ! command -v gcc &> /dev/null && ! command -v clang &> /dev/null; then
        missing_deps+=("gcc or clang")
    fi
    
    # Check for make
    if ! command -v make &> /dev/null; then
        missing_deps+=("make")
    fi
    
    # Check for essential libraries
    if ! ldconfig -p | grep -q libssl; then
        missing_deps+=("libssl-dev")
    fi
    
    if ! ldconfig -p | grep -q libz; then
        missing_deps+=("zlib1g-dev")
    fi
    
    if ! ldconfig -p | grep -q libpthread; then
        missing_deps+=("libc6-dev")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "On Ubuntu/Debian, install with:"
        log_info "  sudo apt-get update"
        log_info "  sudo apt-get install cmake gcc g++ make libssl-dev zlib1g-dev libc6-dev"
        exit 1
    fi
    
    log_success "All dependencies satisfied"
}

# Clean build directory
clean_build() {
    if [ -d "$BUILD_DIR" ] && [ "$CLEAN_BUILD" = true ]; then
        log_info "Cleaning previous build..."
        rm -rf "$BUILD_DIR"
        log_success "Build directory cleaned"
    fi
}

# Configure build
configure_build() {
    log_info "Configuring Wazuh Agent build..."
    
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    local cmake_args=(
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
        -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    )
    
    # Add any additional cmake args
    if [ -n "$CMAKE_ARGS" ]; then
        cmake_args+=($CMAKE_ARGS)
    fi
    
    log_info "CMake configuration: ${cmake_args[*]}"
    
    cmake "${cmake_args[@]}" "$SCRIPT_DIR"
    
    log_success "Build configured successfully"
}

# Build the agent
build_agent() {
    log_info "Building Wazuh Agent..."
    
    cd "$BUILD_DIR"
    
    # Determine number of parallel jobs
    local num_jobs
    if command -v nproc &> /dev/null; then
        num_jobs=$(nproc)
    else
        num_jobs=4
    fi
    
    log_info "Building with $num_jobs parallel jobs..."
    
    cmake --build . --parallel "$num_jobs"
    
    log_success "Wazuh Agent built successfully"
}

# Install the agent
install_agent() {
    if [ "$INSTALL_AFTER" = true ]; then
        log_info "Installing Wazuh Agent to $INSTALL_PREFIX..."
        
        cd "$BUILD_DIR"
        
        # Check if we need sudo
        if [ ! -w "$(dirname "$INSTALL_PREFIX")" ]; then
            log_warning "Installing to system location, may require sudo..."
            sudo cmake --install .
        else
            cmake --install .
        fi
        
        log_success "Wazuh Agent installed to $INSTALL_PREFIX"
    fi
}

# Show build summary
show_summary() {
    log_info "Build Summary:"
    echo "  Source Directory: $SCRIPT_DIR"
    echo "  Build Directory:  $BUILD_DIR"
    echo "  Install Prefix:   $INSTALL_PREFIX"
    echo "  Build Type:       $BUILD_TYPE"
    echo ""
    
    if [ -d "$BUILD_DIR" ]; then
        log_info "Generated binaries:"
        find "$BUILD_DIR" -name "wazuh-*" -type f -executable 2>/dev/null | while read -r binary; do
            echo "  - $(basename "$binary")"
        done
    fi
    
    echo ""
    log_info "Next steps:"
    echo "  1. Configure agent: edit $INSTALL_PREFIX/etc/ossec.conf"
    echo "  2. Add agent key: $INSTALL_PREFIX/bin/manage_agents"
    echo "  3. Start agent: $INSTALL_PREFIX/bin/wazuh-control start"
    echo ""
}

# Main execution
main() {
    log_info "Starting Wazuh Agent Build Process"
    log_info "===================================="
    
    check_dependencies
    clean_build
    configure_build
    build_agent
    install_agent
    show_summary
    
    log_success "Build process completed successfully!"
}

# Run main function
main "$@"
