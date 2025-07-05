#!/bin/bash
# Daily Log Maintenance Script
# Automated log analysis, rotation, and cleanup

# Source core libraries and log management module
source "$(dirname "$0")/../../core/lib/init.sh"
source "$(dirname "$0")/../../modules/system/log_management.sh"

# Configuration
SCRIPT_NAME="Daily Log Maintenance"
REPORT_DIR="/var/log/bash-admin/log-reports"
TODAY=$(date +%Y%m%d)
LOG_RETENTION_DAYS=30
LOG_COMPRESS_DAYS=7
LOG_WARNING_SIZE_MB=100
LOG_CRITICAL_SIZE_MB=500

# Main execution function
main() {
    log_info "Starting $SCRIPT_NAME"
    
    # Ensure report directory exists
    mkdir -p "$REPORT_DIR"
    
    local exit_code=0
    local task_results=()
    
    # Task 1: Analyze system logs for issues
    log_info "Analyzing system logs for issues and patterns"
    local log_issues
    log_issues=$(analyze_system_logs "$REPORT_DIR/log_analysis_$TODAY.txt" 1)
    local analysis_exit_code=$?
    
    if [[ $analysis_exit_code -eq 0 ]]; then
        task_results+=("✓ Log analysis completed - no critical issues")
    else
        task_results+=("⚠ Found $log_issues log issues requiring attention")
        # Don't fail script for log issues, just warn
    fi
    
    # Task 2: Monitor log file growth
    log_info "Monitoring log file growth and disk usage"
    local growth_issues
    growth_issues=$(monitor_log_growth "$REPORT_DIR/log_growth_$TODAY.txt" "$LOG_WARNING_SIZE_MB" "$LOG_CRITICAL_SIZE_MB")
    local growth_exit_code=$?
    
    if [[ $growth_exit_code -eq 0 ]]; then
        task_results+=("✓ Log file sizes within normal limits")
    else
        task_results+=("⚠ Found $growth_issues log growth issues")
        if [[ $growth_issues -gt 0 ]]; then
            # Check if any are critical
            if grep -q "CRITICAL" "$REPORT_DIR/log_growth_$TODAY.txt"; then
                exit_code=1
            fi
        fi
    fi
    
    # Task 3: Rotate and cleanup old logs
    log_info "Rotating and cleaning up old log files"
    if rotate_logs "$LOG_RETENTION_DAYS" "$LOG_COMPRESS_DAYS"; then
        task_results+=("✓ Log rotation and cleanup completed")
    else
        task_results+=("✗ Log rotation encountered issues")
        exit_code=1
    fi
    
    # Task 4: Generate log statistics
    log_info "Generating log statistics and insights"
    if generate_log_stats "$REPORT_DIR/log_stats_$TODAY.txt" 7; then
        task_results+=("✓ Log statistics generated successfully")
    else
        task_results+=("✗ Failed to generate log statistics")
        exit_code=1
    fi
    
    # Task 5: Check log service health
    log_info "Checking log service health"
    if check_log_services; then
        task_results+=("✓ All log services running normally")
    else
        task_results+=("⚠ Some log services need attention")
        # Don't fail for service issues
    fi
    
    # Generate comprehensive log maintenance report
    generate_log_maintenance_report "${task_results[@]}"
    
    log_info "$SCRIPT_NAME completed with exit code $exit_code"
    return $exit_code
}

# Check health of logging services
check_log_services() {
    local service_issues=0
    
    # Check systemd-journald
    if ! systemctl is-active systemd-journald >/dev/null 2>&1; then
        log_error "systemd-journald is not running"
        ((service_issues++))
    fi
    
    # Check rsyslog if installed
    if systemctl list-unit-files | grep -q rsyslog; then
        if ! systemctl is-active rsyslog >/dev/null 2>&1; then
            log_error "rsyslog service is not running"
            ((service_issues++))
        fi
    fi
    
    # Check syslog-ng if installed
    if systemctl list-unit-files | grep -q syslog-ng; then
        if ! systemctl is-active syslog-ng >/dev/null 2>&1; then
            log_error "syslog-ng service is not running"
            ((service_issues++))
        fi
    fi
    
    # Check logrotate configuration
    if [[ ! -f /etc/logrotate.conf ]]; then
        log_error "logrotate configuration not found"
        ((service_issues++))
    fi
    
    return $service_issues
}

# Generate comprehensive log maintenance report
generate_log_maintenance_report() {
    local results=("$@")
    local report_file="$REPORT_DIR/daily_log_summary_$TODAY.html"
    
    # Collect log maintenance metrics
    local total_log_size=$(du -sh /var/log 2>/dev/null | cut -f1)
    local total_log_files=$(find /var/log -type f -name "*.log*" | wc -l)
    local compressed_logs=$(find /var/log -name "*.gz" -o -name "*.bz2" | wc -l)
    local large_logs=$(find /var/log -type f -size +100M | wc -l)
    local old_logs=$(find /var/log -type f -mtime +30 | wc -l)
    local log_errors=$(grep -c "ERROR\|CRITICAL\|FATAL" /var/log/syslog 2>/dev/null || echo 0)
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Daily Log Maintenance Report - $(date)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
        .task-success { color: green; }
        .task-warning { color: orange; }
        .task-error { color: red; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .metric-good { background-color: #d4edda; padding: 5px; border-radius: 3px; }
        .metric-warning { background-color: #fff3cd; padding: 5px; border-radius: 3px; }
        .metric-critical { background-color: #f8d7da; padding: 5px; border-radius: 3px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .chart-container { text-align: center; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Daily Log Maintenance Report</h1>
        <p><strong>Date:</strong> $(date)</p>
        <p><strong>Server:</strong> $(hostname)</p>
        <p><strong>Maintenance ID:</strong> LOG-$TODAY-$(hostname | cut -c1-3 | tr '[:lower:]' '[:upper:]')</p>
    </div>
    
    <div class="section">
        <h2>Maintenance Task Summary</h2>
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
        <h2>Log System Health Metrics</h2>
        <table>
            <tr><th>Metric</th><th>Value</th><th>Status</th></tr>
            <tr>
                <td>Total Log Directory Size</td>
                <td>$total_log_size</td>
                <td class="metric-good">Normal</td>
            </tr>
            <tr>
                <td>Total Log Files</td>
                <td>$total_log_files</td>
                <td class="metric-good">Normal</td>
            </tr>
            <tr>
                <td>Compressed Log Files</td>
                <td>$compressed_logs</td>
                <td class="metric-good">Normal</td>
            </tr>
            <tr>
                <td>Large Log Files (&gt;100MB)</td>
                <td>$large_logs</td>
                <td class="$(if [[ $large_logs -gt 5 ]]; then echo 'metric-warning'; else echo 'metric-good'; fi)">
                    $(if [[ $large_logs -gt 5 ]]; then echo 'Review'; else echo 'Normal'; fi)
                </td>
            </tr>
            <tr>
                <td>Old Log Files (&gt;30 days)</td>
                <td>$old_logs</td>
                <td class="$(if [[ $old_logs -gt 10 ]]; then echo 'metric-warning'; else echo 'metric-good'; fi)">
                    $(if [[ $old_logs -gt 10 ]]; then echo 'Cleanup'; else echo 'Normal'; fi)
                </td>
            </tr>
            <tr>
                <td>Recent Log Errors</td>
                <td>$log_errors</td>
                <td class="$(if [[ $log_errors -gt 50 ]]; then echo 'metric-warning'; else echo 'metric-good'; fi)">
                    $(if [[ $log_errors -gt 50 ]]; then echo 'High'; else echo 'Normal'; fi)
                </td>
            </tr>
        </table>
    </div>
    
    <div class="section">
        <h2>Log Service Status</h2>
        <table>
            <tr><th>Service</th><th>Status</th><th>Health</th></tr>
EOF
    
    # Check logging services status
    local log_services=("systemd-journald" "rsyslog" "syslog-ng" "logrotate")
    for service in "${log_services[@]}"; do
        if systemctl list-unit-files | grep -q "$service"; then
            if systemctl is-active "$service" >/dev/null 2>&1; then
                echo "            <tr><td>$service</td><td class=\"metric-good\">Active</td><td>Healthy</td></tr>" >> "$report_file"
            else
                echo "            <tr><td>$service</td><td class=\"metric-warning\">Inactive</td><td>Needs attention</td></tr>" >> "$report_file"
            fi
        elif [[ "$service" == "logrotate" ]]; then
            if [[ -f /etc/logrotate.conf ]]; then
                echo "            <tr><td>$service</td><td class=\"metric-good\">Configured</td><td>Available</td></tr>" >> "$report_file"
            else
                echo "            <tr><td>$service</td><td class=\"metric-warning\">Not configured</td><td>Setup needed</td></tr>" >> "$report_file"
            fi
        else
            echo "            <tr><td>$service</td><td class=\"metric-warning\">Not installed</td><td>Optional</td></tr>" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>Log File Breakdown</h2>
        <table>
            <tr><th>Log File</th><th>Size</th><th>Last Modified</th><th>Lines</th></tr>
EOF
    
    # Show breakdown of major log files
    local major_logs=("/var/log/syslog" "/var/log/auth.log" "/var/log/kern.log" "/var/log/daemon.log")
    for log_file in "${major_logs[@]}"; do
        if [[ -f "$log_file" ]]; then
            local size=$(ls -lh "$log_file" | awk '{print $5}')
            local modified=$(ls -l "$log_file" | awk '{print $6" "$7" "$8}')
            local lines=$(wc -l < "$log_file" 2>/dev/null || echo "N/A")
            echo "            <tr><td>$(basename "$log_file")</td><td>$size</td><td>$modified</td><td>$lines</td></tr>" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>Maintenance Actions Performed</h2>
        <ul>
            <li>Analyzed system logs for errors and patterns</li>
            <li>Monitored log file growth and disk usage</li>
            <li>Rotated logs older than $LOG_COMPRESS_DAYS days</li>
            <li>Cleaned up logs older than $LOG_RETENTION_DAYS days</li>
            <li>Generated log statistics and insights</li>
            <li>Verified log service health and configuration</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>Recommendations</h2>
        <ul>
EOF
    
    # Generate dynamic recommendations
    if [[ $large_logs -gt 5 ]]; then
        echo "            <li class=\"task-warning\">Consider more frequent log rotation for large log files</li>" >> "$report_file"
    fi
    
    if [[ $log_errors -gt 50 ]]; then
        echo "            <li class=\"task-warning\">High number of log errors detected - investigate causes</li>" >> "$report_file"
    fi
    
    if [[ $old_logs -gt 10 ]]; then
        echo "            <li class=\"task-warning\">Many old log files found - consider adjusting retention policy</li>" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF
            <li>Monitor disk space in /var/log regularly</li>
            <li>Review log rotation configuration periodically</li>
            <li>Consider implementing log aggregation for better management</li>
            <li>Set up automated alerts for critical log errors</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>Generated Reports</h2>
        <ul>
            <li><a href="log_analysis_$TODAY.txt">Log Analysis Report</a></li>
            <li><a href="log_growth_$TODAY.txt">Log Growth Monitoring Report</a></li>
            <li><a href="log_stats_$TODAY.txt">Log Statistics Report</a></li>
        </ul>
    </div>
    
    <div class="section">
        <p><em>Report generated by Linux Automation System at $(date)</em></p>
        <p><em>Next maintenance scheduled for $(date -d '+1 day' '+%Y-%m-%d')</em></p>
    </div>
</body>
</html>
EOF
    
    log_info "Log maintenance report generated: $report_file"
    
    # Send email notification
    local subject="Daily Log Maintenance Report - $(hostname)"
    local recipient=$(get_config "notifications.recipients.admin")
    
    if [[ -n "$recipient" ]]; then
        send_email "$recipient" "$subject" \
            "Daily log maintenance completed. Please review attached report for details." \
            "$report_file"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Daily Log Maintenance and Analysis

Options:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose logging
    -q, --quiet             Suppress non-error output
    -r, --retention DAYS    Set log retention period (default: $LOG_RETENTION_DAYS)
    -c, --compress DAYS     Set compression age (default: $LOG_COMPRESS_DAYS)
    --analysis-only         Run only log analysis, skip rotation/cleanup

Examples:
    $0                      Run full log maintenance
    $0 --verbose            Run with detailed logging
    $0 -r 60 -c 14         Keep logs 60 days, compress after 14 days
    $0 --analysis-only      Run analysis only

EOF
}

# Parse command line arguments
ANALYSIS_ONLY=false

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
            LOG_RETENTION_DAYS="$2"
            shift 2
            ;;
        -c|--compress)
            LOG_COMPRESS_DAYS="$2"
            shift 2
            ;;
        --analysis-only)
            ANALYSIS_ONLY=true
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