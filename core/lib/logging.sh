#!/bin/bash

# BashAdminCore - Logging Module
# Provides centralized logging functionality with multiple output formats and levels

# Global variables
declare -g LOG_LEVEL_DEBUG=0
declare -g LOG_LEVEL_INFO=1
declare -g LOG_LEVEL_WARN=2
declare -g LOG_LEVEL_ERROR=3
declare -g LOG_LEVEL_FATAL=4

declare -g CURRENT_LOG_LEVEL=${BASH_ADMIN_LOG_LEVEL:-1}
declare -g LOG_DIR="${BASH_ADMIN_LOG_DIR:-/var/log/bash-admin}"
declare -g LOG_FILE="${LOG_DIR}/bash-admin-$(date '+%Y-%m-%d').log"

# Colors for console output
declare -g COLOR_RED='\033[0;31m'
declare -g COLOR_YELLOW='\033[1;33m'
declare -g COLOR_GREEN='\033[0;32m'
declare -g COLOR_BLUE='\033[0;34m'
declare -g COLOR_RESET='\033[0m'

# Initialize logging
init_logging() {
    if [[ ! -d "$LOG_DIR" ]]; then
        sudo mkdir -p "$LOG_DIR" 2>/dev/null || mkdir -p "$HOME/.bash-admin/logs" && LOG_DIR="$HOME/.bash-admin/logs"
    fi
    
    # Set appropriate permissions
    if [[ -w "$LOG_DIR" ]]; then
        chmod 755 "$LOG_DIR" 2>/dev/null || true
    fi
}

# Core logging function
write_log() {
    local level="$1"
    local message="$2"
    local category="${3:-GENERAL}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local hostname=$(hostname -s)
    local script_name=$(basename "${BASH_SOURCE[3]}" 2>/dev/null || echo "unknown")
    
    # Create log entry
    local log_entry="[$timestamp] [$hostname] [$script_name] [$level] [$category] $message"
    
    # Write to file if possible
    if [[ -w "$LOG_DIR" ]]; then
        echo "$log_entry" >> "$LOG_FILE"
    fi
    
    # Write to syslog
    logger -t "bash-admin" -p "local0.$level" "$message"
    
    # Write to console with colors
    local color=""
    case "$level" in
        "DEBUG") color="$COLOR_BLUE" ;;
        "INFO")  color="$COLOR_GREEN" ;;
        "WARN")  color="$COLOR_YELLOW" ;;
        "ERROR") color="$COLOR_RED" ;;
        "FATAL") color="$COLOR_RED" ;;
    esac
    
    echo -e "${color}[$level]${COLOR_RESET} $message" >&2
}

# Logging level functions
log_debug() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] && write_log "DEBUG" "$1" "$2"
}

log_info() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]] && write_log "INFO" "$1" "$2"
}

log_warn() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARN ]] && write_log "WARN" "$1" "$2"
}

log_error() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ]] && write_log "ERROR" "$1" "$2"
}

log_fatal() {
    write_log "FATAL" "$1" "$2"
    exit 1
}

# Convenience function for success messages
log_success() {
    write_log "INFO" "✓ $1" "$2"
}

# Function to log command execution
log_command() {
    local cmd="$1"
    local category="${2:-COMMAND}"
    
    log_info "Executing: $cmd" "$category"
    
    if eval "$cmd"; then
        log_success "Command completed successfully" "$category"
        return 0
    else
        local exit_code=$?
        log_error "Command failed with exit code $exit_code" "$category"
        return $exit_code
    fi
}

# Initialize logging when module is sourced
init_logging