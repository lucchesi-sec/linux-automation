#!/bin/bash
# User Data Provider Module
# Responsible ONLY for gathering user data from the system
# Follows Data Provider Contract - no analysis or presentation

# Source system API
source "$(dirname "$0")/../../core/lib/system_api.sh"

# ================================
# Data Provider Functions
# ================================

# Get raw user data from system
get_user_data() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        echo "Error: Username required" >&2
        return 1
    fi
    
    # Gather user information using System API
    local user_info
    user_info=$(system_api_get_user "$username" "all")
    
    if [[ -z "$user_info" ]]; then
        return 1
    fi
    
    echo "$user_info"
    return 0
}

# Get all users within UID range
list_system_users() {
    local min_uid="${1:-0}"
    local max_uid="${2:-999}"
    
    system_api_list_users "$min_uid" "$max_uid"
}

# Get all regular users
list_regular_users() {
    local min_uid="${1:-1000}"
    local max_uid="${2:-60000}"
    
    system_api_list_users "$min_uid" "$max_uid"
}

# Get user's password status
get_user_password_status() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        echo "Error: Username required" >&2
        return 1
    fi
    
    system_api_get_password_status "$username"
}

# Get user's shadow information
get_user_shadow_data() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        echo "Error: Username required" >&2
        return 1
    fi
    
    system_api_get_shadow_info "$username" "all"
}

# Get user's groups
get_user_groups_data() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        echo "Error: Username required" >&2
        return 1
    fi
    
    system_api_get_user_groups "$username"
}

# Get user's home directory info
get_user_home_info() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        echo "Error: Username required" >&2
        return 1
    fi
    
    local home
    home=$(system_api_get_user "$username" 6)
    
    if [[ -n "$home" && -d "$home" ]]; then
        local size
        size=$(system_api_get_directory_size "$home")
        echo "${home}:${size}"
    else
        echo "${home}:0"
    fi
}

# Get user's last login information
get_user_last_login() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        echo "Error: Username required" >&2
        return 1
    fi
    
    # Try multiple sources for last login
    if command -v lastlog >/dev/null 2>&1; then
        lastlog -u "$username" 2>/dev/null | tail -n1
    elif command -v last >/dev/null 2>&1; then
        last -n 1 "$username" 2>/dev/null | head -n1
    else
        echo "Unknown"
    fi
}

# Get all user data in JSON format
get_all_user_data_json() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        echo "Error: Username required" >&2
        return 1
    fi
    
    # Gather all data components
    local user_info shadow_info groups home_info last_login password_status
    
    user_info=$(system_api_get_user "$username" "all")
    [[ -z "$user_info" ]] && return 1
    
    # Parse user info
    IFS=: read -r uname _ uid gid gecos home shell <<< "$user_info"
    
    shadow_info=$(system_api_get_shadow_info "$username" "all")
    groups=$(system_api_get_user_groups "$username")
    home_info=$(get_user_home_info "$username")
    last_login=$(get_user_last_login "$username")
    password_status=$(system_api_get_password_status "$username")
    
    # Output as JSON
    cat <<EOF
{
    "username": "$uname",
    "uid": $uid,
    "gid": $gid,
    "gecos": "$gecos",
    "home": "$home",
    "shell": "$shell",
    "groups": "$groups",
    "password_status": "$password_status",
    "home_size": "$(echo "$home_info" | cut -d: -f2)",
    "last_login": "$last_login",
    "shadow_raw": "$shadow_info"
}
EOF
}

# Fetch excluded users list from configuration
fetch_excluded_users() {
    local config_file="${1:-/etc/admin-tools/config.json}"
    local default_excluded="root daemon bin sys nobody"
    
    if [[ -f "$config_file" ]] && command -v jq >/dev/null 2>&1; then
        jq -r '.modules.user_management.excluded_users[]' "$config_file" 2>/dev/null || echo "$default_excluded"
    else
        echo "$default_excluded"
    fi
}