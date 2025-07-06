#!/bin/bash
# User Management Module
# Provides functions for user account auditing and security analysis

# Source core libraries
source "$(dirname "$0")/../../core/lib/init.sh"

# Get comprehensive user account status
get_user_account_status() {
    local report_file="${1:-/tmp/user_accounts_$(date +%Y%m%d).txt}"
    
    log_info "Analyzing user account status"
    
    # Initialize counters
    local total_users=0
    local active_users=0
    local locked_users=0
    local expired_users=0
    local system_users=0
    local privileged_users=0
    
    # Get excluded users from config
    local excluded_users
    excluded_users=$(get_config 'modules.user_management.excluded_users' '["root", "daemon", "bin", "sys", "nobody"]' | jq -r '.[]' 2>/dev/null || echo -e "root\ndaemon\nbin\nsys\nnobody")
    
    {
        echo "User Account Status Report - $(date)"
        echo "=================================="
        echo
        echo "ACCOUNT ANALYSIS:"
        echo
        
        # Analyze each user account
        while IFS=: read -r username _ uid gid _ home shell; do
            ((total_users++))
            
            # Skip excluded system users
            if echo "$excluded_users" | grep -q "^$username$"; then
                ((system_users++))
                continue
            fi
            
            # Check if account is locked
            local passwd_status
            passwd_status=$(passwd -S "$username" 2>/dev/null | awk '{print $2}' || echo "unknown")
            
            # Check password aging from /etc/shadow
            local shadow_info
            shadow_info=$(getent shadow "$username" 2>/dev/null || echo "$username:*:::::::")
            local last_change=$(echo "$shadow_info" | cut -d: -f3)
            local min_age=$(echo "$shadow_info" | cut -d: -f4)
            local max_age=$(echo "$shadow_info" | cut -d: -f5)
            local warn_period=$(echo "$shadow_info" | cut -d: -f6)
            local expire_date=$(echo "$shadow_info" | cut -d: -f8)
            
            # Determine account status
            local status="ACTIVE"
            local security_notes=""
            
            if [[ "$passwd_status" == "L" || "$passwd_status" == "LK" ]]; then
                status="LOCKED"
                ((locked_users++))
            elif [[ -n "$expire_date" && "$expire_date" != "" ]]; then
                local current_days=$(($(date +%s) / 86400))
                if [[ "$expire_date" -lt "$current_days" ]]; then
                    status="EXPIRED"
                    ((expired_users++))
                fi
            else
                ((active_users++))
            fi
            
            # Check for privileged access
            if groups "$username" 2>/dev/null | grep -qE "(sudo|wheel|admin|root)"; then
                ((privileged_users++))
                security_notes="$security_notes [PRIVILEGED]"
            fi
            
            # Check for empty password
            if echo "$shadow_info" | cut -d: -f2 | grep -q "^$"; then
                security_notes="$security_notes [EMPTY_PASSWORD]"
            fi
            
            # Check for non-standard shell
            if [[ "$shell" != "/bin/bash" && "$shell" != "/bin/sh" && "$shell" != "/usr/bin/bash" && "$shell" != "/sbin/nologin" && "$shell" != "/bin/false" ]]; then
                security_notes="$security_notes [CUSTOM_SHELL:$shell]"
            fi
            
            # Output user information
            printf "  %-15s UID:%-6s Status:%-8s Shell:%-15s %s\n" "$username" "$uid" "$status" "$shell" "$security_notes"
            
        done < /etc/passwd
        
        echo
        echo "SUMMARY STATISTICS:"
        echo "  Total Users: $total_users"
        echo "  Active Users: $active_users"
        echo "  Locked Users: $locked_users"
        echo "  Expired Users: $expired_users"
        echo "  System Users (excluded): $system_users"
        echo "  Privileged Users: $privileged_users"
        echo
        
    } > "$report_file"
    
    log_info "User account analysis saved to: $report_file"
    return 0
}

# Check password policy compliance
check_password_policies() {
    local report_file="${1:-/tmp/password_policies_$(date +%Y%m%d).txt}"
    
    log_info "Checking password policy compliance"
    
    # Get policy settings from config
    local min_length=$(get_config 'modules.user_management.password_policy.min_length' '8')
    local max_age=$(get_config 'modules.user_management.password_policy.max_age_days' '90')
    local require_complexity=$(get_config 'modules.user_management.password_policy.require_complexity' 'true')
    
    local policy_violations=0
    local accounts_checked=0
    
    {
        echo "Password Policy Compliance Report - $(date)"
        echo "=========================================="
        echo
        echo "POLICY SETTINGS:"
        echo "  Minimum Length: $min_length characters"
        echo "  Maximum Age: $max_age days"
        echo "  Complexity Required: $require_complexity"
        echo
        echo "COMPLIANCE ANALYSIS:"
        echo
        
        # Check each user's password status
        while IFS=: read -r username _ uid gid _ home shell; do
            # Skip system users
            if [[ "$uid" -lt 1000 || "$shell" == "/sbin/nologin" || "$shell" == "/bin/false" ]]; then
                continue
            fi
            
            ((accounts_checked++))
            
            # Get shadow entry
            local shadow_info
            shadow_info=$(getent shadow "$username" 2>/dev/null || echo "$username:*:::::::")
            local password_hash=$(echo "$shadow_info" | cut -d: -f2)
            local last_change=$(echo "$shadow_info" | cut -d: -f3)
            local max_age_shadow=$(echo "$shadow_info" | cut -d: -f5)
            
            local violations=""
            
            # Check for empty password
            if [[ -z "$password_hash" || "$password_hash" == "" ]]; then
                violations="$violations EMPTY_PASSWORD"
                ((policy_violations++))
            fi
            
            # Check password age
            if [[ -n "$last_change" && "$last_change" != "" ]]; then
                local current_days=$(($(date +%s) / 86400))
                local password_age=$((current_days - last_change))
                
                if [[ "$password_age" -gt "$max_age" ]]; then
                    violations="$violations PASSWORD_EXPIRED($password_age days)"
                    ((policy_violations++))
                fi
            fi
            
            # Check if password aging is set
            if [[ -z "$max_age_shadow" || "$max_age_shadow" == "" || "$max_age_shadow" == "99999" ]]; then
                violations="$violations NO_AGING_POLICY"
            fi
            
            # Output results
            if [[ -n "$violations" ]]; then
                printf "  ❌ %-15s %s\n" "$username" "$violations"
            else
                printf "  ✅ %-15s COMPLIANT\n" "$username"
            fi
            
        done < /etc/passwd
        
        echo
        echo "POLICY COMPLIANCE SUMMARY:"
        echo "  Accounts Checked: $accounts_checked"
        echo "  Policy Violations: $policy_violations"
        
        if [[ "$policy_violations" -gt 0 ]]; then
            echo "  Status: ❌ NON-COMPLIANT"
        else
            echo "  Status: ✅ COMPLIANT"
        fi
        echo
        
    } > "$report_file"
    
    log_info "Password policy analysis saved to: $report_file"
    
    if [[ "$policy_violations" -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Monitor failed login attempts
monitor_failed_logins() {
    local report_file="${1:-/tmp/failed_logins_$(date +%Y%m%d).txt}"
    local threshold="${2:-$(get_config 'modules.user_management.failed_login_threshold' '10')}"
    
    log_info "Monitoring failed login attempts"
    
    local auth_logs=()
    
    # Find available auth log files
    if [[ -f "/var/log/auth.log" ]]; then
        auth_logs+=("/var/log/auth.log")
    fi
    if [[ -f "/var/log/secure" ]]; then
        auth_logs+=("/var/log/secure")
    fi
    if [[ -f "/var/log/messages" ]]; then
        auth_logs+=("/var/log/messages")
    fi
    
    if [[ "${#auth_logs[@]}" -eq 0 ]]; then
        echo "No authentication logs found" > "$report_file"
        log_warn "No authentication logs found for failed login analysis"
        return 1
    fi
    
    {
        echo "Failed Login Monitoring Report - $(date)"
        echo "======================================"
        echo
        echo "ANALYSIS SETTINGS:"
        echo "  Threshold: $threshold failed attempts"
        echo "  Log Sources: ${auth_logs[*]}"
        echo
        echo "FAILED LOGIN ATTEMPTS (Last 24 Hours):"
        echo
        
        # Analyze failed logins from the last 24 hours
        local yesterday=$(date -d "yesterday" +"%b %d" 2>/dev/null || date -v-1d +"%b %d" 2>/dev/null || echo "")
        local today=$(date +"%b %d")
        
        local failed_attempts
        failed_attempts=$(
            for log_file in "${auth_logs[@]}"; do
                if [[ -r "$log_file" ]]; then
                    # Look for common failed login patterns
                    grep -E "($yesterday|$today)" "$log_file" 2>/dev/null | \
                    grep -iE "(failed|failure|invalid|authentication error)" | \
                    grep -vE "(sudo|su:|cron)" || true
                fi
            done | sort | uniq -c | sort -nr
        )
        
        if [[ -n "$failed_attempts" ]]; then
            echo "$failed_attempts"
            echo
            
            # Count unique users with failed attempts
            local users_with_failures
            users_with_failures=$(echo "$failed_attempts" | wc -l)
            
            # Check if any user exceeds threshold
            local high_failure_users
            high_failure_users=$(echo "$failed_attempts" | awk -v threshold="$threshold" '$1 >= threshold')
            
            echo "SUMMARY:"
            echo "  Users with Failed Attempts: $users_with_failures"
            
            if [[ -n "$high_failure_users" ]]; then
                echo "  ❌ Users Exceeding Threshold ($threshold):"
                echo "$high_failure_users" | while read -r count line; do
                    echo "    $line ($count attempts)"
                done
            else
                echo "  ✅ No users exceed failure threshold"
            fi
        else
            echo "  ✅ No failed login attempts detected in the last 24 hours"
        fi
        echo
        
    } > "$report_file"
    
    log_info "Failed login analysis saved to: $report_file"
    
    # Return non-zero if there are users exceeding threshold
    if [[ -n "$high_failure_users" ]]; then
        return 1
    fi
    return 0
}

# Check for inactive users
check_inactive_users() {
    local report_file="${1:-/tmp/inactive_users_$(date +%Y%m%d).txt}"
    local inactive_days="${2:-$(get_config 'modules.user_management.inactive_user_days' '90')}"
    
    log_info "Checking for inactive user accounts"
    
    local inactive_count=0
    local total_checked=0
    
    {
        echo "Inactive User Analysis Report - $(date)"
        echo "====================================="
        echo
        echo "ANALYSIS SETTINGS:"
        echo "  Inactive Threshold: $inactive_days days"
        echo
        echo "INACTIVE USER ACCOUNTS:"
        echo
        
        # Check each regular user account
        while IFS=: read -r username _ uid gid _ home shell; do
            # Skip system users
            if [[ "$uid" -lt 1000 || "$shell" == "/sbin/nologin" || "$shell" == "/bin/false" ]]; then
                continue
            fi
            
            ((total_checked++))
            
            # Check last login time
            local last_login=""
            local days_since_login=""
            
            # Try to get last login from lastlog
            if command -v lastlog >/dev/null 2>&1; then
                last_login=$(lastlog -u "$username" 2>/dev/null | tail -1 | awk '{print $4, $5, $6, $7}')
            fi
            
            # Try alternative methods if lastlog didn't work
            if [[ -z "$last_login" || "$last_login" == "Never logged in" ]]; then
                # Check wtmp with last command
                last_login=$(last -1 "$username" 2>/dev/null | head -1 | awk '{print $4, $5, $6, $7}')
            fi
            
            # Calculate days since last login
            if [[ -n "$last_login" && "$last_login" != "Never logged in" && "$last_login" != "wtmp begins" ]]; then
                local login_timestamp
                login_timestamp=$(date -d "$last_login" +%s 2>/dev/null || echo "0")
                if [[ "$login_timestamp" -gt 0 ]]; then
                    local current_timestamp=$(date +%s)
                    days_since_login=$(( (current_timestamp - login_timestamp) / 86400 ))
                fi
            fi
            
            # Check if user is inactive
            if [[ -z "$days_since_login" ]]; then
                printf "  ⚠️  %-15s Never logged in or login data unavailable\n" "$username"
                ((inactive_count++))
            elif [[ "$days_since_login" -gt "$inactive_days" ]]; then
                printf "  ❌ %-15s Last login: %s (%d days ago)\n" "$username" "$last_login" "$days_since_login"
                ((inactive_count++))
            else
                printf "  ✅ %-15s Last login: %s (%d days ago)\n" "$username" "$last_login" "$days_since_login"
            fi
            
        done < /etc/passwd
        
        echo
        echo "INACTIVE USER SUMMARY:"
        echo "  Total Users Checked: $total_checked"
        echo "  Inactive Users: $inactive_count"
        echo "  Inactive Threshold: $inactive_days days"
        
        if [[ "$inactive_count" -gt 0 ]]; then
            echo "  Status: ❌ INACTIVE ACCOUNTS DETECTED"
            echo
            echo "RECOMMENDATIONS:"
            echo "  1. Review inactive accounts for necessity"
            echo "  2. Consider disabling unused accounts"
            echo "  3. Verify account owners are still with organization"
            echo "  4. Update account access policies"
        else
            echo "  Status: ✅ ALL ACCOUNTS ACTIVE"
        fi
        echo
        
    } > "$report_file"
    
    log_info "Inactive user analysis saved to: $report_file"
    
    if [[ "$inactive_count" -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Audit user permissions and privileged access
audit_user_permissions() {
    local report_file="${1:-/tmp/user_permissions_$(date +%Y%m%d).txt}"
    
    log_info "Auditing user permissions and privileged access"
    
    local security_issues=0
    
    {
        echo "User Permissions Audit Report - $(date)"
        echo "======================================"
        echo
        echo "PRIVILEGED ACCESS ANALYSIS:"
        echo
        
        # Check sudo access
        echo "SUDO ACCESS:"
        if [[ -f "/etc/sudoers" ]] && command -v sudo >/dev/null 2>&1; then
            # Get sudo users from sudoers file and sudo group
            local sudo_users=()
            
            # Check sudo group members
            if getent group sudo >/dev/null 2>&1; then
                local sudo_group_members
                sudo_group_members=$(getent group sudo | cut -d: -f4 | tr ',' '\n')
                if [[ -n "$sudo_group_members" ]]; then
                    while read -r user; do
                        [[ -n "$user" ]] && sudo_users+=("$user")
                    done <<< "$sudo_group_members"
                fi
            fi
            
            # Check wheel group members (common on RHEL/CentOS)
            if getent group wheel >/dev/null 2>&1; then
                local wheel_group_members
                wheel_group_members=$(getent group wheel | cut -d: -f4 | tr ',' '\n')
                if [[ -n "$wheel_group_members" ]]; then
                    while read -r user; do
                        [[ -n "$user" ]] && sudo_users+=("$user")
                    done <<< "$wheel_group_members"
                fi
            fi
            
            # Remove duplicates and display
            if [[ "${#sudo_users[@]}" -gt 0 ]]; then
                printf '%s\n' "${sudo_users[@]}" | sort -u | while read -r user; do
                    printf "  ✓ %s (sudo access)\n" "$user"
                done
            else
                echo "  No users with sudo access found"
            fi
        else
            echo "  Sudo not available or accessible"
        fi
        echo
        
        # Check admin group memberships
        echo "ADMINISTRATIVE GROUP MEMBERSHIPS:"
        local admin_groups=("root" "admin" "wheel" "sudo" "adm" "staff")
        
        for group in "${admin_groups[@]}"; do
            if getent group "$group" >/dev/null 2>&1; then
                local group_members
                group_members=$(getent group "$group" | cut -d: -f4)
                if [[ -n "$group_members" ]]; then
                    echo "  Group '$group': $group_members"
                else
                    echo "  Group '$group': (empty)"
                fi
            fi
        done
        echo
        
        # Check for users with UID 0 (root privileges)
        echo "ROOT PRIVILEGE ANALYSIS (UID 0):"
        local root_users
        root_users=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
        if [[ -n "$root_users" ]]; then
            echo "$root_users" | while read -r user; do
                if [[ "$user" == "root" ]]; then
                    echo "  ✓ $user (standard root account)"
                else
                    echo "  ⚠️  $user (additional root-privileged account)"
                    ((security_issues++))
                fi
            done
        fi
        echo
        
        # Check for duplicate UIDs
        echo "DUPLICATE UID ANALYSIS:"
        local duplicate_uids
        duplicate_uids=$(awk -F: '{print $3}' /etc/passwd | sort | uniq -d)
        if [[ -n "$duplicate_uids" ]]; then
            echo "$duplicate_uids" | while read -r uid; do
                echo "  ⚠️  UID $uid is used by multiple accounts:"
                awk -F: -v uid="$uid" '$3 == uid {print "    " $1}' /etc/passwd
                ((security_issues++))
            done
        else
            echo "  ✅ No duplicate UIDs found"
        fi
        echo
        
        # Check home directory permissions
        echo "HOME DIRECTORY PERMISSIONS:"
        local home_issues=0
        while IFS=: read -r username _ uid gid _ home shell; do
            # Skip system users
            if [[ "$uid" -lt 1000 || "$shell" == "/sbin/nologin" || "$shell" == "/bin/false" ]]; then
                continue
            fi
            
            if [[ -d "$home" ]]; then
                local perms
                perms=$(stat -c "%a" "$home" 2>/dev/null || stat -f "%A" "$home" 2>/dev/null || echo "unknown")
                local owner
                owner=$(stat -c "%U" "$home" 2>/dev/null || stat -f "%Su" "$home" 2>/dev/null || echo "unknown")
                
                if [[ "$owner" != "$username" ]]; then
                    echo "  ⚠️  $home: owned by $owner (should be $username)"
                    ((home_issues++))
                elif [[ "$perms" =~ [0-9][0-9][0-9] ]]; then
                    local others_perm=${perms: -1}
                    if [[ "$others_perm" -gt 0 ]]; then
                        echo "  ⚠️  $home: permissions $perms (world accessible)"
                        ((home_issues++))
                    else
                        echo "  ✅ $home: permissions $perms (secure)"
                    fi
                else
                    echo "  ⚠️  $home: permissions $perms (unknown format)"
                    ((home_issues++))
                fi
            else
                echo "  ⚠️  $home: directory does not exist for user $username"
                ((home_issues++))
            fi
        done < /etc/passwd
        
        if [[ "$home_issues" -eq 0 ]]; then
            echo "  ✅ All home directories have appropriate permissions"
        fi
        echo
        
        echo "SECURITY SUMMARY:"
        echo "  Security Issues Found: $((security_issues + home_issues))"
        
        if [[ "$((security_issues + home_issues))" -gt 0 ]]; then
            echo "  Status: ❌ SECURITY ISSUES DETECTED"
            echo
            echo "RECOMMENDATIONS:"
            echo "  1. Review all accounts with elevated privileges"
            echo "  2. Remove unnecessary administrative access"
            echo "  3. Fix duplicate UID issues"
            echo "  4. Correct home directory ownership and permissions"
            echo "  5. Implement principle of least privilege"
        else
            echo "  Status: ✅ PERMISSIONS SECURE"
        fi
        echo
        
    } > "$report_file"
    
    log_info "User permissions audit saved to: $report_file"
    
    if [[ "$((security_issues + home_issues))" -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Generate user management recommendations
generate_user_recommendations() {
    local report_file="${1:-/tmp/user_recommendations_$(date +%Y%m%d).txt}"
    
    log_info "Generating user management recommendations"
    
    {
        echo "User Management Recommendations - $(date)"
        echo "========================================"
        echo
        echo "SECURITY RECOMMENDATIONS:"
        echo
        echo "1. PASSWORD SECURITY:"
        echo "   • Enforce strong password policies (minimum 12+ characters)"
        echo "   • Require password complexity (uppercase, lowercase, numbers, symbols)"
        echo "   • Set maximum password age (90 days recommended)"
        echo "   • Enable password history to prevent reuse"
        echo "   • Consider implementing multi-factor authentication"
        echo
        echo "2. ACCOUNT MANAGEMENT:"
        echo "   • Regularly review and disable inactive accounts"
        echo "   • Remove accounts for users who have left the organization"
        echo "   • Implement account lockout policies for failed login attempts"
        echo "   • Set account expiration dates for temporary users"
        echo "   • Monitor privileged account usage"
        echo
        echo "3. ACCESS CONTROL:"
        echo "   • Apply principle of least privilege"
        echo "   • Regularly audit sudo and administrative group memberships"
        echo "   • Remove unnecessary elevated permissions"
        echo "   • Use role-based access control where possible"
        echo "   • Implement proper group management"
        echo
        echo "4. MONITORING & AUDITING:"
        echo "   • Monitor failed login attempts"
        echo "   • Log and review privileged command execution"
        echo "   • Implement user activity monitoring"
        echo "   • Regular security audits of user accounts"
        echo "   • Alert on suspicious account activity"
        echo
        echo "5. COMPLIANCE:"
        echo "   • Ensure compliance with organizational security policies"
        echo "   • Document user access and changes"
        echo "   • Implement approval processes for privileged access"
        echo "   • Regular access reviews and certifications"
        echo "   • Maintain audit trails for compliance requirements"
        echo
        
        # Add system-specific recommendations based on current state
        echo "SYSTEM-SPECIFIC RECOMMENDATIONS:"
        echo
        
        # Check if there are inactive users
        local inactive_users
        inactive_users=$(find /home -maxdepth 1 -type d -not -name "." -exec sh -c 'last -1 $(basename "$1") 2>/dev/null | grep -q "Never logged in\|wtmp begins" && echo "$(basename "$1")"' _ {} \; 2>/dev/null | wc -l)
        
        if [[ "$inactive_users" -gt 0 ]]; then
            echo "• Review $inactive_users potentially inactive user accounts"
        fi
        
        # Check for users without password aging
        local no_aging_count
        no_aging_count=$(awk -F: '$5 == "" || $5 == "99999" {print $1}' /etc/shadow 2>/dev/null | wc -l)
        
        if [[ "$no_aging_count" -gt 0 ]]; then
            echo "• Configure password aging for $no_aging_count accounts"
        fi
        
        # Check for admin group size
        local admin_count=0
        for group in sudo wheel admin; do
            if getent group "$group" >/dev/null 2>&1; then
                local group_size
                group_size=$(getent group "$group" | cut -d: -f4 | tr ',' '\n' | grep -v '^$' | wc -l)
                admin_count=$((admin_count + group_size))
            fi
        done
        
        if [[ "$admin_count" -gt 5 ]]; then
            echo "• Review $admin_count users with administrative privileges"
        fi
        
        echo
        echo "IMPLEMENTATION PRIORITY:"
        echo "1. HIGH: Address any accounts with empty passwords"
        echo "2. HIGH: Fix duplicate UIDs and security violations"
        echo "3. MEDIUM: Configure password aging policies"
        echo "4. MEDIUM: Review and clean up inactive accounts"
        echo "5. LOW: Optimize group memberships and permissions"
        echo
        
    } > "$report_file"
    
    log_info "User management recommendations saved to: $report_file"
    return 0
}

# Generate comprehensive user management HTML report
generate_user_report() {
    local report_file="${1:-/var/log/bash-admin/daily-reports/user_management_$(date +%Y%m%d).html}"
    local temp_dir="/tmp/user_reports_$(date +%Y%m%d_%H%M%S)"
    
    log_info "Generating comprehensive user management report"
    
    # Create temporary directory for individual reports
    mkdir -p "$temp_dir"
    mkdir -p "$(dirname "$report_file")"
    
    # Generate individual reports
    get_user_account_status "$temp_dir/accounts.txt"
    local accounts_status=$?
    
    check_password_policies "$temp_dir/passwords.txt"
    local password_status=$?
    
    monitor_failed_logins "$temp_dir/logins.txt"
    local login_status=$?
    
    check_inactive_users "$temp_dir/inactive.txt"
    local inactive_status=$?
    
    audit_user_permissions "$temp_dir/permissions.txt"
    local permissions_status=$?
    
    generate_user_recommendations "$temp_dir/recommendations.txt"
    
    # Calculate overall status
    local overall_status="success"
    local status_message="All Clear"
    local issues_found=0
    
    if [[ $accounts_status -ne 0 || $password_status -ne 0 || $login_status -ne 0 || $inactive_status -ne 0 || $permissions_status -ne 0 ]]; then
        overall_status="warning"
        status_message="Issues Detected"
        issues_found=1
    fi
    
    # Generate HTML report
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>User Management Report - $(date)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .header h1 { margin: 0; font-size: 28px; }
        .header p { margin: 5px 0; opacity: 0.9; }
        .status-banner { padding: 15px; border-radius: 5px; margin: 20px 0; text-align: center; font-weight: bold; font-size: 18px; }
        .status-success { background-color: #d4edda; color: #155724; border: 2px solid #c3e6cb; }
        .status-warning { background-color: #fff3cd; color: #856404; border: 2px solid #ffeaa7; }
        .status-danger { background-color: #f8d7da; color: #721c24; border: 2px solid #f5c6cb; }
        .section { margin: 20px 0; padding: 20px; border: 1px solid #ddd; border-radius: 5px; background-color: #fafafa; }
        .section h2 { color: #333; border-bottom: 2px solid #667eea; padding-bottom: 10px; }
        .metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .metric-card { background: white; padding: 15px; border-radius: 5px; border-left: 4px solid #667eea; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric-value { font-size: 24px; font-weight: bold; color: #667eea; }
        .metric-label { color: #666; font-size: 14px; }
        .report-section { background: white; padding: 15px; border-radius: 5px; margin: 10px 0; border: 1px solid #eee; }
        .report-content { font-family: 'Courier New', monospace; font-size: 12px; white-space: pre-wrap; background-color: #f8f9fa; padding: 15px; border-radius: 3px; overflow-x: auto; max-height: 400px; overflow-y: auto; }
        .success { color: #28a745; }
        .warning { color: #ffc107; }
        .danger { color: #dc3545; }
        .info { color: #17a2b8; }
        .footer { text-align: center; margin-top: 30px; padding: 20px; color: #666; border-top: 1px solid #ddd; }
        .recommendations { background-color: #e7f3ff; border-left: 4px solid #17a2b8; }
        .nav-tabs { display: flex; border-bottom: 2px solid #ddd; margin-bottom: 20px; }
        .nav-tab { padding: 10px 20px; background: #f8f9fa; border: 1px solid #ddd; border-bottom: none; cursor: pointer; margin-right: 2px; }
        .nav-tab.active { background: white; border-bottom: 2px solid white; margin-bottom: -2px; }
        .tab-content { display: none; }
        .tab-content.active { display: block; }
    </style>
    <script>
        function showTab(tabName) {
            // Hide all tab contents
            var contents = document.getElementsByClassName('tab-content');
            for (var i = 0; i < contents.length; i++) {
                contents[i].classList.remove('active');
            }
            
            // Remove active class from all tabs
            var tabs = document.getElementsByClassName('nav-tab');
            for (var i = 0; i < tabs.length; i++) {
                tabs[i].classList.remove('active');
            }
            
            // Show selected tab content and mark tab as active
            document.getElementById(tabName).classList.add('active');
            event.target.classList.add('active');
        }
    </script>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔐 User Management Report</h1>
            <p><strong>Generated:</strong> $(date)</p>
            <p><strong>Server:</strong> $(hostname)</p>
            <p><strong>Report Period:</strong> Last 24 Hours</p>
        </div>

        <div class="status-banner status-$overall_status">
            User Management Status: $status_message
        </div>

        <div class="section">
            <h2>📊 Overview Metrics</h2>
            <div class="metrics-grid">
EOF

    # Extract metrics from reports
    local total_users=$(grep "Total Users:" "$temp_dir/accounts.txt" | awk '{print $3}' || echo "0")
    local active_users=$(grep "Active Users:" "$temp_dir/accounts.txt" | awk '{print $3}' || echo "0")
    local privileged_users=$(grep "Privileged Users:" "$temp_dir/accounts.txt" | awk '{print $3}' || echo "0")
    local inactive_users=$(grep "Inactive Users:" "$temp_dir/inactive.txt" | awk '{print $3}' || echo "0")
    local policy_violations=$(grep "Policy Violations:" "$temp_dir/passwords.txt" | awk '{print $3}' || echo "0")

    cat >> "$report_file" << EOF
                <div class="metric-card">
                    <div class="metric-value">$total_users</div>
                    <div class="metric-label">Total User Accounts</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">$active_users</div>
                    <div class="metric-label">Active Users</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">$privileged_users</div>
                    <div class="metric-label">Privileged Users</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">$inactive_users</div>
                    <div class="metric-label">Inactive Users</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">$policy_violations</div>
                    <div class="metric-label">Policy Violations</div>
                </div>
            </div>
        </div>

        <div class="section">
            <h2>📋 Detailed Reports</h2>
            <div class="nav-tabs">
                <div class="nav-tab active" onclick="showTab('accounts-tab')">Account Status</div>
                <div class="nav-tab" onclick="showTab('passwords-tab')">Password Policies</div>
                <div class="nav-tab" onclick="showTab('logins-tab')">Failed Logins</div>
                <div class="nav-tab" onclick="showTab('inactive-tab')">Inactive Users</div>
                <div class="nav-tab" onclick="showTab('permissions-tab')">Permissions Audit</div>
                <div class="nav-tab" onclick="showTab('recommendations-tab')">Recommendations</div>
            </div>

            <div id="accounts-tab" class="tab-content active">
                <div class="report-section">
                    <h3>User Account Status Analysis</h3>
                    <div class="report-content">$(cat "$temp_dir/accounts.txt")</div>
                </div>
            </div>

            <div id="passwords-tab" class="tab-content">
                <div class="report-section">
                    <h3>Password Policy Compliance</h3>
                    <div class="report-content">$(cat "$temp_dir/passwords.txt")</div>
                </div>
            </div>

            <div id="logins-tab" class="tab-content">
                <div class="report-section">
                    <h3>Failed Login Monitoring</h3>
                    <div class="report-content">$(cat "$temp_dir/logins.txt")</div>
                </div>
            </div>

            <div id="inactive-tab" class="tab-content">
                <div class="report-section">
                    <h3>Inactive User Analysis</h3>
                    <div class="report-content">$(cat "$temp_dir/inactive.txt")</div>
                </div>
            </div>

            <div id="permissions-tab" class="tab-content">
                <div class="report-section">
                    <h3>User Permissions Audit</h3>
                    <div class="report-content">$(cat "$temp_dir/permissions.txt")</div>
                </div>
            </div>

            <div id="recommendations-tab" class="tab-content">
                <div class="report-section recommendations">
                    <h3>Security Recommendations</h3>
                    <div class="report-content">$(cat "$temp_dir/recommendations.txt")</div>
                </div>
            </div>
        </div>

        <div class="footer">
            <p><em>User Management Report generated by Linux Automation System</em></p>
            <p><em>Next scheduled analysis: $(date -d 'tomorrow' '+%Y-%m-%d 06:00')</em></p>
        </div>
    </div>
</body>
</html>
EOF

    # Clean up temporary files
    rm -rf "$temp_dir"
    
    log_info "User management report generated: $report_file"
    
    if [[ $issues_found -eq 1 ]]; then
        return 1
    fi
    return 0
}

# Main user management orchestration function
run_user_management() {
    log_info "Starting comprehensive user management analysis"
    
    local overall_status=0
    local report_dir="/var/log/bash-admin/daily-reports"
    local today=$(date +%Y%m%d)
    
    # Ensure report directory exists
    mkdir -p "$report_dir"
    
    # Check if user management is enabled
    local enabled=$(get_config 'modules.user_management.enabled' 'true')
    if [[ "$enabled" != "true" ]]; then
        log_info "User management module is disabled"
        return 0
    fi
    
    # Run all user management functions
    log_info "Analyzing user accounts..."
    if ! get_user_account_status "$report_dir/user_accounts_$today.txt"; then
        log_warn "User account analysis completed with warnings"
        overall_status=1
    fi
    
    log_info "Checking password policies..."
    if ! check_password_policies "$report_dir/password_policies_$today.txt"; then
        log_warn "Password policy check found violations"
        overall_status=1
    fi
    
    log_info "Monitoring failed logins..."
    if ! monitor_failed_logins "$report_dir/failed_logins_$today.txt"; then
        log_warn "Failed login monitoring detected issues"
        overall_status=1
    fi
    
    log_info "Checking inactive users..."
    if ! check_inactive_users "$report_dir/inactive_users_$today.txt"; then
        log_warn "Inactive user check found dormant accounts"
        overall_status=1
    fi
    
    log_info "Auditing user permissions..."
    if ! audit_user_permissions "$report_dir/user_permissions_$today.txt"; then
        log_warn "User permissions audit found security issues"
        overall_status=1
    fi
    
    log_info "Generating recommendations..."
    generate_user_recommendations "$report_dir/user_recommendations_$today.txt"
    
    log_info "Creating comprehensive report..."
    if ! generate_user_report "$report_dir/user_management_$today.html"; then
        log_warn "User management report completed with issues detected"
        overall_status=1
    fi
    
    # Send notification if configured
    local notification_enabled=$(get_config 'modules.user_management.notification_on_issues' 'true')
    if [[ "$notification_enabled" == "true" && $overall_status -ne 0 ]]; then
        local recipient=$(get_config 'notifications.recipients.security' 'admin@example.com')
        local subject="⚠️ User Management Issues Detected - $(hostname)"
        local body="User management analysis completed with issues detected.

Report available at: $report_dir/user_management_$today.html

Please review the findings and take appropriate action.

Linux Automation System"
        
        send_email "$recipient" "$subject" "$body" "$report_dir/user_management_$today.html"
    fi
    
    if [[ $overall_status -eq 0 ]]; then
        log_success "User management analysis completed successfully"
    else
        log_error "User management analysis completed with issues requiring attention"
    fi
    
    return $overall_status
}