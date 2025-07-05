#!/bin/bash
# Daily Security Check Script
# Automated security audit and compliance monitoring

# Source core libraries and security audit module
source "$(dirname "$0")/../../core/lib/init.sh"
source "$(dirname "$0")/../../modules/system/security_audit.sh"

# Configuration
SCRIPT_NAME="Daily Security Check"
REPORT_DIR="/var/log/bash-admin/daily-reports"
TODAY=$(date +%Y%m%d)

# Main execution function
main() {
    log_info "Starting $SCRIPT_NAME"
    
    # Ensure report directory exists
    mkdir -p "$REPORT_DIR"
    
    local exit_code=0
    local task_results=()
    local total_security_issues=0
    
    # Task 1: File permissions check
    log_info "Checking file permissions"
    if check_file_permissions "$REPORT_DIR/file_permissions_$TODAY.txt"; then
        task_results+=("✓ File permissions check passed")
    else
        local perm_issues=$?
        task_results+=("✗ Found $perm_issues file permission issues")
        total_security_issues=$((total_security_issues + perm_issues))
        exit_code=1
    fi
    
    # Task 2: Process and network security check
    log_info "Checking running processes and network connections"
    if check_running_processes "$REPORT_DIR/process_security_$TODAY.txt"; then
        task_results+=("✓ Process and network security check passed")
    else
        local proc_issues=$?
        task_results+=("✗ Found $proc_issues suspicious processes/connections")
        total_security_issues=$((total_security_issues + proc_issues))
        exit_code=1
    fi
    
    # Task 3: Security configuration compliance
    log_info "Checking security configuration compliance"
    if check_security_config "$REPORT_DIR/security_config_$TODAY.txt"; then
        task_results+=("✓ Security configuration compliance passed")
    else
        local config_issues=$?
        task_results+=("✗ Found $config_issues security configuration issues")
        total_security_issues=$((total_security_issues + config_issues))
        exit_code=1
    fi
    
    # Task 4: Vulnerability assessment
    log_info "Performing vulnerability assessment"
    if check_system_vulnerabilities "$REPORT_DIR/vulnerability_scan_$TODAY.txt"; then
        task_results+=("✓ No critical vulnerabilities found")
    else
        local vuln_issues=$?
        task_results+=("⚠ Found $vuln_issues potential vulnerabilities")
        total_security_issues=$((total_security_issues + vuln_issues))
        # Don't set exit_code=1 for vulnerabilities as they may be informational
    fi
    
    # Additional security checks
    perform_additional_checks
    task_results+=("${additional_check_results[@]}")
    
    # Generate comprehensive security report
    generate_security_report "${task_results[@]}"
    
    log_info "$SCRIPT_NAME completed with $total_security_issues total security issues (exit code: $exit_code)"
    return $exit_code
}

# Perform additional security checks
perform_additional_checks() {
    additional_check_results=()
    
    # Check for failed sudo attempts
    local sudo_failures=0
    if [[ -f /var/log/auth.log ]]; then
        sudo_failures=$(grep "$(date '+%b %d')" /var/log/auth.log | grep -c "sudo.*FAILED")
    fi
    
    if [[ $sudo_failures -gt 0 ]]; then
        additional_check_results+=("⚠ Found $sudo_failures failed sudo attempts today")
        log_warn "Found $sudo_failures failed sudo attempts today"
    else
        additional_check_results+=("✓ No failed sudo attempts detected")
    fi
    
    # Check for users with empty passwords
    local empty_password_users=()
    while IFS=: read -r username password rest; do
        if [[ "$password" == "" && "$username" != "root" ]]; then
            empty_password_users+=("$username")
        fi
    done < /etc/shadow
    
    if [[ ${#empty_password_users[@]} -gt 0 ]]; then
        additional_check_results+=("✗ Users with empty passwords: ${empty_password_users[*]}")
        log_error "Users with empty passwords found: ${empty_password_users[*]}"
    else
        additional_check_results+=("✓ No users with empty passwords found")
    fi
    
    # Check for accounts with UID 0 (root privileges)
    local root_accounts=()
    while IFS=: read -r username password uid rest; do
        if [[ $uid -eq 0 && "$username" != "root" ]]; then
            root_accounts+=("$username")
        fi
    done < /etc/passwd
    
    if [[ ${#root_accounts[@]} -gt 0 ]]; then
        additional_check_results+=("✗ Non-root accounts with UID 0: ${root_accounts[*]}")
        log_error "Non-root accounts with UID 0 found: ${root_accounts[*]}"
    else
        additional_check_results+=("✓ No unauthorized root accounts found")
    fi
    
    # Check disk space for security logs
    local log_usage=$(df /var/log | awk 'NR==2 {print int($5)}')
    if [[ $log_usage -ge 90 ]]; then
        additional_check_results+=("⚠ Log partition usage high: ${log_usage}%")
        log_warn "Log partition usage high: ${log_usage}%"
    else
        additional_check_results+=("✓ Log partition usage acceptable: ${log_usage}%")
    fi
}

# Generate comprehensive security report
generate_security_report() {
    local results=("$@")
    local report_file="$REPORT_DIR/daily_security_summary_$TODAY.html"
    
    # Get system security metrics
    local total_users=$(getent passwd | wc -l)
    local active_users=$(getent passwd | awk -F: '$3 >= 1000 {print $1}' | wc -l)
    local listening_ports=$(netstat -tuln 2>/dev/null | grep LISTEN | wc -l)
    local running_services=$(systemctl list-units --type=service --state=running | grep -c "\.service")
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Daily Security Report - $(date)</title>
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
        .security-high { background-color: #f8d7da; }
        .security-medium { background-color: #fff3cd; }
        .security-low { background-color: #d4edda; }
        .alert-box { padding: 15px; margin: 10px 0; border-radius: 5px; }
        .alert-danger { background-color: #f8d7da; border: 1px solid #f5c6cb; }
        .alert-warning { background-color: #fff3cd; border: 1px solid #ffeaa7; }
        .alert-success { background-color: #d4edda; border: 1px solid #c3e6cb; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Daily Security Report</h1>
        <p><strong>Date:</strong> $(date)</p>
        <p><strong>Server:</strong> $(hostname)</p>
        <p><strong>Security Level:</strong> <span class="security-level">$(determine_security_level "${results[@]}")</span></p>
    </div>
    
    <div class="section">
        <h2>Security Check Results</h2>
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
        <h2>System Security Metrics</h2>
        <table>
            <tr><th>Metric</th><th>Value</th><th>Status</th></tr>
            <tr><td>Total User Accounts</td><td>$total_users</td><td class="security-low">Normal</td></tr>
            <tr><td>Active User Accounts</td><td>$active_users</td><td class="security-low">Normal</td></tr>
            <tr><td>Listening Network Ports</td><td>$listening_ports</td><td class="security-low">Normal</td></tr>
            <tr><td>Running Services</td><td>$running_services</td><td class="security-low">Normal</td></tr>
            <tr><td>Last Security Scan</td><td>$(date)</td><td class="security-low">Current</td></tr>
        </table>
    </div>
    
    <div class="section">
        <h2>Security Recommendations</h2>
        <div class="alert-box alert-success">
            <h4>Good Security Practices Detected:</h4>
            <ul>
                <li>Regular security monitoring in place</li>
                <li>Automated security reporting active</li>
                <li>System logging enabled</li>
            </ul>
        </div>
EOF
    
    # Add specific recommendations based on findings
    local has_warnings=false
    local has_errors=false
    
    for result in "${results[@]}"; do
        if [[ "$result" =~ ^⚠ ]]; then
            has_warnings=true
        elif [[ "$result" =~ ^✗ ]]; then
            has_errors=true
        fi
    done
    
    if $has_errors; then
        cat >> "$report_file" << EOF
        <div class="alert-box alert-danger">
            <h4>Critical Issues Requiring Immediate Attention:</h4>
            <ul>
                <li>Review and fix all file permission issues</li>
                <li>Investigate suspicious processes immediately</li>
                <li>Update security configuration as needed</li>
                <li>Consider emergency security measures if necessary</li>
            </ul>
        </div>
EOF
    fi
    
    if $has_warnings; then
        cat >> "$report_file" << EOF
        <div class="alert-box alert-warning">
            <h4>Items for Review:</h4>
            <ul>
                <li>Monitor failed login attempts</li>
                <li>Review system vulnerabilities and plan updates</li>
                <li>Consider implementing additional security measures</li>
                <li>Schedule security configuration review</li>
            </ul>
        </div>
EOF
    fi
    
    cat >> "$report_file" << EOF
    </div>
    
    <div class="section">
        <h2>Generated Security Reports</h2>
        <ul>
            <li><a href="file_permissions_$TODAY.txt">File Permissions Report</a></li>
            <li><a href="process_security_$TODAY.txt">Process Security Report</a></li>
            <li><a href="security_config_$TODAY.txt">Security Configuration Report</a></li>
            <li><a href="vulnerability_scan_$TODAY.txt">Vulnerability Scan Report</a></li>
        </ul>
    </div>
    
    <div class="section">
        <p><em>Security report generated by Linux Automation System at $(date)</em></p>
        <p><em>Next automated security check: $(date -d 'tomorrow' '+%Y-%m-%d %H:%M')</em></p>
    </div>
</body>
</html>
EOF
    
    log_info "Security summary report generated: $report_file"
    
    # Send email notification with priority based on findings
    local subject="Daily Security Report - $(hostname)"
    local recipient
    
    if $has_errors; then
        subject="🚨 CRITICAL Security Issues - $(hostname)"
        recipient=$(get_config "notifications.recipients.security")
    elif $has_warnings; then
        subject="⚠️ Security Warnings - $(hostname)"
        recipient=$(get_config "notifications.recipients.security")
    else
        subject="✅ Security All Clear - $(hostname)"
        recipient=$(get_config "notifications.recipients.admin")
    fi
    
    if [[ -n "$recipient" ]]; then
        send_email "$recipient" "$subject" "Daily security audit report attached." "$report_file"
    fi
}

# Determine overall security level
determine_security_level() {
    local results=("$@")
    local has_errors=false
    local has_warnings=false
    
    for result in "${results[@]}"; do
        if [[ "$result" =~ ^✗ ]]; then
            has_errors=true
        elif [[ "$result" =~ ^⚠ ]]; then
            has_warnings=true
        fi
    done
    
    if $has_errors; then
        echo "HIGH RISK"
    elif $has_warnings; then
        echo "MEDIUM RISK"
    else
        echo "LOW RISK"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Daily Security Check and Compliance Monitoring

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose logging
    -q, --quiet         Suppress non-error output
    --quick             Run quick security check only

Examples:
    $0                  Run complete security audit
    $0 --verbose        Run with detailed logging
    $0 --quick          Run basic security checks only

EOF
}

# Parse command line arguments
QUICK_CHECK=false

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
            QUICK_CHECK=true
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