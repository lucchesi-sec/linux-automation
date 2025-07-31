#!/bin/bash
# Daily Administration Suite
# Master script to run all daily administrative tasks

# Source core libraries
source "$(dirname "$0")/../../core/lib/init.sh"

# Configuration
SCRIPT_NAME="Daily Administration Suite"
SUITE_DIR="$(dirname "$0")"
REPORT_DIR="/var/log/bash-admin/daily-reports"
TODAY=$(date +%Y%m%d)
MASTER_REPORT="$REPORT_DIR/daily_admin_master_$TODAY.html"

# Task scripts
declare -A ADMIN_SCRIPTS=(
    ["service_check"]="$SUITE_DIR/daily_service_check.sh"
    ["package_check"]="$SUITE_DIR/daily_package_check.sh"
    ["process_check"]="$SUITE_DIR/daily_process_check.sh"
    ["user_tasks"]="$SUITE_DIR/daily_user_tasks.sh"
    ["backup_check"]="$SUITE_DIR/daily_backup_check.sh"
    ["security_check"]="$SUITE_DIR/daily_security_check.sh"
    ["log_management"]="../maintenance/log_management.sh"
    ["system_report"]="$SUITE_DIR/system_report.sh"
)

# Version info
readonly VERSION="1.0.0"
readonly BUILD_DATE="2025-07-31"

# Show version information
show_version() {
    echo "$SCRIPT_NAME v$VERSION"
    echo "Built: $BUILD_DATE"
    echo "Core Library: $(cd "$(dirname "$0")" && git rev-parse --short HEAD 2>/dev/null || echo "local")"
    exit 0
}

# Show help information
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

OPTIONS:
    --help, -h     Show this help message
    --version, -v  Show version information
    --dry-run       Show what would be executed without running
    --skip TASK     Skip a specific task (use multiple times)
    --only TASK     Only run specific task
    --quiet         Suppress output except errors
    --verbose       Verbose logging

Tasks: ${!ADMIN_SCRIPTS[@]}
EOF
    exit 0
}

# Parse command line arguments
parse_args() {
    local skip_tasks=()
    local only_tasks=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -v|--version)
                show_version
                ;;
            --dry-run)
                export DRY_RUN=true
                shift
                ;;
            --skip)
                skip_tasks+=("$2")
                shift 2
                ;;
            --only)
                only_tasks+=("$2")
                shift 2
                ;;
            --quiet)
                export BASH_ADMIN_LOG_LEVEL=2
                shift
                ;;
            --verbose)
                export BASH_ADMIN_LOG_LEVEL=0
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                ;;
        esac
    done
    
    # Process skip/only filters
    if [[ ${#only_tasks[@]} -gt 0 ]]; then
        for task in "${!ADMIN_SCRIPTS[@]}"; do
            if [[ ! " ${only_tasks[*]} " =~ " $task " ]]; then
                unset ADMIN_SCRIPTS["$task"]
            fi
        done
    fi
    
    for task in "${skip_tasks[@]}"; do
        unset ADMIN_SCRIPTS["$task"]
    done
}

# Execute individual administrative task
execute_admin_task() {
    local task_name="$1"
    local script_path="$2"
    local task_start_time=$(date +%s)
    
    log_info "Executing $task_name..." "$SCRIPT_NAME"
    
    local temp_log="$REPORT_DIR/${task_name}_$(date +%s).log"
    
    if "$script_path" > "$temp_log" 2>&1; then
        log_success "$task_name completed successfully" "$SCRIPT_NAME"
        local task_exit_code=0
    else
        log_error "$task_name failed with exit code $?" "$SCRIPT_NAME"
        cat "$temp_log" >&2
        local task_exit_code=1
    fi
    
    local task_end_time=$(date +%s)
    local task_duration=$((task_end_time - task_start_time))
    
    # Clean up temporary log
    rm -f "$temp_log"
    
    return $task_exit_code
}

# Generate master report
generate_master_report() {
    local start_time="$1"
    local end_time="$2"
    local overall_status="$3"
    local task_results="$4"
    
    local duration=$((end_time - start_time))
    
    cat > "$MASTER_REPORT" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Daily Administration Suite Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .success { color: green; }
        .error { color: red; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
        .task { margin: 10px 0; padding: 5px; border-left: 3px solid #ddd; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Daily Administration Suite Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Duration:</strong> ${duration}s</p>
        <p><strong>Overall Status:</strong> 
$(if [[ $overall_status -eq 0 ]]; then echo "<span class='success'>SUCCESS</span>"; else echo "<span class='error'>PARTIAL SUCCESS</span>"; fi)
</p>
    </div>
    
    <h2>Task Execution Summary</h2>
    $task_results
</body>
</html>
EOF
}

# Main execution function
main() {
    log_info "Starting $SCRIPT_NAME v$VERSION"
    
    # Ensure report directory exists
    mkdir -p "$REPORT_DIR"
    
    local overall_exit_code=0
    local task_results=""
    local execution_times=()
    local start_time=$(date +%s)
    
    # Execute each administrative task
    for task_name in "${!ADMIN_SCRIPTS[@]}"; do
        local script_path="${ADMIN_SCRIPTS[$task_name]}"
        local full_script_path="$SUITE_DIR/$script_path"
        
        # Resolve relative paths
        if [[ "$script_path" =~ ^\.\. ]]; then
            full_script_path="$(dirname "$SUITE_DIR")/${script_path#../}"
        fi
        
        if [[ -f "$full_script_path" && -x "$full_script_path" ]]; then
            local task_start=$(date +%s)
            if execute_admin_task "$task_name" "$full_script_path"; then
                task_results+="<div class='task'><strong>$task_name:</strong> <span class='success'>SUCCESS</span> ($(($(date +%s) - task_start))s)</div>"
            else
                task_results+="<div class='task'><strong>$task_name:</strong> <span class='error'>FAILED</span> ($(($(date +%s) - task_start))s)</div>"
                overall_exit_code=1
            fi
        else
            log_warn "Script not found or executable: $full_script_path" "$SCRIPT_NAME"
            task_results+="<div class='task'><strong>$task_name:</strong> <span class='error'>SCRIPT MISSING</span></div>"
            overall_exit_code=1
        fi
    done
    
    local end_time=$(date +%s)
    
    # Generate master report
    generate_master_report "$start_time" "$end_time" "$overall_exit_code" "$task_results"
    
    log_info "Administration suite completed in $((end_time - start_time))s"
    log_info "Report saved to: $MASTER_REPORT"
    
    return $overall_exit_code
}

# Initialize and run
init_bash_admin "$SCRIPT_NAME" "$@"
parse_args "$@"
main "$@"
exit $?