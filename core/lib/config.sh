#!/bin/bash

# BashAdminCore - Configuration Management Module
# Provides centralized configuration loading and management

# Global configuration variables
declare -gA BASH_ADMIN_CONFIG
declare -g CONFIG_DIR="${BASH_ADMIN_CONFIG_DIR:-/etc/bash-admin/config}"
declare -g CONFIG_FILE="${CONFIG_DIR}/bash-admin.json"
declare -g LOCAL_CONFIG_FILE="$HOME/.bash-admin/config.json"

# Load configuration from JSON file
load_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        log_warn "Configuration file not found: $config_file" "CONFIG"
        return 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required for configuration management but not installed" "CONFIG"
        return 1
    fi
    
    log_info "Loading configuration from: $config_file" "CONFIG"
    
    # Parse JSON and populate associative array
    while IFS="=" read -r key value; do
        BASH_ADMIN_CONFIG["$key"]="$value"
    done < <(jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' "$config_file" 2>/dev/null)
    
    if [[ ${#BASH_ADMIN_CONFIG[@]} -eq 0 ]]; then
        log_error "Failed to load configuration from $config_file" "CONFIG"
        return 1
    fi
    
    log_success "Loaded ${#BASH_ADMIN_CONFIG[@]} configuration items" "CONFIG"
    return 0
}

# Initialize configuration
init_config() {
    # Try to load system config first
    if [[ -f "$CONFIG_FILE" ]]; then
        load_config "$CONFIG_FILE"
    elif [[ -f "$LOCAL_CONFIG_FILE" ]]; then
        load_config "$LOCAL_CONFIG_FILE"
    else
        log_warn "No configuration file found, using defaults" "CONFIG"
        create_default_config
    fi
}

# Create default configuration
create_default_config() {
    local default_config='{
    "email.smtp_server": "localhost",
    "email.smtp_port": "25",
    "email.from_address": "bash-admin@'"$(hostname -d)"'",
    "email.recipients.admin": "admin@'"$(hostname -d)"'",
    "email.recipients.security": "security@'"$(hostname -d)"'",
    "paths.log_dir": "/var/log/bash-admin",
    "paths.report_dir": "/var/reports/bash-admin",
    "paths.backup_dir": "/var/backups/bash-admin",
    "notifications.enabled": "true",
    "notifications.email_enabled": "true",
    "backup.retention_days": "30",
    "backup.compression": "gzip",
    "monitoring.disk_threshold": "90",
    "monitoring.memory_threshold": "85",
    "monitoring.load_threshold": "5.0"
}'
    
    # Ensure directory exists
    local config_dir
    if [[ -w "/etc" ]]; then
        config_dir="/etc/bash-admin/config"
    else
        config_dir="$HOME/.bash-admin"
    fi
    
    mkdir -p "$config_dir"
    echo "$default_config" > "$config_dir/bash-admin.json"
    
    log_info "Created default configuration at: $config_dir/bash-admin.json" "CONFIG"
    load_config "$config_dir/bash-admin.json"
}

# Get configuration value
get_config() {
    local key="$1"
    local default_value="$2"
    
    if [[ -n "${BASH_ADMIN_CONFIG[$key]:-}" ]]; then
        echo "${BASH_ADMIN_CONFIG[$key]}"
    elif [[ -n "$default_value" ]]; then
        echo "$default_value"
    else
        log_warn "Configuration key '$key' not found and no default provided" "CONFIG"
        return 1
    fi
}

# Set configuration value (runtime only)
set_config() {
    local key="$1"
    local value="$2"
    
    BASH_ADMIN_CONFIG["$key"]="$value"
    log_debug "Set configuration: $key=$value" "CONFIG"
}

# Check if configuration key exists
has_config() {
    local key="$1"
    [[ -n "${BASH_ADMIN_CONFIG[$key]:-}" ]]
}

# List all configuration keys
list_config() {
    local filter="${1:-}"
    
    for key in "${!BASH_ADMIN_CONFIG[@]}"; do
        if [[ -z "$filter" ]] || [[ "$key" == *"$filter"* ]]; then
            echo "$key=${BASH_ADMIN_CONFIG[$key]}"
        fi
    done | sort
}

# Validate required configuration
require_config() {
    local required_keys=("$@")
    local missing_keys=()
    
    for key in "${required_keys[@]}"; do
        if ! has_config "$key"; then
            missing_keys+=("$key")
        fi
    done
    
    if [[ ${#missing_keys[@]} -gt 0 ]]; then
        log_error "Missing required configuration keys: ${missing_keys[*]}" "CONFIG"
        return 1
    fi
    
    return 0
}