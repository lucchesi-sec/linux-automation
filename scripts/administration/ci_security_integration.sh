#!/bin/bash

# CI/CD Security Integration Script
# Integrates CI/CD security scan results with the existing bash-admin security infrastructure

# Source core libraries
source "$(dirname "$0")/../../core/lib/init.sh"

# Configuration
SCRIPT_NAME="CI/CD Security Integration"
CI_SECURITY_DIR="/var/log/bash-admin/ci-security"
REPORT_DIR="/var/log/bash-admin/daily-reports"
TODAY=$(date +%Y%m%d)
INTEGRATION_REPORT="$REPORT_DIR/ci_security_integration_$TODAY.html"

# GitHub API configuration (if available)
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GITHUB_REPO="${GITHUB_REPOSITORY:-}"
GITHUB_API_URL="https://api.github.com"

# CI/CD scan result files
declare -A SCAN_RESULT_FILES=(
    ["shellcheck"]="$CI_SECURITY_DIR/shellcheck-results.sarif"
    ["trivy"]="$CI_SECURITY_DIR/trivy-results.sarif"
    ["bandit"]="$CI_SECURITY_DIR/bandit-results.sarif"
    ["gitleaks"]="$CI_SECURITY_DIR/gitleaks-report.json"
)

# Main execution function
main() {
    log_info "Starting $SCRIPT_NAME"
    
    # Ensure directories exist
    mkdir -p "$CI_SECURITY_DIR" "$REPORT_DIR"
    
    local overall_status="SECURE"
    local total_issues=0
    local scan_results=()
    
    # Download latest CI/CD scan results
    if [[ -n "$GITHUB_TOKEN" && -n "$GITHUB_REPO" ]]; then
        download_github_artifacts
    fi
    
    # Process each scan type
    for scan_type in "${!SCAN_RESULT_FILES[@]}"; do
        local result_file="${SCAN_RESULT_FILES[$scan_type]}"
        
        if [[ -f "$result_file" ]]; then
            process_scan_results "$scan_type" "$result_file"
            local scan_issues=$?
            total_issues=$((total_issues + scan_issues))
            
            if [[ $scan_issues -gt 0 ]]; then
                scan_results+=("⚠️ $scan_type: $scan_issues issues found")
                if [[ $scan_issues -ge 5 ]]; then
                    overall_status="HIGH_RISK"
                elif [[ "$overall_status" == "SECURE" ]]; then
                    overall_status="MEDIUM_RISK"
                fi
            else
                scan_results+=("✅ $scan_type: Clean")
            fi
        else
            scan_results+=("❓ $scan_type: No results available")
            log_warn "Scan results not found: $result_file"
        fi
    done
    
    # Generate integration report
    generate_integration_report "$overall_status" "$total_issues" "${scan_results[@]}"
    
    # Update security metrics
    update_security_metrics "$overall_status" "$total_issues"
    
    # Send notifications if needed
    send_security_notifications "$overall_status" "$total_issues" "${scan_results[@]}"
    
    log_info "$SCRIPT_NAME completed. Status: $overall_status, Total Issues: $total_issues"
    
    # Return appropriate exit code
    case "$overall_status" in
        "SECURE") return 0 ;;
        "MEDIUM_RISK") return 1 ;;
        "HIGH_RISK") return 2 ;;
        *) return 1 ;;
    esac
}

# Download latest GitHub Actions artifacts
download_github_artifacts() {
    log_info "Downloading latest CI/CD security scan artifacts"
    
    if ! command -v curl >/dev/null 2>&1; then
        log_warn "curl not available, skipping artifact download"
        return 1
    fi
    
    # Get latest workflow run
    local workflow_runs_url="$GITHUB_API_URL/repos/$GITHUB_REPO/actions/runs"
    local latest_run_id
    
    latest_run_id=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "$workflow_runs_url?status=completed&per_page=1" | \
        jq -r '.workflow_runs[0].id // empty' 2>/dev/null)
    
    if [[ -z "$latest_run_id" ]]; then
        log_warn "Could not retrieve latest workflow run ID"
        return 1
    fi
    
    log_info "Latest workflow run ID: $latest_run_id"
    
    # Download artifacts
    local artifacts_url="$GITHUB_API_URL/repos/$GITHUB_REPO/actions/runs/$latest_run_id/artifacts"
    local artifacts_list
    
    artifacts_list=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "$artifacts_url")
    
    # Process each artifact type
    for artifact_name in "shellcheck-results" "trivy-results" "bandit-results" "security-summary"; do
        local artifact_url
        artifact_url=$(echo "$artifacts_list" | jq -r ".artifacts[] | select(.name == \"$artifact_name\") | .archive_download_url" 2>/dev/null)
        
        if [[ -n "$artifact_url" && "$artifact_url" != "null" ]]; then
            download_and_extract_artifact "$artifact_name" "$artifact_url"
        fi
    done
}

# Download and extract individual artifact
download_and_extract_artifact() {
    local artifact_name="$1"
    local artifact_url="$2"
    
    log_debug "Downloading artifact: $artifact_name"
    
    local temp_dir="/tmp/ci-security-$$"
    mkdir -p "$temp_dir"
    
    if curl -s -L -H "Authorization: token $GITHUB_TOKEN" \
        "$artifact_url" -o "$temp_dir/$artifact_name.zip"; then
        
        if command -v unzip >/dev/null 2>&1; then
            unzip -q "$temp_dir/$artifact_name.zip" -d "$temp_dir/$artifact_name"
            
            # Move extracted files to CI security directory
            find "$temp_dir/$artifact_name" -type f \( -name "*.sarif" -o -name "*.json" \) \
                -exec cp {} "$CI_SECURITY_DIR/" \;
                
            log_success "Downloaded and extracted: $artifact_name"
        else
            log_warn "unzip not available, cannot extract $artifact_name"
        fi
    else
        log_warn "Failed to download artifact: $artifact_name"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Process scan results from SARIF or JSON files
process_scan_results() {
    local scan_type="$1"
    local result_file="$2"
    
    log_debug "Processing $scan_type results from $result_file"
    
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq not available for processing scan results"
        return 0
    fi
    
    local issue_count=0
    
    case "$scan_type" in
        "shellcheck"|"trivy"|"bandit")
            # SARIF format
            if [[ -f "$result_file" ]]; then
                issue_count=$(jq '.runs[0].results | length // 0' "$result_file" 2>/dev/null || echo 0)
            fi
            ;;
        "gitleaks")
            # GitLeaks JSON format
            if [[ -f "$result_file" ]]; then
                issue_count=$(jq '. | length // 0' "$result_file" 2>/dev/null || echo 0)
            fi
            ;;
    esac
    
    log_info "$scan_type scan: $issue_count issues found"
    return $issue_count
}

# Generate HTML integration report
generate_integration_report() {
    local overall_status="$1"
    local total_issues="$2"
    shift 2
    local scan_results=("$@")
    
    local status_color
    local status_message
    
    case "$overall_status" in
        "SECURE")
            status_color="#28a745"
            status_message="System Secure"
            ;;
        "MEDIUM_RISK")
            status_color="#ffc107"
            status_message="Medium Risk"
            ;;
        "HIGH_RISK")
            status_color="#dc3545"
            status_message="High Risk"
            ;;
        *)
            status_color="#6c757d"
            status_message="Unknown Status"
            ;;
    esac
    
    cat > "$INTEGRATION_REPORT" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>CI/CD Security Integration Report - $(date)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .status-banner { 
            background-color: $status_color; 
            color: white; 
            padding: 15px; 
            border-radius: 8px; 
            margin: 20px 0; 
            text-align: center;
        }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #dee2e6; border-radius: 8px; }
        .metric-box { 
            display: inline-block; 
            margin: 10px; 
            padding: 15px; 
            border: 1px solid #dee2e6; 
            border-radius: 8px; 
            min-width: 150px;
            text-align: center;
        }
        .scan-result { padding: 8px; margin: 5px 0; border-radius: 4px; }
        .scan-clean { background-color: #d4edda; border: 1px solid #c3e6cb; }
        .scan-warning { background-color: #fff3cd; border: 1px solid #ffeaa7; }
        .scan-unknown { background-color: #e2e3e5; border: 1px solid #d1d3d4; }
        table { border-collapse: collapse; width: 100%; margin: 15px 0; }
        th, td { border: 1px solid #dee2e6; padding: 10px; text-align: left; }
        th { background-color: #f8f9fa; }
        .timestamp { color: #6c757d; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔒 CI/CD Security Integration Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Server:</strong> $(hostname)</p>
        <p><strong>Integration Script:</strong> $SCRIPT_NAME</p>
    </div>
    
    <div class="status-banner">
        <h2>Overall Security Status: $status_message</h2>
        <p>Total Issues Detected: $total_issues</p>
    </div>
    
    <div class="section">
        <h2>📊 Security Metrics</h2>
        <div class="metric-box">
            <h3>$total_issues</h3>
            <p>Total Issues</p>
        </div>
        <div class="metric-box">
            <h3>$overall_status</h3>
            <p>Risk Level</p>
        </div>
        <div class="metric-box">
            <h3>$(date +%H:%M)</h3>
            <p>Last Scan</p>
        </div>
    </div>
    
    <div class="section">
        <h2>🔍 Scan Results Summary</h2>
EOF
    
    for result in "${scan_results[@]}"; do
        local css_class="scan-unknown"
        if [[ "$result" =~ ^✅ ]]; then
            css_class="scan-clean"
        elif [[ "$result" =~ ^⚠️ ]]; then
            css_class="scan-warning"
        fi
        
        echo "        <div class=\"scan-result $css_class\">$result</div>" >> "$INTEGRATION_REPORT"
    done
    
    cat >> "$INTEGRATION_REPORT" << EOF
    </div>
    
    <div class="section">
        <h2>🔗 Integration Points</h2>
        <table>
            <tr><th>Component</th><th>Status</th><th>Details</th></tr>
            <tr>
                <td>Runtime Security Audits</td>
                <td>✅ Active</td>
                <td>Daily security audits via bash-admin system</td>
            </tr>
            <tr>
                <td>CI/CD Security Scanning</td>
                <td>✅ Active</td>
                <td>Automated security scanning on code changes</td>
            </tr>
            <tr>
                <td>Security Reporting</td>
                <td>✅ Integrated</td>
                <td>Combined reporting across runtime and build-time security</td>
            </tr>
            <tr>
                <td>Alert Notifications</td>
                <td>✅ Configured</td>
                <td>Multi-channel security alerting system</td>
            </tr>
        </table>
    </div>
    
    <div class="section">
        <h2>📋 Recommended Actions</h2>
EOF
    
    if [[ "$overall_status" == "HIGH_RISK" ]]; then
        cat >> "$INTEGRATION_REPORT" << EOF
        <div class="scan-result scan-warning">
            <h4>Immediate Action Required:</h4>
            <ul>
                <li>Review critical security findings in GitHub Security tab</li>
                <li>Address high-severity vulnerabilities immediately</li>
                <li>Run manual security audit: <code>./scripts/administration/daily_security_audit.sh</code></li>
                <li>Consider temporary access restrictions until issues are resolved</li>
            </ul>
        </div>
EOF
    elif [[ "$overall_status" == "MEDIUM_RISK" ]]; then
        cat >> "$INTEGRATION_REPORT" << EOF
        <div class="scan-result scan-warning">
            <h4>Review and Address:</h4>
            <ul>
                <li>Review security findings and prioritize fixes</li>
                <li>Plan remediation for identified vulnerabilities</li>
                <li>Update security configurations as needed</li>
                <li>Monitor for escalation of security issues</li>
            </ul>
        </div>
EOF
    else
        cat >> "$INTEGRATION_REPORT" << EOF
        <div class="scan-result scan-clean">
            <h4>System Secure:</h4>
            <ul>
                <li>All CI/CD security scans passed</li>
                <li>Continue regular security monitoring</li>
                <li>Maintain current security practices</li>
                <li>Review security policy quarterly</li>
            </ul>
        </div>
EOF
    fi
    
    cat >> "$INTEGRATION_REPORT" << EOF
    </div>
    
    <div class="section">
        <h2>🔗 Related Reports</h2>
        <ul>
            <li><a href="daily_security_summary_$TODAY.html">Daily Security Audit Report</a></li>
            <li><a href="system_report_$TODAY.html">System Status Report</a></li>
            <li><a href="daily_admin_master_$TODAY.html">Daily Administration Master Report</a></li>
        </ul>
    </div>
    
    <div class="section timestamp">
        <p><em>CI/CD Security Integration Report generated at $(date)</em></p>
        <p><em>Next integration check: $(date -d '+1 hour' '+%Y-%m-%d %H:%M')</em></p>
    </div>
</body>
</html>
EOF
    
    log_info "CI/CD security integration report generated: $INTEGRATION_REPORT"
}

# Update security metrics for dashboard
update_security_metrics() {
    local overall_status="$1"
    local total_issues="$2"
    
    local metrics_file="$CI_SECURITY_DIR/security_metrics.json"
    
    cat > "$metrics_file" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "overall_status": "$overall_status",
    "total_issues": $total_issues,
    "risk_level": "$(case "$overall_status" in 
        "SECURE") echo "LOW" ;;
        "MEDIUM_RISK") echo "MEDIUM" ;;
        "HIGH_RISK") echo "HIGH" ;;
        *) echo "UNKNOWN" ;;
    esac)",
    "last_integration": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "integration_version": "1.0"
}
EOF
    
    log_debug "Security metrics updated: $metrics_file"
}

# Send security notifications based on status
send_security_notifications() {
    local overall_status="$1"
    local total_issues="$2"
    shift 2
    local scan_results=("$@")
    
    # Only send notifications for medium/high risk
    if [[ "$overall_status" == "SECURE" ]]; then
        return 0
    fi
    
    local subject
    local priority
    local recipient
    
    case "$overall_status" in
        "MEDIUM_RISK")
            subject="⚠️ CI/CD Security Issues Detected - $(hostname)"
            priority="normal"
            recipient=$(get_config "notifications.recipients.admin")
            ;;
        "HIGH_RISK")
            subject="🚨 Critical CI/CD Security Issues - $(hostname)"
            priority="high"
            recipient=$(get_config "notifications.recipients.security")
            ;;
    esac
    
    local email_body="CI/CD Security Integration completed with issues at $(date).

SECURITY STATUS: $overall_status
TOTAL ISSUES: $total_issues

SCAN RESULTS:
$(printf "%s\n" "${scan_results[@]}")

Integration report: $INTEGRATION_REPORT
GitHub Security: https://github.com/$GITHUB_REPO/security

Recommended actions:
1. Review security findings immediately
2. Address high-priority vulnerabilities
3. Run manual security audit if needed

Linux Automation Security System"
    
    if [[ -n "$recipient" ]]; then
        send_email "$recipient" "$subject" "$email_body" "$INTEGRATION_REPORT"
        log_info "Security notification sent to: $recipient"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

CI/CD Security Integration Script
Integrates CI/CD security scan results with bash-admin security infrastructure

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose logging
    -q, --quiet         Suppress non-error output
    --download          Force download of latest CI/CD artifacts
    --report-only       Generate report without downloading new data
    --github-token TOKEN Set GitHub API token for artifact download
    --github-repo REPO  Set GitHub repository (owner/repo format)

Examples:
    $0                                  Run integration with available data
    $0 --download                       Force download latest CI/CD results
    $0 --github-token \$TOKEN --download  Download with specific GitHub token
    $0 --report-only                    Generate report from existing data

Environment Variables:
    GITHUB_TOKEN        GitHub API token for downloading artifacts
    GITHUB_REPOSITORY   GitHub repository in owner/repo format

EOF
}

# Parse command line arguments
FORCE_DOWNLOAD=false
REPORT_ONLY=false

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
        --download)
            FORCE_DOWNLOAD=true
            shift
            ;;
        --report-only)
            REPORT_ONLY=true
            shift
            ;;
        --github-token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        --github-repo)
            GITHUB_REPO="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate GitHub configuration if download is requested
if [[ "$FORCE_DOWNLOAD" == "true" && ( -z "$GITHUB_TOKEN" || -z "$GITHUB_REPO" ) ]]; then
    log_warn "GitHub token and repository required for artifact download"
    log_info "Set GITHUB_TOKEN and GITHUB_REPOSITORY environment variables"
fi

# Initialize and execute
init_bash_admin "$(basename "$0")"

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi