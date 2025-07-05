#!/bin/bash

# BashAdminCore - Privilege Management Module
# Provides privilege checking and elevation capabilities

# Check if running with root privileges
check_root_privileges() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Check if running with sudo privileges
check_sudo_privileges() {
    if sudo -n true 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Require root privileges
require_root() {
    local message="${1:-This operation requires root privileges}"
    
    if ! check_root_privileges; then
        log_error "$message" "PRIVILEGES"
        
        if check_sudo_privileges; then
            log_info "Attempting to elevate privileges with sudo..." "PRIVILEGES"
            exec sudo -E "$0" "$@"
        else
            log_fatal "Root privileges required but not available" "PRIVILEGES"
        fi
    fi
    
    log_debug "Root privileges confirmed" "PRIVILEGES"
}

# Require sudo privileges (doesn't need to be root)
require_sudo() {
    local message="${1:-This operation requires sudo privileges}"
    
    if ! check_sudo_privileges && ! check_root_privileges; then
        log_error "$message" "PRIVILEGES"
        log_info "Please run with sudo or as root" "PRIVILEGES"
        return 1
    fi
    
    log_debug "Elevated privileges confirmed" "PRIVILEGES"
    return 0
}

# Execute command with sudo if not root
execute_privileged() {
    local cmd="$1"
    local description="${2:-Executing privileged command}"
    
    log_info "$description" "PRIVILEGES"
    
    if check_root_privileges; then
        log_command "$cmd" "PRIVILEGED"
    elif check_sudo_privileges; then
        log_command "sudo $cmd" "PRIVILEGED"
    else
        log_error "Cannot execute privileged command: $cmd" "PRIVILEGES"
        return 1
    fi
}

# Check if user exists
user_exists() {
    local username="$1"
    id "$username" >/dev/null 2>&1
}

# Check if group exists
group_exists() {
    local groupname="$1"
    getent group "$groupname" >/dev/null 2>&1
}

# Check if user is in group
user_in_group() {
    local username="$1"
    local groupname="$2"
    
    groups "$username" 2>/dev/null | grep -q "\b$groupname\b"
}

# Get current user information
get_user_info() {
    local username="${1:-$(whoami)}"
    
    if user_exists "$username"; then
        local user_info
        user_info=$(getent passwd "$username")
        echo "Username: $(echo "$user_info" | cut -d: -f1)"
        echo "UID: $(echo "$user_info" | cut -d: -f3)"
        echo "GID: $(echo "$user_info" | cut -d: -f4)"
        echo "Home: $(echo "$user_info" | cut -d: -f6)"
        echo "Shell: $(echo "$user_info" | cut -d: -f7)"
        echo "Groups: $(groups "$username" 2>/dev/null | cut -d: -f2- | tr ' ' ',' | sed 's/^,//')"
    else
        log_error "User does not exist: $username" "PRIVILEGES"
        return 1
    fi
}

# Validate script permissions
validate_script_permissions() {
    local script_path="$1"
    
    if [[ ! -f "$script_path" ]]; then
        log_error "Script not found: $script_path" "PRIVILEGES"
        return 1
    fi
    
    # Check if script is executable
    if [[ ! -x "$script_path" ]]; then
        log_warn "Script is not executable: $script_path" "PRIVILEGES"
        return 1
    fi
    
    # Check ownership and permissions
    local script_owner=$(stat -c '%U' "$script_path" 2>/dev/null || stat -f '%Su' "$script_path" 2>/dev/null)
    local script_perms=$(stat -c '%a' "$script_path" 2>/dev/null || stat -f '%Lp' "$script_path" 2>/dev/null)
    
    log_debug "Script: $script_path, Owner: $script_owner, Permissions: $script_perms" "PRIVILEGES"
    
    # Warn if script is world-writable
    if [[ "$script_perms" == *2 ]] || [[ "$script_perms" == *6 ]]; then
        log_warn "Script is world-writable (potential security risk): $script_path" "PRIVILEGES"
    fi
    
    return 0
}