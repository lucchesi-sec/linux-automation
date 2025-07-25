#!/bin/bash

# BashAdminCore - Initialization Module
# Main entry point that sets up the environment and loads all core modules

# Set strict bash options
set -euo pipefail

# Determine script directory
BASH_ADMIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASH_ADMIN_CORE="$BASH_ADMIN_ROOT/core"
BASH_ADMIN_LIB="$BASH_ADMIN_CORE/lib"

# Export for use by other scripts
export BASH_ADMIN_ROOT
export BASH_ADMIN_CORE
export BASH_ADMIN_LIB

# Global error handler
bash_admin_error_handler() {
    local exit_code=$?
    local line_no=$1
    local bash_lineno=$2
    local last_command="$3"
    local func_stack=("${FUNCNAME[@]}")
    
    # Don't handle errors in the error handler itself
    set +e
    
    echo "ERROR: Command failed with exit code $exit_code" >&2
    echo "  Line: $line_no" >&2
    echo "  Command: $last_command" >&2
    echo "  Function stack: ${func_stack[*]}" >&2
    
    # Log to syslog if available
    if command -v logger >/dev/null 2>&1; then
        logger -t "bash-admin" -p "local0.error" "Script error: $last_command (exit: $exit_code, line: $line_no)"
    fi
    
    exit $exit_code
}

# Set up error handling
trap 'bash_admin_error_handler $LINENO $BASH_LINENO "$BASH_COMMAND"' ERR

# Function to source a library safely
source_lib() {
    local lib_file="$1"
    local lib_path="$BASH_ADMIN_LIB/$lib_file"
    
    if [[ -f "$lib_path" ]]; then
        # shellcheck source=/dev/null
        source "$lib_path"
    else
        echo "ERROR: Required library not found: $lib_path" >&2
        exit 1
    fi
}

# Load core libraries in order
source_lib "logging.sh"
source_lib "display.sh"
source_lib "config.sh"
source_lib "privileges.sh"
source_lib "security.sh"
source_lib "error_handler.sh"
source_lib "dry_run.sh"
source_lib "notifications.sh"

# Initialize core systems
init_bash_admin() {
    local script_name="${1:-$(basename "$0")}"
    
    # Initialize logging first
    if ! init_logging; then
        echo "ERROR: Failed to initialize logging" >&2
        exit 1
    fi
    
    log_info "Starting Bash Admin: $script_name" "INIT"
    log_debug "Bash Admin root: $BASH_ADMIN_ROOT" "INIT"
    
    # Initialize display module
    init_display
    
    # Initialize configuration
    if ! init_config; then
        log_fatal "Failed to initialize configuration" "INIT"
    fi
    
    # Initialize security module
    init_security
    
    # Initialize error handling
    init_error_handling
    
    # Initialize dry-run mode
    init_dry_run
    
    # Set up signal handlers
    trap 'log_info "Received SIGTERM, shutting down gracefully" "INIT"; exit 0' TERM
    trap 'log_info "Received SIGINT, shutting down gracefully" "INIT"; exit 0' INT
    
    # Validate environment
    validate_environment
    
    log_success "Bash Admin initialized successfully" "INIT"
}

# Validate the environment
validate_environment() {
    # Check required commands
    local required_commands=("logger" "date" "hostname" "whoami")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_warn "Missing recommended commands: ${missing_commands[*]}" "INIT"
    fi
    
    # Check for optional but useful commands
    local optional_commands=("jq" "curl" "sendmail" "mail")
    local missing_optional=()
    
    for cmd in "${optional_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_optional+=("$cmd")
        fi
    done
    
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        log_debug "Optional commands not available: ${missing_optional[*]}" "INIT"
    fi
    
    # Validate script permissions
    local script_path="${BASH_SOURCE[1]}"
    if [[ -n "$script_path" ]]; then
        validate_script_permissions "$script_path"
    fi
}

# Cleanup function
cleanup_bash_admin() {
    local exit_code=${1:-0}
    
    log_info "Bash Admin cleanup initiated" "CLEANUP"
    
    # Perform any necessary cleanup here
    # Remove temporary files, close connections, etc.
    
    log_info "Bash Admin shutdown complete (exit code: $exit_code)" "CLEANUP"
    exit $exit_code
}

# Set up cleanup trap
trap 'cleanup_bash_admin $?' EXIT

# Show usage information
show_bash_admin_info() {
    cat << EOF
Bash Admin Core Library
Version: 1.0.0
Root: $BASH_ADMIN_ROOT

Available functions:
  Logging: log_debug, log_info, log_warn, log_error, log_fatal, log_success
  Display: print_color, print_status, print_header, print_progress_bar, start_spinner
  Config:  get_config, set_config, has_config, list_config, require_config
  Privileges: check_root_privileges, require_root, execute_privileged
  Security: validate_ssh_config, check_password_policy, generate_security_audit
  Error Handling: register_rollback, execute_rollback, safe_execute, retry_with_backoff
  Dry Run: enable_dry_run, dry_run_execute, generate_dry_run_summary
  Notifications: send_email, send_notification, generate_html_report

Usage:
  source "$BASH_ADMIN_LIB/init.sh"
  init_bash_admin "$(basename "$0")"

For more information, see documentation in $BASH_ADMIN_ROOT/docs/
EOF
}

# If this script is called directly, show info
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_bash_admin_info
fi