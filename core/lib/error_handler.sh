#!/bin/bash

# BashAdminCore - Error Handling and Rollback Module
# Provides comprehensive error handling, rollback capabilities, and recovery mechanisms

# Global error handling variables
declare -g ERROR_COUNT=0
declare -g LAST_ERROR=""
declare -g LAST_ERROR_CODE=0
declare -gA ROLLBACK_STACK
declare -g ROLLBACK_INDEX=0
declare -g ERROR_RECOVERY_ENABLED=true
declare -g ERROR_LOG_FILE="${BASH_ADMIN_LOG_DIR:-/var/log/bash-admin}/errors.log"

# Initialize error handling
init_error_handling() {
    # Create error log directory if needed
    local error_log_dir=$(dirname "$ERROR_LOG_FILE")
    if [[ ! -d "$error_log_dir" ]]; then
        mkdir -p "$error_log_dir" 2>/dev/null || {
            ERROR_LOG_FILE="$HOME/.bash-admin/logs/errors.log"
            mkdir -p "$(dirname "$ERROR_LOG_FILE")"
        }
    fi
    
    # Set up global error trap
    trap 'handle_error $? "$BASH_COMMAND" $LINENO $BASH_LINENO "${FUNCNAME[@]}"' ERR
    
    # Enable error options
    set -eE  # Exit on error and inherit ERR trap
    set -o pipefail  # Fail on pipe errors
    
    log_debug "Error handling initialized" "ERROR_HANDLER"
}

# Main error handler
handle_error() {
    local error_code=$1
    local failed_command="$2"
    local line_number=$3
    local bash_line_number=$4
    shift 4
    local function_stack=("$@")
    
    # Increment error count
    ((ERROR_COUNT++))
    LAST_ERROR="$failed_command"
    LAST_ERROR_CODE=$error_code
    
    # Build error context
    local error_context="Error #$ERROR_COUNT
    Exit Code: $error_code
    Command: $failed_command
    Line: $line_number
    Function Stack: ${function_stack[*]}"
    
    # Log the error
    log_error "$error_context" "ERROR_HANDLER"
    
    # Write to error log file
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR"
        echo "$error_context"
        echo "---"
    } >> "$ERROR_LOG_FILE"
    
    # Attempt recovery if enabled
    if [[ "$ERROR_RECOVERY_ENABLED" == "true" ]]; then
        attempt_error_recovery "$error_code" "$failed_command"
    fi
    
    # Execute rollback if we have rollback actions
    if [[ $ROLLBACK_INDEX -gt 0 ]]; then
        log_warn "Executing rollback due to error..." "ERROR_HANDLER"
        execute_rollback
    fi
    
    # Re-throw if not recovered
    return $error_code
}

# Register a rollback action
register_rollback() {
    local action="$1"
    local description="${2:-Rollback action}"
    
    ROLLBACK_STACK[$ROLLBACK_INDEX]="$action"
    ((ROLLBACK_INDEX++))
    
    log_debug "Registered rollback action #$ROLLBACK_INDEX: $description" "ROLLBACK"
}

# Execute all rollback actions in reverse order
execute_rollback() {
    local rollback_errors=0
    
    log_info "Starting rollback process ($ROLLBACK_INDEX actions)..." "ROLLBACK"
    
    # Disable error trap during rollback
    trap - ERR
    set +e
    
    # Execute rollback actions in reverse order
    for ((i=ROLLBACK_INDEX-1; i>=0; i--)); do
        local action="${ROLLBACK_STACK[$i]}"
        log_info "Executing rollback action #$((i+1)): $action" "ROLLBACK"
        
        if eval "$action"; then
            log_success "Rollback action #$((i+1)) completed" "ROLLBACK"
        else
            log_error "Rollback action #$((i+1)) failed" "ROLLBACK"
            ((rollback_errors++))
        fi
    done
    
    # Clear rollback stack
    ROLLBACK_STACK=()
    ROLLBACK_INDEX=0
    
    # Re-enable error trap
    set -e
    trap 'handle_error $? "$BASH_COMMAND" $LINENO $BASH_LINENO "${FUNCNAME[@]}"' ERR
    
    if [[ $rollback_errors -eq 0 ]]; then
        log_success "Rollback completed successfully" "ROLLBACK"
    else
        log_error "Rollback completed with $rollback_errors errors" "ROLLBACK"
    fi
    
    return $rollback_errors
}

# Clear rollback stack (for successful operations)
clear_rollback_stack() {
    ROLLBACK_STACK=()
    ROLLBACK_INDEX=0
    log_debug "Rollback stack cleared" "ROLLBACK"
}

# Attempt to recover from specific errors
attempt_error_recovery() {
    local error_code=$1
    local failed_command="$2"
    
    log_info "Attempting error recovery for exit code $error_code" "ERROR_RECOVERY"
    
    case $error_code in
        1)
            # General errors - check if it's a missing directory
            if [[ "$failed_command" =~ mkdir|cd ]]; then
                local dir_match
                if [[ "$failed_command" =~ mkdir[[:space:]]+-?p?[[:space:]]+([^[:space:]]+) ]]; then
                    dir_match="${BASH_REMATCH[1]}"
                    log_info "Attempting to create parent directories for: $dir_match" "ERROR_RECOVERY"
                    if mkdir -p "$(dirname "$dir_match")" 2>/dev/null; then
                        return 0
                    fi
                fi
            fi
            ;;
        
        2)
            # Misuse of shell builtins - often permission issues
            if [[ "$failed_command" =~ Permission\ denied|permission\ denied ]]; then
                log_info "Permission denied - checking if sudo is available" "ERROR_RECOVERY"
                if check_sudo_privileges; then
                    log_info "Retrying with sudo: $failed_command" "ERROR_RECOVERY"
                    if sudo $failed_command; then
                        return 0
                    fi
                fi
            fi
            ;;
        
        126)
            # Command cannot execute - usually permission issue
            log_info "Command not executable - attempting to fix permissions" "ERROR_RECOVERY"
            if [[ "$failed_command" =~ ^([^[:space:]]+) ]]; then
                local cmd="${BASH_REMATCH[1]}"
                if [[ -f "$cmd" ]] && chmod +x "$cmd" 2>/dev/null; then
                    log_info "Fixed permissions, retrying command" "ERROR_RECOVERY"
                    if $failed_command; then
                        return 0
                    fi
                fi
            fi
            ;;
        
        127)
            # Command not found
            log_warn "Command not found - cannot auto-recover" "ERROR_RECOVERY"
            ;;
    esac
    
    log_warn "Error recovery failed for exit code $error_code" "ERROR_RECOVERY"
    return $error_code
}

# Safe command execution with error handling
safe_execute() {
    local command="$1"
    local description="${2:-Executing command}"
    local allow_failure="${3:-false}"
    
    log_info "$description" "SAFE_EXECUTE"
    log_debug "Command: $command" "SAFE_EXECUTE"
    
    # Temporarily disable error trap if allowing failure
    if [[ "$allow_failure" == "true" ]]; then
        set +e
    fi
    
    # Execute command and capture result
    local output
    local exit_code
    output=$(eval "$command" 2>&1)
    exit_code=$?
    
    # Re-enable error trap
    if [[ "$allow_failure" == "true" ]]; then
        set -e
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "$description completed successfully" "SAFE_EXECUTE"
        [[ -n "$output" ]] && echo "$output"
        return 0
    else
        log_error "$description failed with exit code $exit_code" "SAFE_EXECUTE"
        [[ -n "$output" ]] && log_error "Output: $output" "SAFE_EXECUTE"
        
        if [[ "$allow_failure" != "true" ]]; then
            return $exit_code
        else
            log_warn "Continuing despite failure (allow_failure=true)" "SAFE_EXECUTE"
            return 0
        fi
    fi
}

# Transaction-like operation with automatic rollback
transactional_operation() {
    local operation_name="$1"
    shift
    local operations=("$@")
    
    log_info "Starting transactional operation: $operation_name" "TRANSACTION"
    
    # Save current rollback state
    local saved_rollback_index=$ROLLBACK_INDEX
    
    # Execute operations
    for op in "${operations[@]}"; do
        if ! eval "$op"; then
            log_error "Transaction failed at: $op" "TRANSACTION"
            
            # Rollback only operations from this transaction
            local transaction_rollback_count=$((ROLLBACK_INDEX - saved_rollback_index))
            if [[ $transaction_rollback_count -gt 0 ]]; then
                log_warn "Rolling back $transaction_rollback_count operations" "TRANSACTION"
                
                for ((i=ROLLBACK_INDEX-1; i>=saved_rollback_index; i--)); do
                    local action="${ROLLBACK_STACK[$i]}"
                    log_info "Rolling back: $action" "TRANSACTION"
                    eval "$action" || log_error "Rollback failed: $action" "TRANSACTION"
                done
                
                # Reset rollback index
                ROLLBACK_INDEX=$saved_rollback_index
            fi
            
            return 1
        fi
    done
    
    log_success "Transaction completed successfully: $operation_name" "TRANSACTION"
    return 0
}

# Retry operation with exponential backoff
retry_with_backoff() {
    local max_attempts="${1:-3}"
    local initial_delay="${2:-1}"
    local command="$3"
    local description="${4:-Operation}"
    
    local attempt=1
    local delay=$initial_delay
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "$description - Attempt $attempt/$max_attempts" "RETRY"
        
        if eval "$command"; then
            log_success "$description succeeded on attempt $attempt" "RETRY"
            return 0
        else
            local exit_code=$?
            log_warn "$description failed on attempt $attempt (exit code: $exit_code)" "RETRY"
            
            if [[ $attempt -lt $max_attempts ]]; then
                log_info "Waiting ${delay}s before retry..." "RETRY"
                sleep "$delay"
                delay=$((delay * 2))  # Exponential backoff
            fi
        fi
        
        ((attempt++))
    done
    
    log_error "$description failed after $max_attempts attempts" "RETRY"
    return 1
}

# Check if we're in a recoverable state
is_recoverable_error() {
    local error_code=$1
    
    case $error_code in
        0) return 0 ;;      # Success
        1) return 0 ;;      # General error - potentially recoverable
        2) return 0 ;;      # Misuse - potentially recoverable
        126) return 0 ;;    # Permission issue - potentially recoverable
        *) return 1 ;;      # Other errors - not recoverable
    esac
}

# Create error report
generate_error_report() {
    local report_file="${1:-$BASH_ADMIN_LOG_DIR/error_report_$(date +%Y%m%d_%H%M%S).log}"
    
    {
        echo "Error Report"
        echo "============"
        echo "Generated: $(date)"
        echo "Host: $(hostname -f)"
        echo "User: $(whoami)"
        echo "Script: ${0}"
        echo ""
        echo "Summary:"
        echo "--------"
        echo "Total Errors: $ERROR_COUNT"
        echo "Last Error: $LAST_ERROR"
        echo "Last Error Code: $LAST_ERROR_CODE"
        echo ""
        echo "Recent Errors:"
        echo "--------------"
        tail -50 "$ERROR_LOG_FILE" 2>/dev/null || echo "No error log available"
    } > "$report_file"
    
    log_info "Error report generated: $report_file" "ERROR_HANDLER"
    echo "$report_file"
}

# Clean up old error logs
cleanup_error_logs() {
    local retention_days="${1:-30}"
    local error_log_dir=$(dirname "$ERROR_LOG_FILE")
    
    log_info "Cleaning up error logs older than $retention_days days" "ERROR_HANDLER"
    
    find "$error_log_dir" -name "error*.log" -mtime +$retention_days -delete 2>/dev/null || true
}

# Test error handling (for debugging)
test_error_handling() {
    log_info "Testing error handling..." "ERROR_TEST"
    
    # Test 1: Basic error
    safe_execute "false" "Test basic error" "true"
    
    # Test 2: Command not found
    safe_execute "nonexistentcommand" "Test command not found" "true"
    
    # Test 3: Permission denied
    safe_execute "cat /etc/shadow" "Test permission denied" "true"
    
    # Test 4: Rollback
    register_rollback "echo 'Rollback action executed'" "Test rollback"
    safe_execute "false" "Test with rollback" "true"
    
    log_info "Error handling tests completed" "ERROR_TEST"
}