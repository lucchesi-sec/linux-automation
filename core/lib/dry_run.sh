#!/bin/bash

# BashAdminCore - Dry Run Mode Module
# Provides dry-run simulation capabilities for safe operation testing

# Global dry-run variables
declare -g DRY_RUN_MODE=false
declare -g DRY_RUN_LOG_FILE="${BASH_ADMIN_LOG_DIR:-/var/log/bash-admin}/dry_run.log"
declare -gA DRY_RUN_COMMANDS
declare -g DRY_RUN_COMMAND_COUNT=0

# Initialize dry-run mode
init_dry_run() {
    # Check if dry-run mode is enabled via environment or config
    if [[ "${BASH_ADMIN_DRY_RUN:-false}" == "true" ]] || [[ "${DRY_RUN:-false}" == "true" ]]; then
        enable_dry_run
    fi
    
    # Create dry-run log directory if needed
    local dry_run_log_dir=$(dirname "$DRY_RUN_LOG_FILE")
    if [[ ! -d "$dry_run_log_dir" ]]; then
        mkdir -p "$dry_run_log_dir" 2>/dev/null || {
            DRY_RUN_LOG_FILE="$HOME/.bash-admin/logs/dry_run.log"
            mkdir -p "$(dirname "$DRY_RUN_LOG_FILE")"
        }
    fi
    
    log_debug "Dry-run mode initialized (enabled: $DRY_RUN_MODE)" "DRY_RUN"
}

# Enable dry-run mode
enable_dry_run() {
    DRY_RUN_MODE=true
    log_info "DRY-RUN MODE ENABLED - No actual changes will be made" "DRY_RUN"
    
    # Start new dry-run session log
    {
        echo "=== DRY-RUN SESSION STARTED ==="
        echo "Time: $(date)"
        echo "User: $(whoami)"
        echo "Host: $(hostname -f)"
        echo "Script: ${0}"
        echo "================================"
        echo ""
    } >> "$DRY_RUN_LOG_FILE"
}

# Disable dry-run mode
disable_dry_run() {
    DRY_RUN_MODE=false
    log_info "Dry-run mode disabled - Operations will execute normally" "DRY_RUN"
}

# Check if in dry-run mode
is_dry_run() {
    [[ "$DRY_RUN_MODE" == "true" ]]
}

# Execute or simulate command based on dry-run mode
dry_run_execute() {
    local command="$1"
    local description="${2:-Executing command}"
    local impact="${3:-MODIFY}"  # READ, MODIFY, DELETE, CREATE
    
    ((DRY_RUN_COMMAND_COUNT++))
    
    if is_dry_run; then
        # Log what would be executed
        log_info "[DRY-RUN] Would execute: $description" "DRY_RUN"
        log_debug "[DRY-RUN] Command: $command" "DRY_RUN"
        log_debug "[DRY-RUN] Impact: $impact" "DRY_RUN"
        
        # Store command details
        DRY_RUN_COMMANDS[$DRY_RUN_COMMAND_COUNT]="$command|$description|$impact"
        
        # Log to dry-run file
        {
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Command #$DRY_RUN_COMMAND_COUNT"
            echo "Description: $description"
            echo "Impact: $impact"
            echo "Command: $command"
            echo "---"
        } >> "$DRY_RUN_LOG_FILE"
        
        # Simulate success for read operations in dry-run
        if [[ "$impact" == "READ" ]]; then
            return 0
        else
            # For modify operations, return success but don't execute
            return 0
        fi
    else
        # Actually execute the command
        log_command "$command" "$description"
    fi
}

# Wrapper for file operations with dry-run support
dry_run_file_operation() {
    local operation="$1"
    local file_path="$2"
    local description="$3"
    shift 3
    local extra_args=("$@")
    
    case "$operation" in
        "create")
            if is_dry_run; then
                log_info "[DRY-RUN] Would create file: $file_path" "DRY_RUN"
                return 0
            else
                touch "$file_path" "${extra_args[@]}"
            fi
            ;;
        
        "delete")
            if is_dry_run; then
                log_info "[DRY-RUN] Would delete: $file_path" "DRY_RUN"
                return 0
            else
                rm "$file_path" "${extra_args[@]}"
            fi
            ;;
        
        "modify")
            if is_dry_run; then
                log_info "[DRY-RUN] Would modify: $file_path" "DRY_RUN"
                [[ -n "$description" ]] && log_debug "[DRY-RUN] Changes: $description" "DRY_RUN"
                return 0
            else
                # Actual modification would be handled by caller
                return 0
            fi
            ;;
        
        "copy")
            local dest="${extra_args[0]}"
            if is_dry_run; then
                log_info "[DRY-RUN] Would copy: $file_path -> $dest" "DRY_RUN"
                return 0
            else
                cp "$file_path" "$dest" "${extra_args[@]:1}"
            fi
            ;;
        
        "move")
            local dest="${extra_args[0]}"
            if is_dry_run; then
                log_info "[DRY-RUN] Would move: $file_path -> $dest" "DRY_RUN"
                return 0
            else
                mv "$file_path" "$dest" "${extra_args[@]:1}"
            fi
            ;;
    esac
}

# Wrapper for user operations with dry-run support
dry_run_user_operation() {
    local operation="$1"
    local username="$2"
    shift 2
    local extra_args=("$@")
    
    case "$operation" in
        "create")
            if is_dry_run; then
                log_info "[DRY-RUN] Would create user: $username" "DRY_RUN"
                [[ ${#extra_args[@]} -gt 0 ]] && log_debug "[DRY-RUN] Options: ${extra_args[*]}" "DRY_RUN"
                return 0
            else
                useradd "$username" "${extra_args[@]}"
            fi
            ;;
        
        "delete")
            if is_dry_run; then
                log_info "[DRY-RUN] Would delete user: $username" "DRY_RUN"
                return 0
            else
                userdel "$username" "${extra_args[@]}"
            fi
            ;;
        
        "modify")
            if is_dry_run; then
                log_info "[DRY-RUN] Would modify user: $username" "DRY_RUN"
                [[ ${#extra_args[@]} -gt 0 ]] && log_debug "[DRY-RUN] Changes: ${extra_args[*]}" "DRY_RUN"
                return 0
            else
                usermod "$username" "${extra_args[@]}"
            fi
            ;;
    esac
}

# Wrapper for package operations with dry-run support
dry_run_package_operation() {
    local operation="$1"
    local package="$2"
    local package_manager="${3:-auto}"
    
    # Auto-detect package manager if needed
    if [[ "$package_manager" == "auto" ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            package_manager="apt"
        elif command -v yum >/dev/null 2>&1; then
            package_manager="yum"
        elif command -v dnf >/dev/null 2>&1; then
            package_manager="dnf"
        else
            log_error "No supported package manager found" "DRY_RUN"
            return 1
        fi
    fi
    
    case "$operation" in
        "install")
            if is_dry_run; then
                log_info "[DRY-RUN] Would install package: $package (using $package_manager)" "DRY_RUN"
                return 0
            else
                case "$package_manager" in
                    apt) apt-get install -y "$package" ;;
                    yum) yum install -y "$package" ;;
                    dnf) dnf install -y "$package" ;;
                esac
            fi
            ;;
        
        "remove")
            if is_dry_run; then
                log_info "[DRY-RUN] Would remove package: $package (using $package_manager)" "DRY_RUN"
                return 0
            else
                case "$package_manager" in
                    apt) apt-get remove -y "$package" ;;
                    yum) yum remove -y "$package" ;;
                    dnf) dnf remove -y "$package" ;;
                esac
            fi
            ;;
        
        "update")
            if is_dry_run; then
                log_info "[DRY-RUN] Would update package: $package (using $package_manager)" "DRY_RUN"
                return 0
            else
                case "$package_manager" in
                    apt) apt-get upgrade -y "$package" ;;
                    yum) yum update -y "$package" ;;
                    dnf) dnf update -y "$package" ;;
                esac
            fi
            ;;
    esac
}

# Generate dry-run summary report
generate_dry_run_summary() {
    local summary_file="${1:-$BASH_ADMIN_LOG_DIR/dry_run_summary_$(date +%Y%m%d_%H%M%S).log}"
    
    if [[ $DRY_RUN_COMMAND_COUNT -eq 0 ]]; then
        log_info "No dry-run commands recorded" "DRY_RUN"
        return 0
    fi
    
    {
        echo "Dry-Run Summary Report"
        echo "====================="
        echo "Generated: $(date)"
        echo "Total Commands: $DRY_RUN_COMMAND_COUNT"
        echo ""
        echo "Commands by Impact Type:"
        echo "-----------------------"
        
        # Count by impact type
        local read_count=0
        local modify_count=0
        local create_count=0
        local delete_count=0
        
        for i in "${!DRY_RUN_COMMANDS[@]}"; do
            IFS='|' read -r cmd desc impact <<< "${DRY_RUN_COMMANDS[$i]}"
            case "$impact" in
                READ) ((read_count++)) ;;
                MODIFY) ((modify_count++)) ;;
                CREATE) ((create_count++)) ;;
                DELETE) ((delete_count++)) ;;
            esac
        done
        
        echo "  READ operations: $read_count"
        echo "  MODIFY operations: $modify_count"
        echo "  CREATE operations: $create_count"
        echo "  DELETE operations: $delete_count"
        echo ""
        echo "Detailed Command List:"
        echo "---------------------"
        
        for i in "${!DRY_RUN_COMMANDS[@]}"; do
            IFS='|' read -r cmd desc impact <<< "${DRY_RUN_COMMANDS[$i]}"
            echo ""
            echo "Command #$i:"
            echo "  Description: $desc"
            echo "  Impact: $impact"
            echo "  Command: $cmd"
        done
    } | tee "$summary_file"
    
    log_success "Dry-run summary generated: $summary_file" "DRY_RUN"
}

# Check if a command would be safe to run
is_safe_command() {
    local command="$1"
    
    # List of read-only commands that are always safe
    local safe_commands=(
        "ls" "cat" "grep" "find" "stat" "file" "head" "tail"
        "ps" "top" "df" "du" "free" "uptime" "who" "w"
        "date" "hostname" "uname" "id" "groups"
    )
    
    # Extract the base command
    local base_cmd
    base_cmd=$(echo "$command" | awk '{print $1}')
    
    # Check if it's in the safe list
    for safe_cmd in "${safe_commands[@]}"; do
        if [[ "$base_cmd" == "$safe_cmd" ]]; then
            return 0
        fi
    done
    
    # Check for obviously unsafe patterns
    if [[ "$command" =~ (rm|delete|del|purge|format|mkfs|dd) ]]; then
        return 1
    fi
    
    # Default to unsafe
    return 1
}

# Simulate command execution for testing
simulate_command() {
    local command="$1"
    local expected_output="${2:-Command executed successfully}"
    local expected_exit_code="${3:-0}"
    
    if is_dry_run; then
        log_info "[DRY-RUN SIMULATION] Command: $command" "DRY_RUN"
        log_info "[DRY-RUN SIMULATION] Expected output: $expected_output" "DRY_RUN"
        log_info "[DRY-RUN SIMULATION] Expected exit code: $expected_exit_code" "DRY_RUN"
        
        # Simulate output
        echo "$expected_output"
        return $expected_exit_code
    else
        # Actually execute
        eval "$command"
    fi
}

# Cleanup dry-run logs
cleanup_dry_run_logs() {
    local retention_days="${1:-7}"
    local dry_run_log_dir=$(dirname "$DRY_RUN_LOG_FILE")
    
    log_info "Cleaning up dry-run logs older than $retention_days days" "DRY_RUN"
    
    find "$dry_run_log_dir" -name "dry_run*.log" -mtime +$retention_days -delete 2>/dev/null || true
}