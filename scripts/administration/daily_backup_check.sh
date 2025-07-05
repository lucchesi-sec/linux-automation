#!/bin/bash
# Daily Backup Verification Script
# Automated backup monitoring and verification

# Source core libraries and backup monitoring module
source "$(dirname "$0")/../../core/lib/init.sh"
source "$(dirname "$0")/../../modules/system/backup_monitor.sh"

# Configuration
SCRIPT_NAME="Daily Backup Check"
REPORT_DIR="/var/log/bash-admin/daily-reports"
TODAY=$(date +%Y%m%d)
BACKUP_CONFIG="/etc/bash-admin/backup-jobs.conf"

# Create backup configuration if it doesn't exist
create_backup_config() {
    if [[ ! -f "$BACKUP_CONFIG" ]]; then
        mkdir -p "$(dirname "$BACKUP_CONFIG")"
        cat > "$BACKUP_CONFIG" << 'EOF'
# Backup Jobs Configuration
# Format: job_name,backup_path,schedule,retention_days
# Lines starting with # are comments
system_backup,/backup/system/system_backup_$(date +%Y%m%d).tar.gz,daily,30
database_backup,/backup/db/mysql_dump_$(date +%Y%m%d).sql.gz,daily,14
home_backup,/backup/users/home_backup_$(date +%Y%m%d).tar.gz,weekly,60
config_backup,/backup/config/etc_backup_$(date +%Y%m%d).tar.gz,daily,90
EOF
        log_info "Created default backup configuration: $BACKUP_CONFIG"
    fi
}

# Main execution function
main() {
    log_info "Starting $SCRIPT_NAME"
    
    # Ensure report directory exists
    mkdir -p "$REPORT_DIR"
    
    # Create backup config if needed
    create_backup_config
    
    local exit_code=0
    local task_results=()
    
    # Task 1: Monitor backup jobs status
    log_info "Monitoring backup job status"
    if monitor_backup_jobs "$BACKUP_CONFIG" "$REPORT_DIR/backup_status_$TODAY.txt"; then
        task_results+=("✓ All backup jobs completed successfully")
    else
        task_results+=("✗ Some backup jobs failed")
        exit_code=1
    fi
    
    # Task 2: Check backup storage space
    log_info "Checking backup storage space"
    local backup_dirs=("/backup" "/var/backups")
    
    for backup_dir in "${backup_dirs[@]}"; do
        if [[ -d "$backup_dir" ]]; then
            if manage_backup_storage "$backup_dir" 30 85 95; then
                task_results+=("✓ Backup storage $backup_dir: OK")
            else
                task_results+=("⚠ Backup storage $backup_dir: Issues detected")
                # Don't fail script for storage warnings
            fi
        fi
    done
    
    # Task 3: Test sample backup restore
    log_info "Testing backup restore capabilities"
    local test_backup=$(find /backup -name "*.tar.gz" -o -name "*.zip" | head -1)
    if [[ -n "$test_backup" ]]; then
        if test_backup_restore "$test_backup"; then
            task_results+=("✓ Backup restore test successful")
        else
            task_results+=("✗ Backup restore test failed")
            exit_code=1
        fi
    else
        task_results+=("⚠ No backup files found for restore testing")
    fi
    
    # Task 4: Verify recent backups integrity
    log_info "Verifying backup file integrity"
    local integrity_issues=0
    
    # Check backups from last 24 hours
    while IFS= read -r -d '' backup_file; do
        if ! verify_backup_integrity "$backup_file" "" 24; then
            ((integrity_issues++))
        fi
    done < <(find /backup -type f -mtime -1 \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.sql.gz" \) -print0 2>/dev/null)
    
    if [[ $integrity_issues -eq 0 ]]; then
        task_results+=("✓ All recent backups passed integrity checks")
    else
        task_results+=("✗ $integrity_issues backup(s) failed integrity checks")
        exit_code=1
    fi
    
    # Generate comprehensive report
    generate_backup_report "${task_results[@]}"
    
    log_info "$SCRIPT_NAME completed with exit code $exit_code"
    return $exit_code
}

# Generate detailed backup report
generate_backup_report() {
    local results=("$@")
    local report_file="$REPORT_DIR/daily_backup_summary_$TODAY.html"
    
    # Get backup statistics
    local total_backups=$(find /backup -type f -name "*.tar.gz" -o -name "*.zip" -o -name "*.sql.gz" 2>/dev/null | wc -l)
    local recent_backups=$(find /backup -type f -mtime -1 -name "*.tar.gz" -o -name "*.zip" -o -name "*.sql.gz" 2>/dev/null | wc -l)
    local backup_size=$(du -sh /backup 2>/dev/null | cut -f1)
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Daily Backup Report - $(date)</title>
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
        .metric-good { background-color: #d4edda; }
        .metric-warning { background-color: #fff3cd; }
        .metric-danger { background-color: #f8d7da; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Daily Backup Report</h1>
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
        <h2>Backup Statistics</h2>
        <table>
            <tr><th>Metric</th><th>Value</th><th>Status</th></tr>
            <tr><td>Total Backup Files</td><td>$total_backups</td><td class="metric-good">OK</td></tr>
            <tr><td>Recent Backups (24h)</td><td>$recent_backups</td><td class="metric-good">OK</td></tr>
            <tr><td>Total Backup Size</td><td>$backup_size</td><td class="metric-good">OK</td></tr>
            <tr><td>Last Check</td><td>$(date)</td><td class="metric-good">Current</td></tr>
        </table>
    </div>
    
    <div class="section">
        <h2>Storage Usage</h2>
        <table>
            <tr><th>Path</th><th>Size</th><th>Used</th><th>Available</th><th>Use%</th></tr>
EOF
    
    # Add storage information for backup directories
    for backup_dir in /backup /var/backups; do
        if [[ -d "$backup_dir" ]]; then
            df -h "$backup_dir" | tail -1 | while read filesystem size used avail use_percent mountpoint; do
                local css_class="metric-good"
                local use_num=${use_percent%\%}
                if [[ $use_num -ge 95 ]]; then
                    css_class="metric-danger"
                elif [[ $use_num -ge 85 ]]; then
                    css_class="metric-warning"
                fi
                echo "            <tr class=\"$css_class\"><td>$backup_dir</td><td>$size</td><td>$used</td><td>$avail</td><td>$use_percent</td></tr>" >> "$report_file"
            done
        fi
    done
    
    cat >> "$report_file" << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>Recent Backup Files</h2>
        <table>
            <tr><th>File</th><th>Size</th><th>Date</th><th>Age (hours)</th></tr>
EOF
    
    # List recent backup files
    find /backup -type f -mtime -2 \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.sql.gz" \) -printf "%p|%s|%TY-%Tm-%Td %TH:%TM|%CH\n" 2>/dev/null | \
    head -10 | while IFS='|' read -r filepath filesize filedate filehours; do
        local size_mb=$((filesize / 1024 / 1024))
        echo "            <tr><td>$(basename "$filepath")</td><td>${size_mb}MB</td><td>$filedate</td><td>$filehours</td></tr>" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>Generated Reports</h2>
        <ul>
            <li><a href="backup_status_$TODAY.txt">Backup Status Report</a></li>
        </ul>
    </div>
    
    <div class="section">
        <p><em>Report generated by Linux Automation System at $(date)</em></p>
    </div>
</body>
</html>
EOF
    
    log_info "Backup summary report generated: $report_file"
    
    # Send email notification
    local subject="Daily Backup Report - $(hostname)"
    local recipient=$(get_config "notifications.recipients.admin")
    
    if [[ -n "$recipient" ]]; then
        send_email "$recipient" "$subject" "Daily backup verification report attached." "$report_file"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Daily Backup Verification and Monitoring

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose logging
    -q, --quiet         Suppress non-error output
    -c, --config FILE   Use custom backup configuration file

Examples:
    $0                  Run all backup checks
    $0 --verbose        Run with detailed logging
    $0 -c /custom/backup.conf  Use custom config

EOF
}

# Parse command line arguments
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
        -c|--config)
            BACKUP_CONFIG="$2"
            shift 2
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