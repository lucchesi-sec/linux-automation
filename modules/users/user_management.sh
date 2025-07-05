#!/bin/bash
# User Management Module
# Provides functions for daily user administration tasks

# Source core libraries
source "$(dirname "$0")/../../core/lib/init.sh"

# Daily user account verification
check_user_accounts() {
    local report_file="${1:-/tmp/user_account_report_$(date +%Y%m%d).txt}"
    local suspicious_users=()
    local inactive_users=()
    local expired_accounts=()
    
    log_info "Starting daily user account verification"
    
    # Check for suspicious user accounts
    while IFS=: read -r username password uid gid gecos home shell; do
        # Skip system accounts (UID < 1000)
        if [[ $uid -lt 1000 && $uid -ne 0 ]]; then
            continue
        fi
        
        # Check for accounts with empty passwords
        if [[ -z "$password" || "$password" == "" ]]; then
            suspicious_users+=("$username: Empty password")
        fi
        
        # Check for inactive users (no login in 30 days)
        if ! last "$username" -n 1 | grep -q "$(date -d '30 days ago' '+%a %b %d')"; then
            inactive_users+=("$username: No login in 30+ days")
        fi
        
        # Check for expired accounts
        if chage -l "$username" 2>/dev/null | grep -q "Account expires.*$(date -d 'yesterday' '+%b %d, %Y')"; then
            expired_accounts+=("$username: Account expired")
        fi
        
    done < /etc/passwd
    
    # Generate report
    {
        echo "Daily User Account Report - $(date)"
        echo "========================================"
        echo
        echo "SUSPICIOUS ACCOUNTS:"
        if [[ ${#suspicious_users[@]} -eq 0 ]]; then
            echo "  None found"
        else
            printf "  %s\n" "${suspicious_users[@]}"
        fi
        echo
        echo "INACTIVE ACCOUNTS (30+ days):"
        if [[ ${#inactive_users[@]} -eq 0 ]]; then
            echo "  None found"
        else
            printf "  %s\n" "${inactive_users[@]}"
        fi
        echo
        echo "EXPIRED ACCOUNTS:"
        if [[ ${#expired_accounts[@]} -eq 0 ]]; then
            echo "  None found"
        else
            printf "  %s\n" "${expired_accounts[@]}"
        fi
    } > "$report_file"
    
    log_info "User account report generated: $report_file"
    
    # Send notification if issues found
    local total_issues=$((${#suspicious_users[@]} + ${#inactive_users[@]} + ${#expired_accounts[@]}))
    if [[ $total_issues -gt 0 ]]; then
        send_notification "admin" "User Account Issues Found" \
            "Found $total_issues user account issues requiring attention. Check $report_file for details."
    fi
    
    return $total_issues
}

# Clean up temporary user files
cleanup_user_temp() {
    local days_old="${1:-7}"
    local temp_dirs=("/tmp" "/var/tmp" "/home/*/tmp")
    local files_cleaned=0
    
    log_info "Cleaning temporary user files older than $days_old days"
    
    for temp_dir in "${temp_dirs[@]}"; do
        if [[ -d "$temp_dir" ]]; then
            # Find and remove old temporary files
            while IFS= read -r -d '' file; do
                if rm -f "$file" 2>/dev/null; then
                    ((files_cleaned++))
                    log_debug "Removed temp file: $file"
                fi
            done < <(find "$temp_dir" -type f -mtime +$days_old -print0 2>/dev/null)
        fi
    done
    
    log_info "Cleaned $files_cleaned temporary files"
    return 0
}

# Monitor failed login attempts
check_failed_logins() {
    local threshold="${1:-5}"
    local report_file="${2:-/tmp/failed_logins_$(date +%Y%m%d).txt}"
    local suspicious_ips=()
    
    log_info "Checking for suspicious login attempts (threshold: $threshold)"
    
    # Analyze auth logs for failed attempts
    if [[ -f /var/log/auth.log ]]; then
        # Extract failed SSH attempts from today
        grep "$(date '+%b %d')" /var/log/auth.log | \
        grep "Failed password" | \
        awk '{print $11}' | \
        sort | uniq -c | \
        while read count ip; do
            if [[ $count -ge $threshold ]]; then
                suspicious_ips+=("$ip: $count failed attempts")
                log_warn "Suspicious activity from IP $ip: $count failed login attempts"
            fi
        done
    fi
    
    # Generate report
    {
        echo "Failed Login Attempts Report - $(date)"
        echo "====================================="
        echo
        if [[ ${#suspicious_ips[@]} -eq 0 ]]; then
            echo "No suspicious login activity detected"
        else
            echo "SUSPICIOUS IP ADDRESSES:"
            printf "  %s\n" "${suspicious_ips[@]}"
        fi
    } > "$report_file"
    
    # Send alert if suspicious activity found
    if [[ ${#suspicious_ips[@]} -gt 0 ]]; then
        send_notification "security" "Suspicious Login Activity" \
            "Detected ${#suspicious_ips[@]} IP addresses with excessive failed login attempts. Check $report_file for details."
    fi
    
    return ${#suspicious_ips[@]}
}

# Reset user password and force change on next login
reset_user_password() {
    local username="$1"
    local temp_password="$2"
    
    if [[ -z "$username" ]]; then
        log_error "Username required for password reset"
        return 1
    fi
    
    if ! id "$username" &>/dev/null; then
        log_error "User $username does not exist"
        return 1
    fi
    
    # Generate temporary password if not provided
    if [[ -z "$temp_password" ]]; then
        temp_password=$(openssl rand -base64 12)
    fi
    
    # Reset password
    if echo "$username:$temp_password" | chpasswd; then
        # Force password change on next login
        chage -d 0 "$username"
        log_info "Password reset for user $username (temp password: $temp_password)"
        
        # Send notification
        send_notification "admin" "User Password Reset" \
            "Password has been reset for user $username. Temporary password: $temp_password"
        
        return 0
    else
        log_error "Failed to reset password for user $username"
        return 1
    fi
}

# Lock/unlock user account
manage_user_account() {
    local action="$1"  # lock or unlock
    local username="$2"
    local reason="$3"
    
    if [[ -z "$action" || -z "$username" ]]; then
        log_error "Action and username required"
        return 1
    fi
    
    if ! id "$username" &>/dev/null; then
        log_error "User $username does not exist"
        return 1
    fi
    
    case "$action" in
        "lock")
            if usermod -L "$username"; then
                log_info "User account $username locked. Reason: ${reason:-Administrative action}"
                send_notification "admin" "User Account Locked" \
                    "User account $username has been locked. Reason: ${reason:-Administrative action}"
                return 0
            fi
            ;;
        "unlock")
            if usermod -U "$username"; then
                log_info "User account $username unlocked"
                send_notification "admin" "User Account Unlocked" \
                    "User account $username has been unlocked"
                return 0
            fi
            ;;
        *)
            log_error "Invalid action: $action. Use 'lock' or 'unlock'"
            return 1
            ;;
    esac
    
    log_error "Failed to $action user account $username"
    return 1
}

# Export functions for use by other scripts
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f check_user_accounts
    export -f cleanup_user_temp
    export -f check_failed_logins
    export -f reset_user_password
    export -f manage_user_account
fi