#!/bin/bash
# User Presentation Module  
# Responsible ONLY for formatting and presenting user data
# Follows Presenter Contract - no data gathering or analysis

# ================================
# Presenter Functions
# ================================

# Format user status for display
format_user_status() {
    local user_data="$1"
    local analysis="$2"
    local format="${3:-text}"
    
    case "$format" in
        text)
            format_user_status_text "$user_data" "$analysis"
            ;;
        json)
            format_user_status_json "$user_data" "$analysis"
            ;;
        html)
            format_user_status_html "$user_data" "$analysis"
            ;;
        csv)
            format_user_status_csv "$user_data" "$analysis"
            ;;
        *)
            echo "Error: Unsupported format: $format" >&2
            return 1
            ;;
    esac
}

# Format user status as text
format_user_status_text() {
    local user_data="$1"
    local analysis="$2"
    
    # Parse data
    local username uid gid home shell groups
    username=$(echo "$user_data" | jq -r '.username' 2>/dev/null)
    uid=$(echo "$user_data" | jq -r '.uid' 2>/dev/null)
    gid=$(echo "$user_data" | jq -r '.gid' 2>/dev/null)
    home=$(echo "$user_data" | jq -r '.home' 2>/dev/null)
    shell=$(echo "$user_data" | jq -r '.shell' 2>/dev/null)
    groups=$(echo "$user_data" | jq -r '.groups' 2>/dev/null)
    
    local status risk_level security_flags
    status=$(echo "$analysis" | jq -r '.status' 2>/dev/null)
    risk_level=$(echo "$analysis" | jq -r '.risk_level' 2>/dev/null)
    security_flags=$(echo "$analysis" | jq -r '.security_flags[]?' 2>/dev/null | tr '\n' ' ')
    
    # Format output
    printf "%-15s UID:%-6s GID:%-6s Status:%-10s Risk:%-8s\n" "$username" "$uid" "$gid" "$status" "$risk_level"
    printf "  Home: %s\n" "$home"
    printf "  Shell: %s\n" "$shell"
    printf "  Groups: %s\n" "$groups"
    [[ -n "$security_flags" ]] && printf "  Flags: %s\n" "$security_flags"
}

# Format user status as JSON
format_user_status_json() {
    local user_data="$1"
    local analysis="$2"
    
    # Validate JSON inputs before merging
    if ! echo "$user_data" | jq empty 2>/dev/null; then
        echo "Error: Invalid user_data JSON" >&2
        return 1
    fi
    
    if ! echo "$analysis" | jq empty 2>/dev/null; then
        echo "Error: Invalid analysis JSON" >&2
        return 1
    fi
    
    # Merge user data and analysis
    jq -s '.[0] * .[1]' <(echo "$user_data") <(echo "$analysis") 2>/dev/null || {
        echo "Error: Failed to merge JSON data" >&2
        return 1
    }
}

# Format user status as HTML
format_user_status_html() {
    local user_data="$1"
    local analysis="$2"
    
    # Parse data
    local username uid status risk_level
    username=$(echo "$user_data" | jq -r '.username' 2>/dev/null)
    uid=$(echo "$user_data" | jq -r '.uid' 2>/dev/null)
    status=$(echo "$analysis" | jq -r '.status' 2>/dev/null)
    risk_level=$(echo "$analysis" | jq -r '.risk_level' 2>/dev/null)
    
    # Generate HTML
    cat <<EOF
<div class="user-status">
    <h3>$username (UID: $uid)</h3>
    <p><strong>Status:</strong> <span class="status-$status">$status</span></p>
    <p><strong>Risk Level:</strong> <span class="risk-$risk_level">$risk_level</span></p>
</div>
EOF
}

# Format user status as CSV
format_user_status_csv() {
    local user_data="$1"
    local analysis="$2"
    
    # Parse data
    local username uid gid status risk_level
    username=$(echo "$user_data" | jq -r '.username' 2>/dev/null)
    uid=$(echo "$user_data" | jq -r '.uid' 2>/dev/null)
    gid=$(echo "$user_data" | jq -r '.gid' 2>/dev/null)
    status=$(echo "$analysis" | jq -r '.status' 2>/dev/null)
    risk_level=$(echo "$analysis" | jq -r '.risk_level' 2>/dev/null)
    
    echo "$username,$uid,$gid,$status,$risk_level"
}

# Display user report header
display_report_header() {
    local title="$1"
    local format="${2:-text}"
    
    case "$format" in
        text)
            echo "=================================="
            echo "$title"
            echo "Generated: $(date)"
            echo "=================================="
            echo
            ;;
        html)
            cat <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>$title</title>
    <style>
        .report { font-family: monospace; }
        .status-ACTIVE { color: green; }
        .status-LOCKED { color: orange; }
        .status-EXPIRED { color: red; }
        .risk-LOW { color: green; }
        .risk-MEDIUM { color: orange; }
        .risk-HIGH { color: red; }
        .risk-CRITICAL { color: darkred; font-weight: bold; }
    </style>
</head>
<body>
    <div class="report">
        <h1>$title</h1>
        <p>Generated: $(date)</p>
EOF
            ;;
        csv)
            echo "# $title"
            echo "# Generated: $(date)"
            echo "Username,UID,GID,Status,Risk Level"
            ;;
    esac
}

# Display report footer
display_report_footer() {
    local format="${1:-text}"
    
    case "$format" in
        text)
            echo
            echo "=================================="
            echo "End of Report"
            echo "=================================="
            ;;
        html)
            cat <<EOF
    </div>
</body>
</html>
EOF
            ;;
        csv)
            echo "# End of Report"
            ;;
    esac
}

# Present summary statistics
present_summary_statistics() {
    local stats_json="$1"
    local format="${2:-text}"
    
    # Parse statistics
    local total active locked expired privileged
    total=$(echo "$stats_json" | jq -r '.total' 2>/dev/null)
    active=$(echo "$stats_json" | jq -r '.active' 2>/dev/null)
    locked=$(echo "$stats_json" | jq -r '.locked' 2>/dev/null)
    expired=$(echo "$stats_json" | jq -r '.expired' 2>/dev/null)
    privileged=$(echo "$stats_json" | jq -r '.privileged' 2>/dev/null)
    
    case "$format" in
        text)
            echo "SUMMARY STATISTICS:"
            echo "  Total Users: $total"
            echo "  Active: $active"
            echo "  Locked: $locked"
            echo "  Expired: $expired"
            echo "  Privileged: $privileged"
            ;;
        json)
            echo "$stats_json"
            ;;
        html)
            cat <<EOF
<div class="summary">
    <h2>Summary Statistics</h2>
    <ul>
        <li>Total Users: $total</li>
        <li>Active: $active</li>
        <li>Locked: $locked</li>
        <li>Expired: $expired</li>
        <li>Privileged: $privileged</li>
    </ul>
</div>
EOF
            ;;
    esac
}

# Format security score display
format_security_score() {
    local score_json="$1"
    local format="${2:-text}"
    
    # Parse score data
    local score grade deductions
    score=$(echo "$score_json" | jq -r '.score' 2>/dev/null)
    grade=$(echo "$score_json" | jq -r '.grade' 2>/dev/null)
    deductions=$(echo "$score_json" | jq -r '.deductions[]?' 2>/dev/null)
    
    case "$format" in
        text)
            echo "Security Score: $score/100 (Grade: $grade)"
            if [[ -n "$deductions" ]]; then
                echo "Deductions:"
                echo "$deductions" | sed 's/^/  - /'
            fi
            ;;
        json)
            echo "$score_json"
            ;;
        html)
            cat <<EOF
<div class="security-score">
    <h3>Security Score: $score/100 (Grade: $grade)</h3>
    $(if [[ -n "$deductions" ]]; then
        echo "<h4>Deductions:</h4><ul>"
        echo "$deductions" | while read -r d; do
            echo "<li>$d</li>"
        done
        echo "</ul>"
    fi)
</div>
EOF
            ;;
    esac
}

# Display colored output helpers
display_colored_status() {
    local status="$1"
    local use_colors="${2:-auto}"
    
    # Auto-detect terminal color support
    if [[ "$use_colors" == "auto" ]]; then
        if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
            if [[ $(tput colors 2>/dev/null) -ge 8 ]]; then
                use_colors="true"
            else
                use_colors="false"
            fi
        else
            use_colors="false"
        fi
    fi
    
    if [[ "$use_colors" == "false" ]]; then
        echo "$status"
        return
    fi
    
    case "$status" in
        ACTIVE)
            echo -e "\033[32m$status\033[0m"  # Green
            ;;
        LOCKED)
            echo -e "\033[33m$status\033[0m"  # Yellow
            ;;
        EXPIRED|DISABLED)
            echo -e "\033[31m$status\033[0m"  # Red
            ;;
        *)
            echo "$status"
            ;;
    esac
}

display_colored_risk() {
    local risk="$1"
    local use_colors="${2:-auto}"
    
    # Auto-detect terminal color support
    if [[ "$use_colors" == "auto" ]]; then
        if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
            if [[ $(tput colors 2>/dev/null) -ge 8 ]]; then
                use_colors="true"
            else
                use_colors="false"
            fi
        else
            use_colors="false"
        fi
    fi
    
    if [[ "$use_colors" == "false" ]]; then
        echo "$risk"
        return
    fi
    
    case "$risk" in
        LOW)
            echo -e "\033[32m$risk\033[0m"  # Green
            ;;
        MEDIUM)
            echo -e "\033[33m$risk\033[0m"  # Yellow
            ;;
        HIGH)
            echo -e "\033[91m$risk\033[0m"  # Light Red
            ;;
        CRITICAL)
            echo -e "\033[31;1m$risk\033[0m"  # Bold Red
            ;;
        *)
            echo "$risk"
            ;;
    esac
}

# Present compliance report
present_compliance_report() {
    local compliance_json="$1"
    local format="${2:-text}"
    
    local compliant violations
    compliant=$(echo "$compliance_json" | jq -r '.compliant' 2>/dev/null)
    violations=$(echo "$compliance_json" | jq -r '.violations[]?' 2>/dev/null)
    
    case "$format" in
        text)
            if [[ "$compliant" == "true" ]]; then
                echo "✓ Policy Compliant"
            else
                echo "✗ Policy Violations Found:"
                echo "$violations" | sed 's/^/  - /'
            fi
            ;;
        json)
            echo "$compliance_json"
            ;;
        html)
            if [[ "$compliant" == "true" ]]; then
                echo "<p class='compliant'>✓ Policy Compliant</p>"
            else
                echo "<div class='violations'>"
                echo "<p>✗ Policy Violations Found:</p>"
                echo "<ul>"
                echo "$violations" | while read -r v; do
                    echo "<li>$v</li>"
                done
                echo "</ul>"
                echo "</div>"
            fi
            ;;
    esac
}