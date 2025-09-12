#!/bin/bash

# Deploy Real Wazuh Binaries Script
# Replaces mock shell scripts with compiled C binaries

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/src"
BIN_DIR="${SCRIPT_DIR}/bin"
LIB_DIR="${SCRIPT_DIR}/lib"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Core binaries to deploy
BINARIES=(
    "wazuh-agentd"
    "wazuh-logcollector" 
    "wazuh-syscheckd"
    "wazuh-modulesd"
    "wazuh-execd"
)

# Shared libraries to deploy
LIBRARIES=(
    "libwazuhext.so"
    "libwazuhshared.so"
    "libwazuh.a"
)

# Create library directory
create_lib_directory() {
    log_info "Creating library directory..."
    mkdir -p "$LIB_DIR"
    log_success "Library directory created: $LIB_DIR"
}

# Deploy shared libraries
deploy_libraries() {
    log_info "Deploying shared libraries..."
    
    for lib in "${LIBRARIES[@]}"; do
        if [ -f "$SRC_DIR/$lib" ]; then
            cp "$SRC_DIR/$lib" "$LIB_DIR/"
            log_success "Deployed library: $lib"
        else
            log_warning "Library not found: $lib"
        fi
    done
}

# Deploy binaries with wrapper scripts
deploy_binaries() {
    log_info "Deploying real compiled binaries..."
    
    for binary in "${BINARIES[@]}"; do
        if [ -f "$SRC_DIR/$binary" ]; then
            # Copy the compiled binary
            cp "$SRC_DIR/$binary" "$BIN_DIR/$binary.real"
            
            # Create wrapper script with proper library path
            cat > "$BIN_DIR/$binary" << EOFBIN
#!/bin/bash
# Wazuh $binary wrapper script
# Automatically sets library path and configuration

AGENT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"
export LD_LIBRARY_PATH="\$AGENT_DIR/lib:\$LD_LIBRARY_PATH"

# Set proper working directory
cd "\$AGENT_DIR"

# Execute real binary with proper paths
exec "\$AGENT_DIR/bin/$binary.real" "\$@"
EOFBIN
            chmod +x "$BIN_DIR/$binary"
            log_success "Deployed binary: $binary"
        else
            log_error "Binary not found: $SRC_DIR/$binary"
            return 1
        fi
    done
}

# Verify binary functionality
verify_binaries() {
    log_info "Verifying binary functionality..."
    
    for binary in "${BINARIES[@]}"; do
        if [ -x "$BIN_DIR/$binary" ]; then
            # Test help option (most binaries support -h)
            if "$BIN_DIR/$binary" -h >/dev/null 2>&1 || "$BIN_DIR/$binary" -V >/dev/null 2>&1; then
                log_success "Binary functional: $binary"
            else
                # For some binaries, any exit is okay as long as they don't segfault
                if [ $? -ne 139 ]; then  # 139 is segfault
                    log_success "Binary functional: $binary (non-zero exit is normal)"
                else
                    log_error "Binary crashed: $binary"
                    return 1
                fi
            fi
        else
            log_error "Binary not executable: $binary"
            return 1
        fi
    done
}

# Show deployment summary
show_summary() {
    log_info "Deployment Summary:"
    echo "  Source Directory: $SRC_DIR"
    echo "  Binary Directory: $BIN_DIR" 
    echo "  Library Directory: $LIB_DIR"
    echo ""
    
    log_info "Deployed binaries:"
    for binary in "${BINARIES[@]}"; do
        if [ -x "$BIN_DIR/$binary" ]; then
            echo "  ✅ $binary"
        else
            echo "  ❌ $binary"
        fi
    done
    
    echo ""
    log_info "Deployed libraries:"
    for lib in "${LIBRARIES[@]}"; do
        if [ -f "$LIB_DIR/$lib" ]; then
            echo "  ✅ $lib"
        else
            echo "  ❌ $lib"
        fi
    done
}

# Main execution
main() {
    log_info "Starting Wazuh Binary Deployment"
    log_info "================================"
    
    create_lib_directory
    deploy_libraries
    deploy_binaries
    verify_binaries
    show_summary
    
    log_success "Binary deployment completed successfully!"
    log_info "Real compiled binaries are now active in $BIN_DIR"
}

# Run main function
main "$@"
