#!/bin/bash
# Agent Identity Management Library
# Secure storage and retrieval of agent identity information

set -e

# Configuration
AGENT_IDENTITY_FILE="${WAZUH_HOME:-$(dirname $(dirname $(realpath $0)))}/etc/agent.identity"
AGENT_IDENTITY_BACKUP="${AGENT_IDENTITY_FILE}.backup"
AGENT_IDENTITY_LOCK="${AGENT_IDENTITY_FILE}.lock"

# Security settings
IDENTITY_FILE_PERMS="600"
IDENTITY_DIR_PERMS="700"

# Logging functions
log_identity() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [IDENTITY] $*" >&2
}

log_identity_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [IDENTITY ERROR] $*" >&2
}

log_identity_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [IDENTITY WARNING] $*" >&2
}

# Validation functions
validate_agent_name() {
    local name="$1"
    
    # Check if name is empty
    if [[ -z "$name" ]]; then
        log_identity_error "Agent name cannot be empty"
        return 1
    fi
    
    # Check length (3-64 characters)
    if [[ ${#name} -lt 3 ]] || [[ ${#name} -gt 64 ]]; then
        log_identity_error "Agent name must be between 3 and 64 characters (current: ${#name})"
        return 1
    fi
    
    # Check for valid characters (alphanumeric, dash, underscore, dot)
    if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        log_identity_error "Agent name contains invalid characters. Only alphanumeric, dash, underscore, and dot allowed"
        return 1
    fi
    
    # Check it doesn't start or end with special characters
    if [[ "$name" =~ ^[._-] ]] || [[ "$name" =~ [._-]$ ]]; then
        log_identity_error "Agent name cannot start or end with special characters"
        return 1
    fi
    
    # Check for reserved names
    local reserved_names=("localhost" "manager" "server" "admin" "root" "system" "default")
    for reserved in "${reserved_names[@]}"; do
        if [[ "$name" == "$reserved" ]]; then
            log_identity_error "Agent name '$name' is reserved"
            return 1
        fi
    done
    
    return 0
}

# File locking functions
acquire_identity_lock() {
    local timeout="${1:-30}"
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if (set -C; echo $$ > "$AGENT_IDENTITY_LOCK") 2>/dev/null; then
            log_identity "Lock acquired: $AGENT_IDENTITY_LOCK"
            return 0
        fi
        
        # Check if lock file exists and process is still running
        if [[ -f "$AGENT_IDENTITY_LOCK" ]]; then
            local lock_pid=$(cat "$AGENT_IDENTITY_LOCK" 2>/dev/null || echo "")
            if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
                log_identity_warning "Removing stale lock file (PID $lock_pid not running)"
                rm -f "$AGENT_IDENTITY_LOCK"
                continue
            fi
        fi
        
        sleep 1
        ((elapsed++))
    done
    
    log_identity_error "Failed to acquire lock after $timeout seconds"
    return 1
}

release_identity_lock() {
    if [[ -f "$AGENT_IDENTITY_LOCK" ]]; then
        rm -f "$AGENT_IDENTITY_LOCK"
        log_identity "Lock released: $AGENT_IDENTITY_LOCK"
    fi
}

# Ensure lock is released on exit
trap 'release_identity_lock' EXIT

# Identity file management
create_identity_file() {
    local identity_dir=$(dirname "$AGENT_IDENTITY_FILE")
    
    # Create directory if it doesn't exist
    if [[ ! -d "$identity_dir" ]]; then
        mkdir -p "$identity_dir"
        chmod "$IDENTITY_DIR_PERMS" "$identity_dir"
        log_identity "Created identity directory: $identity_dir"
    fi
    
    # Create empty identity file
    touch "$AGENT_IDENTITY_FILE"
    chmod "$IDENTITY_FILE_PERMS" "$AGENT_IDENTITY_FILE"
    
    # Initialize with default structure
    cat > "$AGENT_IDENTITY_FILE" << EOF
# Wazuh Agent Identity File
# This file contains the persistent agent identity information
# WARNING: Do not edit manually unless you know what you're doing

# Agent Identity
AGENT_NAME=""
AGENT_ID=""
AGENT_GROUP=""

# Registration Information  
REGISTRATION_DATE=""
LAST_UPDATE=""
MANAGER_IP=""

# Status
ENROLLMENT_STATUS="not_enrolled"

# Security Checksum (for tampering detection)
CHECKSUM=""
EOF
    
    log_identity "Created identity file: $AGENT_IDENTITY_FILE"
}

# Backup management
create_identity_backup() {
    if [[ -f "$AGENT_IDENTITY_FILE" ]]; then
        cp "$AGENT_IDENTITY_FILE" "${AGENT_IDENTITY_BACKUP}.$(date +%s)"
        cp "$AGENT_IDENTITY_FILE" "$AGENT_IDENTITY_BACKUP"
        log_identity "Created identity backup"
    fi
}

restore_identity_backup() {
    if [[ -f "$AGENT_IDENTITY_BACKUP" ]]; then
        cp "$AGENT_IDENTITY_BACKUP" "$AGENT_IDENTITY_FILE"
        chmod "$IDENTITY_FILE_PERMS" "$AGENT_IDENTITY_FILE"
        log_identity "Restored identity from backup"
        return 0
    else
        log_identity_error "No backup file found"
        return 1
    fi
}

# Checksum functions for tampering detection
calculate_identity_checksum() {
    local file="$1"
    if [[ -f "$file" ]]; then
        # Calculate checksum excluding the checksum line itself
        grep -v "^CHECKSUM=" "$file" 2>/dev/null | sha256sum | cut -d' ' -f1
    fi
}

update_identity_checksum() {
    local temp_file="${AGENT_IDENTITY_FILE}.tmp"
    local checksum
    
    # Calculate checksum of current content (excluding checksum line)
    checksum=$(calculate_identity_checksum "$AGENT_IDENTITY_FILE")
    
    # Update checksum in file
    grep -v "^CHECKSUM=" "$AGENT_IDENTITY_FILE" > "$temp_file"
    echo "CHECKSUM=\"$checksum\"" >> "$temp_file"
    
    mv "$temp_file" "$AGENT_IDENTITY_FILE"
    chmod "$IDENTITY_FILE_PERMS" "$AGENT_IDENTITY_FILE"
}

verify_identity_integrity() {
    if [[ ! -f "$AGENT_IDENTITY_FILE" ]]; then
        log_identity_error "Identity file not found"
        return 1
    fi
    
    # Get stored checksum
    local stored_checksum=$(grep "^CHECKSUM=" "$AGENT_IDENTITY_FILE" 2>/dev/null | cut -d'"' -f2)
    
    # Calculate current checksum
    local current_checksum=$(calculate_identity_checksum "$AGENT_IDENTITY_FILE")
    
    if [[ "$stored_checksum" != "$current_checksum" ]]; then
        log_identity_error "Identity file integrity check failed! File may have been tampered with."
        log_identity_error "Stored: $stored_checksum"
        log_identity_error "Current: $current_checksum"
        return 1
    fi
    
    log_identity "Identity file integrity verified"
    return 0
}

# Core identity functions
get_agent_name() {
    if [[ ! -f "$AGENT_IDENTITY_FILE" ]]; then
        return 1
    fi
    
    if ! verify_identity_integrity; then
        log_identity_error "Cannot read agent name - integrity check failed"
        return 1
    fi
    
    local name=$(grep "^AGENT_NAME=" "$AGENT_IDENTITY_FILE" 2>/dev/null | cut -d'"' -f2)
    if [[ -n "$name" ]]; then
        echo "$name"
        return 0
    fi
    
    return 1
}

set_agent_name() {
    local name="$1"
    local skip_validation="$2"
    
    # Validate name unless explicitly skipped
    if [[ "$skip_validation" != "skip_validation" ]]; then
        if ! validate_agent_name "$name"; then
            return 1
        fi
    fi
    
    # Acquire lock
    if ! acquire_identity_lock; then
        return 1
    fi
    
    # Create file if it doesn't exist
    if [[ ! -f "$AGENT_IDENTITY_FILE" ]]; then
        create_identity_file
    fi
    
    # Create backup
    create_identity_backup
    
    # Update agent name
    local temp_file="${AGENT_IDENTITY_FILE}.tmp"
    
    # Copy everything except AGENT_NAME and CHECKSUM
    grep -v -E "^(AGENT_NAME=|CHECKSUM=)" "$AGENT_IDENTITY_FILE" > "$temp_file"
    
    # Add new agent name
    echo "AGENT_NAME=\"$name\"" >> "$temp_file"
    
    # Update last update timestamp
    sed -i "/^LAST_UPDATE=/d" "$temp_file"
    echo "LAST_UPDATE=\"$(date '+%Y-%m-%d %H:%M:%S')\"" >> "$temp_file"
    
    # Move temp file to main file
    mv "$temp_file" "$AGENT_IDENTITY_FILE"
    chmod "$IDENTITY_FILE_PERMS" "$AGENT_IDENTITY_FILE"
    
    # Update checksum
    update_identity_checksum
    
    log_identity "Agent name set to: $name"
    return 0
}

get_agent_id() {
    if [[ ! -f "$AGENT_IDENTITY_FILE" ]]; then
        return 1
    fi
    
    if ! verify_identity_integrity; then
        return 1
    fi
    
    local id=$(grep "^AGENT_ID=" "$AGENT_IDENTITY_FILE" 2>/dev/null | cut -d'"' -f2)
    if [[ -n "$id" ]]; then
        echo "$id"
        return 0
    fi
    
    return 1
}

set_agent_id() {
    local id="$1"
    
    if [[ -z "$id" ]]; then
        log_identity_error "Agent ID cannot be empty"
        return 1
    fi
    
    # Acquire lock
    if ! acquire_identity_lock; then
        return 1
    fi
    
    # Create file if it doesn't exist
    if [[ ! -f "$AGENT_IDENTITY_FILE" ]]; then
        create_identity_file
    fi
    
    # Create backup
    create_identity_backup
    
    # Update agent ID
    local temp_file="${AGENT_IDENTITY_FILE}.tmp"
    
    # Copy everything except AGENT_ID and CHECKSUM
    grep -v -E "^(AGENT_ID=|CHECKSUM=)" "$AGENT_IDENTITY_FILE" > "$temp_file"
    
    # Add new agent ID
    echo "AGENT_ID=\"$id\"" >> "$temp_file"
    
    # Update last update timestamp
    sed -i "/^LAST_UPDATE=/d" "$temp_file"
    echo "LAST_UPDATE=\"$(date '+%Y-%m-%d %H:%M:%S')\"" >> "$temp_file"
    
    # Move temp file to main file
    mv "$temp_file" "$AGENT_IDENTITY_FILE"
    chmod "$IDENTITY_FILE_PERMS" "$AGENT_IDENTITY_FILE"
    
    # Update checksum
    update_identity_checksum
    
    log_identity "Agent ID set to: $id"
    return 0
}

# Status management
set_enrollment_status() {
    local status="$1"
    
    if [[ -z "$status" ]]; then
        log_identity_error "Enrollment status cannot be empty"
        return 1
    fi
    
    # Acquire lock
    if ! acquire_identity_lock; then
        return 1
    fi
    
    # Create file if it doesn't exist
    if [[ ! -f "$AGENT_IDENTITY_FILE" ]]; then
        create_identity_file
    fi
    
    # Create backup
    create_identity_backup
    
    # Update enrollment status
    local temp_file="${AGENT_IDENTITY_FILE}.tmp"
    
    # Copy everything except ENROLLMENT_STATUS and CHECKSUM
    grep -v -E "^(ENROLLMENT_STATUS=|CHECKSUM=)" "$AGENT_IDENTITY_FILE" > "$temp_file"
    
    # Add new status
    echo "ENROLLMENT_STATUS=\"$status\"" >> "$temp_file"
    
    # Update last update timestamp
    sed -i "/^LAST_UPDATE=/d" "$temp_file"
    echo "LAST_UPDATE=\"$(date '+%Y-%m-%d %H:%M:%S')\"" >> "$temp_file"
    
    # Move temp file to main file
    mv "$temp_file" "$AGENT_IDENTITY_FILE"
    chmod "$IDENTITY_FILE_PERMS" "$AGENT_IDENTITY_FILE"
    
    # Update checksum
    update_identity_checksum
    
    log_identity "Enrollment status set to: $status"
    return 0
}

get_enrollment_status() {
    if [[ ! -f "$AGENT_IDENTITY_FILE" ]]; then
        echo "not_enrolled"
        return 1
    fi
    
    if ! verify_identity_integrity; then
        echo "corrupted"
        return 1
    fi
    
    local status=$(grep "^ENROLLMENT_STATUS=" "$AGENT_IDENTITY_FILE" 2>/dev/null | cut -d'"' -f2)
    echo "${status:-not_enrolled}"
}

# Complete identity management
set_agent_identity() {
    local name="$1"
    local id="$2"
    local group="$3"
    local manager_ip="$4"
    
    if ! validate_agent_name "$name"; then
        return 1
    fi
    
    # Acquire lock
    if ! acquire_identity_lock; then
        return 1
    fi
    
    # Create file if it doesn't exist
    if [[ ! -f "$AGENT_IDENTITY_FILE" ]]; then
        create_identity_file
    fi
    
    # Create backup
    create_identity_backup
    
    # Update all identity fields
    local temp_file="${AGENT_IDENTITY_FILE}.tmp"
    
    # Copy comments and fields we're not updating
    grep -E "^#|^$" "$AGENT_IDENTITY_FILE" > "$temp_file"
    
    # Add all identity fields
    echo "AGENT_NAME=\"$name\"" >> "$temp_file"
    echo "AGENT_ID=\"${id:-}\"" >> "$temp_file"
    echo "AGENT_GROUP=\"${group:-default}\"" >> "$temp_file"
    echo "" >> "$temp_file"
    echo "REGISTRATION_DATE=\"$(date '+%Y-%m-%d %H:%M:%S')\"" >> "$temp_file"
    echo "LAST_UPDATE=\"$(date '+%Y-%m-%d %H:%M:%S')\"" >> "$temp_file"
    echo "MANAGER_IP=\"${manager_ip:-}\"" >> "$temp_file"
    echo "" >> "$temp_file"
    echo "ENROLLMENT_STATUS=\"enrolled\"" >> "$temp_file"
    echo "" >> "$temp_file"
    
    # Move temp file to main file
    mv "$temp_file" "$AGENT_IDENTITY_FILE"
    chmod "$IDENTITY_FILE_PERMS" "$AGENT_IDENTITY_FILE"
    
    # Update checksum
    update_identity_checksum
    
    log_identity "Complete agent identity configured: name=$name, id=$id, group=${group:-default}"
    return 0
}

# Display functions
show_agent_identity() {
    if [[ ! -f "$AGENT_IDENTITY_FILE" ]]; then
        echo "Agent identity not configured"
        return 1
    fi
    
    if ! verify_identity_integrity; then
        echo "ERROR: Identity file integrity check failed!"
        return 1
    fi
    
    echo "=== Agent Identity ==="
    
    local name=$(get_agent_name 2>/dev/null)
    local id=$(get_agent_id 2>/dev/null)
    local status=$(get_enrollment_status 2>/dev/null)
    
    echo "Name: ${name:-not set}"
    echo "ID: ${id:-not set}"
    
    # Show other fields
    local group=$(grep "^AGENT_GROUP=" "$AGENT_IDENTITY_FILE" 2>/dev/null | cut -d'"' -f2)
    local reg_date=$(grep "^REGISTRATION_DATE=" "$AGENT_IDENTITY_FILE" 2>/dev/null | cut -d'"' -f2)
    local last_update=$(grep "^LAST_UPDATE=" "$AGENT_IDENTITY_FILE" 2>/dev/null | cut -d'"' -f2)
    local manager_ip=$(grep "^MANAGER_IP=" "$AGENT_IDENTITY_FILE" 2>/dev/null | cut -d'"' -f2)
    
    echo "Group: ${group:-default}"
    echo "Status: ${status:-unknown}"
    echo "Manager: ${manager_ip:-not set}"
    echo "Registered: ${reg_date:-not set}"
    echo "Last Update: ${last_update:-not set}"
    
    return 0
}

# Reset and cleanup functions
reset_agent_identity() {
    local confirm="$1"
    
    if [[ "$confirm" != "CONFIRM" ]]; then
        echo "WARNING: This will completely reset the agent identity!"
        echo "To confirm, run: reset_agent_identity CONFIRM"
        return 1
    fi
    
    # Acquire lock
    if ! acquire_identity_lock; then
        return 1
    fi
    
    # Create backup before reset
    if [[ -f "$AGENT_IDENTITY_FILE" ]]; then
        create_identity_backup
        cp "$AGENT_IDENTITY_FILE" "${AGENT_IDENTITY_FILE}.pre-reset.$(date +%s)"
    fi
    
    # Remove identity file
    rm -f "$AGENT_IDENTITY_FILE"
    
    # Create fresh identity file
    create_identity_file
    
    log_identity "Agent identity reset completed"
    return 0
}

# Export functions for sourcing
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    log_identity "Agent identity management library loaded"
else
    # Direct execution - show help
    echo "Agent Identity Management Library"
    echo "Usage: source this file to access identity functions"
    echo ""
    echo "Available functions:"
    echo "  get_agent_name                 - Get current agent name"
    echo "  set_agent_name NAME            - Set agent name"
    echo "  get_agent_id                   - Get current agent ID"
    echo "  set_agent_id ID                - Set agent ID"
    echo "  get_enrollment_status          - Get enrollment status"
    echo "  set_enrollment_status STATUS   - Set enrollment status"
    echo "  set_agent_identity NAME ID GROUP MANAGER - Set complete identity"
    echo "  show_agent_identity            - Display current identity"
    echo "  verify_identity_integrity      - Check file integrity"
    echo "  reset_agent_identity CONFIRM   - Reset identity (requires CONFIRM)"
fi