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

# Main execution function
main() {
    log_info "Starting $SCRIPT_NAME"
    
    # Ensure report directory exists
    mkdir -p "$REPORT_DIR"
    
    local overall_exit_code=0
    local task_results=()
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
            execute_admin_task "$task_name" "$full_script_path"
            local task_exit_code=$?
            
            if [[ $task_exit_code -eq 0 ]]; then
                task_results+=("✓ $task_name: Completed successfully")
            else
                task_results+=("✗ $task_name: Failed (exit code: $task_exit_code)")
                overall_exit_code=1
            fi
        else
            log_warn "Skipping $task_name: Script not found or not executable: $full_script_path"
            task_results+=("⚠ $task_name: Script not available")
        fi
    done
    
    # Calculate total execution time
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Generate master report
    generate_master_report "${task_results[@]}"
    
    # Send summary notification
    send_suite_summary "$overall_exit_code" "${task_results[@]}"
    
    log_info "$SCRIPT_NAME completed in ${total_duration}s with exit code $overall_exit_code"
    return $overall_exit_code
}

# Execute individual administrative task
execute_admin_task() {
    local task_name="$1"
    local script_path="$2"
    
    log_info "Executing $task_name: $script_path"
    
    local task_start=$(date +%s)
    local task_log="$REPORT_DIR/${task_name}_execution_$TODAY.log"
    
    # Execute the task with timeout and logging
    if timeout 1800 bash "$script_path" --quiet > "$task_log" 2>&1; then
        local task_end=$(date +%s)
        local task_duration=$((task_end - task_start))
        execution_times+=("$task_name: ${task_duration}s")
        log_success "$task_name completed in ${task_duration}s"
        return 0
    else
        local exit_code=$?
        local task_end=$(date +%s)
        local task_duration=$((task_end - task_start))
        execution_times+=("$task_name: ${task_duration}s (FAILED)")
        
        if [[ $exit_code -eq 124 ]]; then
            log_error "$task_name timed out after 30 minutes"
        else
            log_error "$task_name failed with exit code $exit_code"
        fi
        
        return $exit_code
    fi
}

# Generate master administration report
generate_master_report() {
    local results=("$@")
    
    # Count task outcomes
    local successful_tasks=0
    local failed_tasks=0
    local skipped_tasks=0
    
    for result in "${results[@]}"; do
        if [[ "$result" =~ ^✓ ]]; then
            ((successful_tasks++))
        elif [[ "$result" =~ ^✗ ]]; then
            ((failed_tasks++))
        else
            ((skipped_tasks++))
        fi
    done
    
    local total_tasks=$((successful_tasks + failed_tasks + skipped_tasks))
    
    cat > "$MASTER_REPORT" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Daily Administration Master Report - $(date)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .task-success { color: green; font-weight: bold; }
        .task-error { color: red; font-weight: bold; }
        .task-warning { color: orange; font-weight: bold; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .summary-box { padding: 15px; border-radius: 5px; margin: 10px 0; }
        .summary-success { background-color: #d4edda; border: 1px solid #c3e6cb; }
        .summary-warning { background-color: #fff3cd; border: 1px solid #ffeaa7; }
        .summary-danger { background-color: #f8d7da; border: 1px solid #f5c6cb; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .metric-good { background-color: #d4edda; }
        .metric-warning { background-color: #fff3cd; }
        .metric-danger { background-color: #f8d7da; }
        .execution-time { font-family: monospace; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Daily Administration Master Report</h1>
        <p><strong>Date:</strong> $(date)</p>
        <p><strong>Server:</strong> $(hostname)</p>
        <p><strong>Report Generated:</strong> $(date)</p>
    </div>
EOF
    
    # Add overall summary
    local summary_class="summary-success"
    local summary_status="All Clear"
    
    if [[ $failed_tasks -gt 0 ]]; then
        summary_class="summary-danger"
        summary_status="Issues Detected"
    elif [[ $skipped_tasks -gt 0 ]]; then
        summary_class="summary-warning"
        summary_status="Some Tasks Skipped"
    fi
    
    cat >> "$MASTER_REPORT" << EOF
    <div class="summary-box $summary_class">
        <h2>Overall Status: $summary_status</h2>
        <p><strong>Total Tasks:</strong> $total_tasks | 
           <strong>Successful:</strong> $successful_tasks | 
           <strong>Failed:</strong> $failed_tasks | 
           <strong>Skipped:</strong> $skipped_tasks</p>
    </div>
    
    <div class="section">
        <h2>Task Execution Results</h2>
        <ul>
EOF
    
    for result in "${results[@]}"; do
        if [[ "$result" =~ ^✓ ]]; then
            echo "            <li class=\"task-success\">$result</li>" >> "$MASTER_REPORT"
        elif [[ "$result" =~ ^✗ ]]; then
            echo "            <li class=\"task-error\">$result</li>" >> "$MASTER_REPORT"
        else
            echo "            <li class=\"task-warning\">$result</li>" >> "$MASTER_REPORT"
        fi
    done
    
    cat >> "$MASTER_REPORT" << EOF
        </ul>
    </div>
    
    <div class="section">
        <h2>Execution Times</h2>
        <table>
            <tr><th>Task</th><th>Duration</th><th>Status</th></tr>
EOF
    
    for timing in "${execution_times[@]}"; do
        local task=$(echo "$timing" | cut -d: -f1)
        local duration=$(echo "$timing" | cut -d: -f2)
        local status_class="metric-good"
        local status="OK"
        
        if [[ "$duration" =~ FAILED ]]; then
            status_class="metric-danger"
            status="FAILED"
            duration=$(echo "$duration" | sed 's/ (FAILED)//')
        fi
        
        echo "            <tr class=\"$status_class\"><td>$task</td><td class=\"execution-time\">$duration</td><td>$status</td></tr>" >> "$MASTER_REPORT"
    done
    
    cat >> "$MASTER_REPORT" << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>System Summary</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>System Uptime</td><td>$(uptime -p)</td></tr>
            <tr><td>Load Average</td><td>$(uptime | awk -F'load average:' '{print $2}')</td></tr>
            <tr><td>Memory Usage</td><td>$(free -h | awk 'NR==2{printf "%.1f%%", $3/$2*100}')</td></tr>
            <tr><td>Disk Usage (/)</td><td>$(df -h / | awk 'NR==2{print $5}')</td></tr>
            <tr><td>Active Users</td><td>$(who | wc -l)</td></tr>
        </table>
    </div>
    
    <div class="section">
        <h2>Individual Reports</h2>
        <ul>
            <li><a href="service_management_$TODAY.html">Service Management Report</a></li>
            <li><a href="package_management_$TODAY.html">Package Management Report</a></li>
            <li><a href="process_management_$TODAY.html">Process Management Report</a></li>
            <li><a href="daily_user_summary_$TODAY.html">User Management Report</a></li>
            <li><a href="daily_backup_summary_$TODAY.html">Backup Status Report</a></li>
            <li><a href="daily_security_summary_$TODAY.html">Security Audit Report</a></li>
            <li><a href="log_management_summary_$TODAY.html">Log Management Report</a></li>
            <li><a href="system_report_$TODAY.html">System Status Report</a></li>
        </ul>
    </div>
    
    <div class="section">
        <h2>Next Steps</h2>
EOF
    
    if [[ $failed_tasks -gt 0 ]]; then
        cat >> "$MASTER_REPORT" << EOF
        <div class="summary-box summary-danger">
            <h4>Immediate Action Required:</h4>
            <ul>
                <li>Review failed task logs for detailed error information</li>
                <li>Address any critical system issues immediately</li>
                <li>Check individual task reports for specific recommendations</li>
                <li>Consider manual intervention for failed automation tasks</li>
            </ul>
        </div>
EOF
    elif [[ $skipped_tasks -gt 0 ]]; then
        cat >> "$MASTER_REPORT" << EOF
        <div class="summary-box summary-warning">
            <h4>Review Required:</h4>
            <ul>
                <li>Verify skipped tasks are intentional or fix missing scripts</li>
                <li>Check system configuration for automation setup</li>
                <li>Review individual reports for any warnings</li>
            </ul>
        </div>
EOF
    else
        cat >> "$MASTER_REPORT" << EOF
        <div class="summary-box summary-success">
            <h4>System Status: Excellent</h4>
            <ul>
                <li>All administrative tasks completed successfully</li>
                <li>System is operating within normal parameters</li>
                <li>No immediate action required</li>
                <li>Continue regular monitoring schedule</li>
            </ul>
        </div>
EOF
    fi
    
    cat >> "$MASTER_REPORT" << EOF
    </div>
    
    <div class="section">
        <p><em>Master report generated by Linux Automation System at $(date)</em></p>
        <p><em>Next scheduled run: $(date -d 'tomorrow' '+%Y-%m-%d 06:00')</em></p>
    </div>
</body>
</html>
EOF
    
    log_info "Master administration report generated: $MASTER_REPORT"
}

# Send suite summary notification
send_suite_summary() {
    local exit_code="$1"
    shift
    local results=("$@")
    
    local subject
    local priority
    local recipient
    
    if [[ $exit_code -eq 0 ]]; then
        subject="✅ Daily Administration Complete - $(hostname)"
        priority="normal"
        recipient=$(get_config "notifications.recipients.admin")
    else
        subject="❌ Daily Administration Issues - $(hostname)"
        priority="high"
        recipient=$(get_config "notifications.recipients.admin")
    fi
    
    local email_body="Daily administration suite completed at $(date).

SUMMARY:
$(printf "%s\n" "${results[@]}")

Full reports available at: $MASTER_REPORT

Linux Automation System"
    
    if [[ -n "$recipient" ]]; then
        send_email "$recipient" "$subject" "$email_body" "$MASTER_REPORT"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Daily Administration Suite - Master Controller

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose logging
    -q, --quiet         Suppress non-error output
    --skip TASK         Skip specific task (service_check, package_check, process_check, user_tasks, backup_check, security_check, log_management, system_report)
    --only TASK         Run only specified task
    --dry-run           Show what would be executed without running

Examples:
    $0                          Run all daily admin tasks
    $0 --verbose                Run with detailed logging
    $0 --skip security_check    Skip security audit
    $0 --only package_check     Run only package management
    $0 --dry-run               Preview execution plan

Available Tasks:
$(printf "    %s\n" "${!ADMIN_SCRIPTS[@]}")

EOF
}

# Parse command line arguments
SKIP_TASKS=()
ONLY_TASK=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            set_log_level "DEBUG"
            shift
            ;;
        -q|--quiet)
            set_log_level "ERROR"
            shift
            ;;
        --skip)
            SKIP_TASKS+=("$2")
            shift 2
            ;;
        --only)
            ONLY_TASK="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Handle task filtering
if [[ -n "$ONLY_TASK" ]]; then
    if [[ -z "${ADMIN_SCRIPTS[$ONLY_TASK]}" ]]; then
        log_error "Unknown task: $ONLY_TASK"
        exit 1
    fi
    # Create new array with only the specified task
    declare -A FILTERED_SCRIPTS
    FILTERED_SCRIPTS["$ONLY_TASK"]="${ADMIN_SCRIPTS[$ONLY_TASK]}"
    ADMIN_SCRIPTS=()
    for key in "${!FILTERED_SCRIPTS[@]}"; do
        ADMIN_SCRIPTS["$key"]="${FILTERED_SCRIPTS[$key]}"
    done
fi

# Remove skipped tasks
for skip_task in "${SKIP_TASKS[@]}"; do
    if [[ -n "${ADMIN_SCRIPTS[$skip_task]}" ]]; then
        unset ADMIN_SCRIPTS["$skip_task"]
        log_info "Skipping task: $skip_task"
    else
        log_warn "Cannot skip unknown task: $skip_task"
    fi
done

# Dry run mode
if $DRY_RUN; then
    echo "DRY RUN - Would execute the following tasks:"
    for task_name in "${!ADMIN_SCRIPTS[@]}"; do
        echo "  $task_name: ${ADMIN_SCRIPTS[$task_name]}"
    done
    exit 0
fi

# Check for required privileges
require_root

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi