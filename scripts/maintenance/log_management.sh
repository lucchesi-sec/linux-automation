#!/bin/bash
# Log Management and Analysis Script
# Automated log rotation, cleanup, and analysis

# Source core libraries
source "$(dirname "$0")/../../core/lib/init.sh"

# Configuration
SCRIPT_NAME="Log Management"
REPORT_DIR="/var/log/bash-admin/daily-reports"
TODAY=$(date +%Y%m%d)
DEFAULT_RETENTION_DAYS=30
ANALYSIS_REPORT="$REPORT_DIR/log_analysis_$TODAY.html"

# Main execution function
main() {
    log_info "Starting $SCRIPT_NAME"
    
    # Ensure report directory exists
    mkdir -p "$REPORT_DIR"
    
    local exit_code=0
    local task_results=()
    
    # Task 1: Rotate and compress logs
    log_info "Performing log rotation and compression"
    if rotate_logs; then
        task_results+=("✓ Log rotation completed successfully")
    else
        task_results+=("✗ Log rotation encountered issues")
        exit_code=1
    fi
    
    # Task 2: Clean up old logs
    log_info "Cleaning up old log files"
    if cleanup_old_logs "$DEFAULT_RETENTION_DAYS"; then
        task_results+=("✓ Old log cleanup completed")
    else
        task_results+=("✗ Old log cleanup failed")
        exit_code=1
    fi
    
    # Task 3: Analyze logs for issues
    log_info "Analyzing logs for issues and patterns"
    if analyze_system_logs; then
        task_results+=("✓ Log analysis completed")
    else
        task_results+=("⚠ Log analysis found issues")
        # Don't set exit_code=1 for analysis findings
    fi
    
    # Task 4: Monitor log disk usage
    log_info "Monitoring log disk usage"
    if monitor_log_disk_usage; then
        task_results+=("✓ Log disk usage within limits")
    else
        task_results+=("⚠ Log disk usage requires attention")
    fi
    
    # Generate summary report
    generate_log_report "${task_results[@]}"
    
    log_info "$SCRIPT_NAME completed with exit code $exit_code"
    return $exit_code
}

# Rotate and compress log files
rotate_logs() {
    local rotation_success=true
    local rotated_files=0
    
    # Define log files to rotate (if not using logrotate)
    local log_files=(
        "/var/log/auth.log"
        "/var/log/syslog"
        "/var/log/kern.log"
        "/var/log/mail.log"
        "/var/log/apache2/access.log"
        "/var/log/nginx/access.log"
        "/var/log/bash-admin/system.log"
    )
    
    # Check if logrotate is available and configured
    if command -v logrotate >/dev/null && [[ -f /etc/logrotate.conf ]]; then
        log_info "Using system logrotate for log rotation"
        if logrotate -f /etc/logrotate.conf 2>/dev/null; then
            log_success "System logrotate completed successfully"
            return 0
        else
            log_warn "System logrotate failed, performing manual rotation"
        fi
    fi
    
    # Manual log rotation for files that exist and are larger than 10MB
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            local file_size=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
            local size_mb=$((file_size / 1024 / 1024))
            
            if [[ $size_mb -gt 10 ]]; then
                log_debug "Rotating log file: $log_file (${size_mb}MB)"
                
                # Create timestamped backup
                local backup_name="${log_file}.$(date +%Y%m%d-%H%M%S)"
                
                if cp "$log_file" "$backup_name" && truncate -s 0 "$log_file"; then
                    # Compress the backup
                    if gzip "$backup_name" 2>/dev/null; then
                        log_success "Rotated and compressed: $log_file"
                        ((rotated_files++))
                    else
                        log_warn "Failed to compress rotated log: $backup_name"
                    fi
                else
                    log_error "Failed to rotate log file: $log_file"
                    rotation_success=false
                fi
            fi
        fi
    done
    
    log_info "Manual log rotation completed: $rotated_files files rotated"
    return $rotation_success
}

# Clean up old log files
cleanup_old_logs() {
    local retention_days="${1:-$DEFAULT_RETENTION_DAYS}"
    local files_removed=0
    local space_freed=0
    
    log_info "Removing log files older than $retention_days days"
    
    # Define log directories to clean
    local log_dirs=(
        "/var/log"
        "/var/log/apache2"
        "/var/log/nginx"
        "/var/log/mysql"
        "/var/log/postgresql"
        "/var/log/bash-admin"
    )
    
    for log_dir in "${log_dirs[@]}"; do
        if [[ -d "$log_dir" ]]; then
            log_debug "Cleaning old logs in: $log_dir"
            
            # Remove old compressed log files
            while IFS= read -r -d '' file; do
                local file_size=$(stat -c %s "$file" 2>/dev/null || echo 0)
                if rm -f "$file" 2>/dev/null; then
                    ((files_removed++))
                    space_freed=$((space_freed + file_size))
                    log_debug "Removed old log: $file"
                fi
            done < <(find "$log_dir" -type f \( -name "*.gz" -o -name "*.log.*" \) -mtime +$retention_days -print0 2>/dev/null)
        fi
    done
    
    local space_freed_mb=$((space_freed / 1024 / 1024))
    log_info "Log cleanup completed: $files_removed files removed, ${space_freed_mb}MB freed"
    
    return 0
}

# Analyze system logs for issues and patterns
analyze_system_logs() {
    local analysis_file="$REPORT_DIR/log_analysis_details_$TODAY.txt"
    local issues_found=0
    local error_count=0
    local warning_count=0
    local auth_failures=0
    
    log_info "Analyzing system logs for issues"
    
    # Analyze authentication failures
    if [[ -f /var/log/auth.log ]]; then
        auth_failures=$(grep "$(date '+%b %d')" /var/log/auth.log | grep -c "authentication failure")
        if [[ $auth_failures -gt 10 ]]; then
            ((issues_found++))
            log_warn "High number of authentication failures: $auth_failures"
        fi
    fi
    
    # Analyze system errors in syslog
    if [[ -f /var/log/syslog ]]; then
        error_count=$(grep "$(date '+%b %d')" /var/log/syslog | grep -ci "error")
        warning_count=$(grep "$(date '+%b %d')" /var/log/syslog | grep -ci "warning")
        
        if [[ $error_count -gt 50 ]]; then
            ((issues_found++))
            log_warn "High number of system errors: $error_count"
        fi
    fi
    
    # Check for disk space issues
    local disk_errors=$(grep "$(date '+%b %d')" /var/log/syslog 2>/dev/null | grep -ci "no space left\|disk full")
    if [[ $disk_errors -gt 0 ]]; then
        ((issues_found++))
        log_error "Disk space issues detected: $disk_errors occurrences"
    fi
    
    # Check for OOM (Out of Memory) errors
    local oom_errors=$(grep "$(date '+%b %d')" /var/log/syslog 2>/dev/null | grep -ci "out of memory\|oom")
    if [[ $oom_errors -gt 0 ]]; then
        ((issues_found++))
        log_error "Out of memory errors detected: $oom_errors occurrences"
    fi
    
    # Analyze web server logs if present
    local web_errors=0
    for web_log in "/var/log/apache2/error.log" "/var/log/nginx/error.log"; do
        if [[ -f "$web_log" ]]; then
            web_errors=$(grep "$(date '+%Y/%m/%d\|%d/%b/%Y')" "$web_log" 2>/dev/null | grep -ci "error" || echo 0)
            if [[ $web_errors -gt 20 ]]; then
                ((issues_found++))
                log_warn "High number of web server errors in $web_log: $web_errors"
            fi
        fi
    done
    
    # Generate detailed analysis report
    {
        echo "System Log Analysis Report - $(date)"
        echo "=================================="
        echo
        echo "SUMMARY STATISTICS:"
        echo "  Authentication failures: $auth_failures"
        echo "  System errors: $error_count"
        echo "  System warnings: $warning_count"
        echo "  Disk space issues: $disk_errors"
        echo "  Memory issues: $oom_errors"
        echo "  Web server errors: $web_errors"
        echo
        echo "ISSUES REQUIRING ATTENTION: $issues_found"
        echo
        if [[ $issues_found -gt 0 ]]; then
            echo "RECOMMENDATIONS:"
            echo "  - Review authentication logs for suspicious activity"
            echo "  - Investigate system errors and warnings"
            echo "  - Monitor disk space and memory usage"
            echo "  - Check web server configuration if applicable"
        else
            echo "No significant issues detected in today's logs"
        fi
    } > "$analysis_file"
    
    log_info "Log analysis report generated: $analysis_file"
    
    # Send notification if significant issues found
    if [[ $issues_found -gt 5 ]]; then
        send_notification "admin" "High Number of Log Issues" \
            "Found $issues_found significant issues in today's logs. Check $analysis_file for details."
    fi
    
    return $issues_found
}

# Monitor log disk usage
monitor_log_disk_usage() {
    local warning_threshold=80
    local critical_threshold=90
    local log_usage_ok=true
    
    # Check /var/log disk usage
    local var_log_usage=$(df /var/log | awk 'NR==2 {print int($5)}')
    log_info "Log partition (/var/log) usage: ${var_log_usage}%"
    
    if [[ $var_log_usage -ge $critical_threshold ]]; then
        log_error "CRITICAL: Log partition usage at ${var_log_usage}%"
        send_notification "admin" "Critical Log Disk Usage" \
            "Log partition usage at ${var_log_usage}%. Immediate cleanup required."
        log_usage_ok=false
    elif [[ $var_log_usage -ge $warning_threshold ]]; then
        log_warn "WARNING: Log partition usage at ${var_log_usage}%"
        send_notification "admin" "Log Disk Usage Warning" \
            "Log partition usage at ${var_log_usage}%. Consider cleanup."
    fi
    
    # Check individual log file sizes
    local large_logs=()
    while IFS= read -r -d '' file; do
        local file_size_mb=$(du -m "$file" | cut -f1)
        if [[ $file_size_mb -gt 100 ]]; then
            large_logs+=("$(basename "$file"): ${file_size_mb}MB")
        fi
    done < <(find /var/log -type f -name "*.log" -print0 2>/dev/null)
    
    if [[ ${#large_logs[@]} -gt 0 ]]; then
        log_warn "Large log files detected:"
        printf "  %s\n" "${large_logs[@]}"
    fi
    
    return $log_usage_ok
}

# Generate comprehensive log management report
generate_log_report() {
    local results=("$@")
    local report_file="$REPORT_DIR/log_management_summary_$TODAY.html"
    
    # Get log statistics
    local total_log_files=$(find /var/log -type f -name "*.log" 2>/dev/null | wc -l)
    local compressed_logs=$(find /var/log -type f -name "*.gz" 2>/dev/null | wc -l)
    local log_dir_size=$(du -sh /var/log 2>/dev/null | cut -f1)
    local oldest_log=$(find /var/log -type f -name "*.log" -printf '%T@ %p\n' 2>/dev/null | sort -n | head -1 | cut -d' ' -f2- | xargs -I {} basename {})
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Log Management Report - $(date)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
        .task-success { color: green; }
        .task-warning { color: orange; }
        .task-error { color: red; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .usage-normal { background-color: #d4edda; }
        .usage-warning { background-color: #fff3cd; }
        .usage-critical { background-color: #f8d7da; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Log Management Report</h1>
        <p><strong>Date:</strong> $(date)</p>
        <p><strong>Server:</strong> $(hostname)</p>
    </div>
    
    <div class="section">
        <h2>Task Summary</h2>
        <ul>
EOF
    
    for result in "${results[@]}"; do
        if [[ "$result" =~ ^✓ ]]; then
            echo "            <li class=\"task-success\">$result</li>" >> "$report_file"
        elif [[ "$result" =~ ^⚠ ]]; then
            echo "            <li class=\"task-warning\">$result</li>" >> "$report_file"
        else
            echo "            <li class=\"task-error\">$result</li>" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF
        </ul>
    </div>
    
    <div class="section">
        <h2>Log Statistics</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Total Log Files</td><td>$total_log_files</td></tr>
            <tr><td>Compressed Log Files</td><td>$compressed_logs</td></tr>
            <tr><td>Total Log Directory Size</td><td>$log_dir_size</td></tr>
            <tr><td>Oldest Log File</td><td>$oldest_log</td></tr>
            <tr><td>Last Maintenance</td><td>$(date)</td></tr>
        </table>
    </div>
    
    <div class="section">
        <h2>Disk Usage</h2>
        <table>
            <tr><th>Path</th><th>Size</th><th>Used</th><th>Available</th><th>Use%</th><th>Status</th></tr>
EOF
    
    # Add disk usage information
    df -h /var/log | tail -1 | while read filesystem size used avail use_percent mountpoint; do
        local use_num=${use_percent%\%}
        local css_class="usage-normal"
        local status="Normal"
        
        if [[ $use_num -ge 90 ]]; then
            css_class="usage-critical"
            status="Critical"
        elif [[ $use_num -ge 80 ]]; then
            css_class="usage-warning"
            status="Warning"
        fi
        
        echo "            <tr class=\"$css_class\"><td>/var/log</td><td>$size</td><td>$used</td><td>$avail</td><td>$use_percent</td><td>$status</td></tr>" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>Log Analysis Summary</h2>
        <p>Detailed log analysis results can be found in: <a href="log_analysis_details_$TODAY.txt">Log Analysis Details</a></p>
    </div>
    
    <div class="section">
        <p><em>Report generated by Linux Automation System at $(date)</em></p>
    </div>
</body>
</html>
EOF
    
    log_info "Log management summary report generated: $report_file"
    
    # Send email notification
    local subject="Log Management Report - $(hostname)"
    local recipient=$(get_config "notifications.recipients.admin")
    
    if [[ -n "$recipient" ]]; then
        send_email "$recipient" "$subject" "Daily log management report attached." "$report_file"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Log Management and Analysis

Options:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose logging
    -q, --quiet             Suppress non-error output
    -r, --retention DAYS    Set log retention period (default: $DEFAULT_RETENTION_DAYS)
    --rotate-only           Only perform log rotation
    --analyze-only          Only perform log analysis

Examples:
    $0                      Run complete log management
    $0 --verbose            Run with detailed logging
    $0 -r 60               Set 60-day retention period
    $0 --analyze-only      Only analyze logs, no rotation

EOF
}

# Parse command line arguments
ROTATE_ONLY=false
ANALYZE_ONLY=false

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
        -r|--retention)
            DEFAULT_RETENTION_DAYS="$2"
            shift 2
            ;;
        --rotate-only)
            ROTATE_ONLY=true
            shift
            ;;
        --analyze-only)
            ANALYZE_ONLY=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check for required privileges
require_root

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi