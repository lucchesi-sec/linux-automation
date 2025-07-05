#!/bin/bash
# Daily Security Audit Script
# Automated security checks and compliance monitoring

# Source core libraries and security audit module
source "$(dirname "$0")/../../core/lib/init.sh"
source "$(dirname "$0")/../../modules/system/security_audit.sh"

# Configuration
SCRIPT_NAME="Daily Security Audit"
REPORT_DIR="/var/log/bash-admin/security-reports"
TODAY=$(date +%Y%m%d)

# Main execution function
main() {
    log_info "Starting $SCRIPT_NAME"
    
    # Ensure report directory exists
    mkdir -p "$REPORT_DIR"
    
    local exit_code=0
    local task_results=()
    
    # Task 1: Check file permissions
    log_info "Auditing file permissions"
    local perm_issues
    perm_issues=$(check_file_permissions "$REPORT_DIR/file_permissions_$TODAY.txt")
    local perm_exit_code=$?
    
    if [[ $perm_exit_code -eq 0 ]]; then
        task_results+=("✓ File permissions audit passed")
    else
        task_results+=("✗ Found $perm_issues file permission issues")
        exit_code=1
    fi
    
    # Task 2: Check running processes and network connections
    log_info "Analyzing running processes and network connections"
    local proc_issues
    proc_issues=$(check_running_processes "$REPORT_DIR/process_security_$TODAY.txt")
    local proc_exit_code=$?
    
    if [[ $proc_exit_code -eq 0 ]]; then
        task_results+=("✓ Process and network security check passed")
    else
        task_results+=("✗ Found $proc_issues suspicious processes/connections")
        exit_code=1
    fi
    
    # Task 3: Check security configuration
    log_info "Verifying security configuration"
    local config_issues
    config_issues=$(check_security_config "$REPORT_DIR/security_config_$TODAY.txt")
    local config_exit_code=$?
    
    if [[ $config_exit_code -eq 0 ]]; then
        task_results+=("✓ Security configuration compliant")
    else
        task_results+=("✗ Found $config_issues security configuration issues")
        exit_code=1
    fi
    
    # Task 4: Check for vulnerabilities and updates
    log_info "Scanning for vulnerabilities and security updates"
    local vuln_issues
    vuln_issues=$(check_system_vulnerabilities "$REPORT_DIR/vulnerability_scan_$TODAY.txt")
    local vuln_exit_code=$?
    
    if [[ $vuln_exit_code -eq 0 ]]; then
        task_results+=("✓ No critical vulnerabilities detected")
    else
        task_results+=("⚠ Found $vuln_issues security updates/vulnerabilities")
        # Don't fail for available updates, just warn
    fi
    
    # Generate comprehensive security report
    generate_security_report "${task_results[@]}"
    
    log_info "$SCRIPT_NAME completed with exit code $exit_code"
    return $exit_code
}

# Generate comprehensive security report
generate_security_report() {
    local results=("$@")
    local report_file="$REPORT_DIR/daily_security_summary_$TODAY.html"
    
    # Collect system security metrics
    local failed_login_count=$(grep "Failed password" /var/log/auth.log 2>/dev/null | grep "$(date '+%b %d')" | wc -l)
    local sudo_usage=$(grep "sudo:" /var/log/auth.log 2>/dev/null | grep "$(date '+%b %d')" | wc -l)
    local listening_ports=$(netstat -tuln 2>/dev/null | grep LISTEN | wc -l)
    local root_processes=$(ps -eo user | grep -c "^root")
    local last_reboot=$(uptime -s)
    local system_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Daily Security Audit Report - $(date)</title>
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
        .security-score { font-size: 24px; font-weight: bold; text-align: center; padding: 20px; border-radius: 10px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Daily Security Audit Report</h1>
        <p><strong>Date:</strong> $(date)</p>
        <p><strong>Server:</strong> $(hostname)</p>
        <p><strong>Report ID:</strong> SEC-$TODAY-$(hostname | cut -c1-3 | tr '[:lower:]' '[:upper:]')</p>
    </div>
    
    <div class="section">
        <h2>Security Audit Summary</h2>
        <ul>
EOF
    
    # Calculate security score
    local security_score=100
    for result in "${results[@]}"; do
        if [[ "$result" =~ ^✗ ]]; then
            security_score=$((security_score - 20))
        elif [[ "$result" =~ ^⚠ ]]; then
            security_score=$((security_score - 10))
        fi
    done
    
    local score_class="metric-good"
    if [[ $security_score -lt 70 ]]; then
        score_class="metric-critical"
    elif [[ $security_score -lt 85 ]]; then
        score_class="metric-warning"
    fi
    
    cat >> "$report_file" << EOF
        </ul>
        <div class="security-score $score_class">
            Security Score: ${security_score}%
        </div>
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
        <h2>Security Metrics</h2>
        <table>
            <tr><th>Metric</th><th>Value</th><th>Status</th></tr>
            <tr>
                <td>Failed Login Attempts (Today)</td>
                <td>$failed_login_count</td>
                <td class="$(if [[ $failed_login_count -gt 10 ]]; then echo 'metric-warning'; else echo 'metric-good'; fi)">
                    $(if [[ $failed_login_count -gt 10 ]]; then echo 'High'; else echo 'Normal'; fi)
                </td>
            </tr>
            <tr>
                <td>Sudo Usage (Today)</td>
                <td>$sudo_usage</td>
                <td class="metric-good">Normal</td>
            </tr>
            <tr>
                <td>Listening Network Ports</td>
                <td>$listening_ports</td>
                <td class="$(if [[ $listening_ports -gt 20 ]]; then echo 'metric-warning'; else echo 'metric-good'; fi)">
                    $(if [[ $listening_ports -gt 20 ]]; then echo 'Review'; else echo 'Normal'; fi)
                </td>
            </tr>
            <tr>
                <td>Root Processes</td>
                <td>$root_processes</td>
                <td class="metric-good">Normal</td>
            </tr>
            <tr>
                <td>Last System Reboot</td>
                <td>$last_reboot</td>
                <td class="metric-good">Normal</td>
            </tr>
            <tr>
                <td>System Load</td>
                <td>$system_load</td>
                <td class="$(if (( $(echo "$system_load > 2.0" | bc -l) )); then echo 'metric-warning'; else echo 'metric-good'; fi)">
                    $(if (( $(echo "$system_load > 2.0" | bc -l) )); then echo 'High'; else echo 'Normal'; fi)
                </td>
            </tr>
        </table>
    </div>
    
    <div class="section">
        <h2>System Services Status</h2>
        <table>
            <tr><th>Service</th><th>Status</th><th>Security Impact</th></tr>
EOF
    
    # Check critical security services
    local security_services=("ssh" "ufw" "fail2ban" "clamav-daemon" "apparmor")
    for service in "${security_services[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            echo "            <tr><td>$service</td><td class=\"metric-good\">Active</td><td>Positive</td></tr>" >> "$report_file"
        elif systemctl list-unit-files | grep -q "^$service"; then
            echo "            <tr><td>$service</td><td class=\"metric-warning\">Inactive</td><td>Review needed</td></tr>" >> "$report_file"
        else
            echo "            <tr><td>$service</td><td class=\"metric-warning\">Not installed</td><td>Consider installing</td></tr>" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>Recent Security Events</h2>
        <table>
            <tr><th>Time</th><th>Event</th><th>Severity</th></tr>
EOF
    
    # Parse recent security events from logs
    if [[ -f /var/log/auth.log ]]; then
        grep "$(date '+%b %d')" /var/log/auth.log 2>/dev/null | \
        grep -E "(Failed password|sudo:|Invalid user)" | \
        tail -10 | \
        while IFS= read -r line; do
            local timestamp=$(echo "$line" | awk '{print $1" "$2" "$3}')
            local event=$(echo "$line" | cut -d' ' -f5- | cut -c1-80)
            local severity="Info"
            
            if [[ "$line" =~ "Failed password" ]]; then
                severity="Warning"
            elif [[ "$line" =~ "Invalid user" ]]; then
                severity="Warning"
            fi
            
            echo "            <tr><td>$timestamp</td><td>$event</td><td>$severity</td></tr>" >> "$report_file"
        done
    fi
    
    cat >> "$report_file" << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>Security Recommendations</h2>
        <ul>
EOF
    
    # Generate dynamic recommendations based on findings
    if [[ $failed_login_count -gt 10 ]]; then
        echo "            <li class=\"task-warning\">High number of failed login attempts - consider implementing fail2ban</li>" >> "$report_file"
    fi
    
    if [[ $listening_ports -gt 20 ]]; then
        echo "            <li class=\"task-warning\">Many listening ports detected - review and close unnecessary services</li>" >> "$report_file"
    fi
    
    if ! systemctl is-active ufw >/dev/null 2>&1; then
        echo "            <li class=\"task-error\">Firewall not active - enable UFW or configure iptables</li>" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF
            <li>Regularly update system packages and security patches</li>
            <li>Review user access permissions and remove unused accounts</li>
            <li>Monitor system logs for suspicious activities</li>
            <li>Implement intrusion detection systems if not already present</li>
            <li>Ensure backup systems are secure and regularly tested</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>Generated Reports</h2>
        <ul>
            <li><a href="file_permissions_$TODAY.txt">File Permissions Report</a></li>
            <li><a href="process_security_$TODAY.txt">Process Security Report</a></li>
            <li><a href="security_config_$TODAY.txt">Security Configuration Report</a></li>
            <li><a href="vulnerability_scan_$TODAY.txt">Vulnerability Scan Report</a></li>
        </ul>
    </div>
    
    <div class="section">
        <p><em>Report generated by Linux Automation System at $(date)</em></p>
        <p><em>Next audit scheduled for $(date -d '+1 day' '+%Y-%m-%d')</em></p>
    </div>
</body>
</html>
EOF
    
    log_info "Security audit report generated: $report_file"
    
    # Send email notification
    local subject="Daily Security Audit Report - $(hostname) (Score: ${security_score}%)"
    local recipient=$(get_config "notifications.recipients.security")
    
    if [[ -n "$recipient" ]]; then
        local priority="normal"
        if [[ $security_score -lt 70 ]]; then
            priority="high"
        elif [[ $security_score -lt 85 ]]; then
            priority="medium"
        fi
        
        send_email "$recipient" "$subject" \
            "Daily security audit completed with score ${security_score}%. Please review attached report for details." \
            "$report_file"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Daily Security Audit and Compliance Check

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose logging
    -q, --quiet         Suppress non-error output
    --quick             Run quick security check (skip vulnerability scan)

Examples:
    $0                  Run full security audit
    $0 --verbose        Run with detailed logging
    $0 --quick          Run quick security check

EOF
}

# Parse command line arguments
QUICK_MODE=false

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
        --quick)
            QUICK_MODE=true
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