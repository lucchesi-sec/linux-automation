#!/bin/bash

# BashAdminCore - Security Module
# Provides security utilities, permission checks, and compliance validation

# Security constants
declare -g SECURE_FILE_PERMS="600"
declare -g SECURE_DIR_PERMS="700"
declare -g SECURE_SCRIPT_PERMS="700"
declare -g SECURITY_LOG_DIR="${BASH_ADMIN_LOG_DIR:-/var/log/bash-admin}/security"

# Initialize security module
init_security() {
    # Create security log directory if it doesn't exist
    if [[ ! -d "$SECURITY_LOG_DIR" ]]; then
        mkdir -p "$SECURITY_LOG_DIR" 2>/dev/null || {
            SECURITY_LOG_DIR="$HOME/.bash-admin/logs/security"
            mkdir -p "$SECURITY_LOG_DIR"
        }
    fi
    
    # Set secure permissions on security log directory
    chmod 700 "$SECURITY_LOG_DIR" 2>/dev/null || true
    
    log_debug "Security module initialized" "SECURITY"
}

# Check file permissions
check_file_permissions() {
    local file_path="$1"
    local expected_perms="${2:-$SECURE_FILE_PERMS}"
    
    if [[ ! -e "$file_path" ]]; then
        log_error "File does not exist: $file_path" "SECURITY"
        return 1
    fi
    
    local actual_perms=$(stat -c '%a' "$file_path" 2>/dev/null || stat -f '%Lp' "$file_path" 2>/dev/null)
    
    if [[ "$actual_perms" == "$expected_perms" ]]; then
        log_debug "File permissions OK: $file_path ($actual_perms)" "SECURITY"
        return 0
    else
        log_warn "File permissions mismatch: $file_path (expected: $expected_perms, actual: $actual_perms)" "SECURITY"
        return 1
    fi
}

# Set secure file permissions
set_secure_permissions() {
    local path="$1"
    local perms="${2:-$SECURE_FILE_PERMS}"
    
    if [[ ! -e "$path" ]]; then
        log_error "Path does not exist: $path" "SECURITY"
        return 1
    fi
    
    if chmod "$perms" "$path" 2>/dev/null; then
        log_success "Set permissions $perms on: $path" "SECURITY"
        return 0
    else
        log_error "Failed to set permissions on: $path" "SECURITY"
        return 1
    fi
}

# Validate SSH configuration
validate_ssh_config() {
    local ssh_config="${1:-/etc/ssh/sshd_config}"
    local issues=()
    
    if [[ ! -f "$ssh_config" ]]; then
        log_warn "SSH config not found: $ssh_config" "SECURITY"
        return 1
    fi
    
    # Check for insecure settings
    if grep -qE "^PermitRootLogin\s+(yes|without-password)" "$ssh_config" 2>/dev/null; then
        issues+=("PermitRootLogin should be set to 'no'")
    fi
    
    if grep -qE "^PasswordAuthentication\s+yes" "$ssh_config" 2>/dev/null; then
        issues+=("Consider disabling PasswordAuthentication in favor of key-based auth")
    fi
    
    if ! grep -qE "^Protocol\s+2" "$ssh_config" 2>/dev/null; then
        issues+=("SSH Protocol should be set to 2")
    fi
    
    if ! grep -qE "^PermitEmptyPasswords\s+no" "$ssh_config" 2>/dev/null; then
        issues+=("PermitEmptyPasswords should be explicitly set to 'no'")
    fi
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        log_warn "SSH configuration issues found:" "SECURITY"
        for issue in "${issues[@]}"; do
            log_warn "  - $issue" "SECURITY"
        done
        return 1
    else
        log_success "SSH configuration appears secure" "SECURITY"
        return 0
    fi
}

# Check for world-writable files
find_world_writable() {
    local search_path="${1:-/}"
    local exclude_paths=("/tmp" "/var/tmp" "/dev/shm")
    local world_writable_files=()
    
    log_info "Scanning for world-writable files in: $search_path" "SECURITY"
    
    # Build exclude options
    local find_excludes=""
    for exclude in "${exclude_paths[@]}"; do
        find_excludes="$find_excludes -path $exclude -prune -o"
    done
    
    # Find world-writable files
    while IFS= read -r -d '' file; do
        world_writable_files+=("$file")
    done < <(find "$search_path" $find_excludes -type f -perm -002 -print0 2>/dev/null)
    
    if [[ ${#world_writable_files[@]} -gt 0 ]]; then
        log_warn "Found ${#world_writable_files[@]} world-writable files" "SECURITY"
        for file in "${world_writable_files[@]:0:10}"; do
            log_warn "  - $file" "SECURITY"
        done
        if [[ ${#world_writable_files[@]} -gt 10 ]]; then
            log_warn "  ... and $((${#world_writable_files[@]} - 10)) more" "SECURITY"
        fi
        return 1
    else
        log_success "No world-writable files found" "SECURITY"
        return 0
    fi
}

# Check for SUID/SGID files
find_suid_sgid() {
    local search_path="${1:-/}"
    local suid_files=()
    local sgid_files=()
    
    log_info "Scanning for SUID/SGID files in: $search_path" "SECURITY"
    
    # Find SUID files
    while IFS= read -r -d '' file; do
        suid_files+=("$file")
    done < <(find "$search_path" -type f -perm -4000 -print0 2>/dev/null)
    
    # Find SGID files
    while IFS= read -r -d '' file; do
        sgid_files+=("$file")
    done < <(find "$search_path" -type f -perm -2000 -print0 2>/dev/null)
    
    # Log results
    if [[ ${#suid_files[@]} -gt 0 ]]; then
        log_info "Found ${#suid_files[@]} SUID files" "SECURITY"
        for file in "${suid_files[@]:0:5}"; do
            log_info "  SUID: $file" "SECURITY"
        done
    fi
    
    if [[ ${#sgid_files[@]} -gt 0 ]]; then
        log_info "Found ${#sgid_files[@]} SGID files" "SECURITY"
        for file in "${sgid_files[@]:0:5}"; do
            log_info "  SGID: $file" "SECURITY"
        done
    fi
    
    # Write full list to security log
    local security_report="$SECURITY_LOG_DIR/suid_sgid_$(date +%Y%m%d_%H%M%S).log"
    {
        echo "SUID/SGID File Report - $(date)"
        echo "========================="
        echo ""
        echo "SUID Files (${#suid_files[@]}):"
        printf '%s\n' "${suid_files[@]}"
        echo ""
        echo "SGID Files (${#sgid_files[@]}):"
        printf '%s\n' "${sgid_files[@]}"
    } > "$security_report"
    
    log_info "Full SUID/SGID report saved to: $security_report" "SECURITY"
}

# Validate password policy
check_password_policy() {
    local policy_file="/etc/security/pwquality.conf"
    local issues=()
    
    if [[ -f "$policy_file" ]]; then
        # Check minimum length
        local min_len=$(grep -E "^minlen" "$policy_file" 2>/dev/null | awk -F= '{print $2}' | tr -d ' ')
        if [[ -z "$min_len" ]] || [[ "$min_len" -lt 12 ]]; then
            issues+=("Password minimum length should be at least 12 characters")
        fi
        
        # Check complexity requirements
        if ! grep -qE "^dcredit.*=-1" "$policy_file" 2>/dev/null; then
            issues+=("Password should require at least one digit (dcredit = -1)")
        fi
        
        if ! grep -qE "^ucredit.*=-1" "$policy_file" 2>/dev/null; then
            issues+=("Password should require at least one uppercase letter (ucredit = -1)")
        fi
        
        if ! grep -qE "^lcredit.*=-1" "$policy_file" 2>/dev/null; then
            issues+=("Password should require at least one lowercase letter (lcredit = -1)")
        fi
        
        if ! grep -qE "^ocredit.*=-1" "$policy_file" 2>/dev/null; then
            issues+=("Password should require at least one special character (ocredit = -1)")
        fi
    else
        issues+=("Password policy file not found: $policy_file")
    fi
    
    # Check password aging in /etc/login.defs
    if [[ -f "/etc/login.defs" ]]; then
        local pass_max_days=$(grep -E "^PASS_MAX_DAYS" "/etc/login.defs" 2>/dev/null | awk '{print $2}')
        if [[ -z "$pass_max_days" ]] || [[ "$pass_max_days" -gt 90 ]]; then
            issues+=("PASS_MAX_DAYS should be 90 or less")
        fi
        
        local pass_min_days=$(grep -E "^PASS_MIN_DAYS" "/etc/login.defs" 2>/dev/null | awk '{print $2}')
        if [[ -z "$pass_min_days" ]] || [[ "$pass_min_days" -lt 1 ]]; then
            issues+=("PASS_MIN_DAYS should be at least 1")
        fi
    fi
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        log_warn "Password policy issues found:" "SECURITY"
        for issue in "${issues[@]}"; do
            log_warn "  - $issue" "SECURITY"
        done
        return 1
    else
        log_success "Password policy appears secure" "SECURITY"
        return 0
    fi
}

# Check for failed login attempts
check_failed_logins() {
    local threshold="${1:-5}"
    local auth_log="/var/log/auth.log"
    local secure_log="/var/log/secure"
    local suspicious_ips=()
    
    # Determine which log file to use
    local log_file=""
    if [[ -f "$auth_log" ]]; then
        log_file="$auth_log"
    elif [[ -f "$secure_log" ]]; then
        log_file="$secure_log"
    else
        log_warn "No authentication log found" "SECURITY"
        return 1
    fi
    
    log_info "Checking failed login attempts in: $log_file" "SECURITY"
    
    # Extract failed login attempts from the last 24 hours
    local yesterday=$(date -d "yesterday" +"%b %e" 2>/dev/null || date -v-1d +"%b %e" 2>/dev/null)
    local today=$(date +"%b %e")
    
    # Count failed attempts by IP
    declare -A failed_attempts
    while IFS= read -r line; do
        if [[ "$line" =~ Failed\ password.*from\ ([0-9.]+) ]]; then
            local ip="${BASH_REMATCH[1]}"
            ((failed_attempts["$ip"]++))
        fi
    done < <(grep -E "(${yesterday}|${today}).*Failed password" "$log_file" 2>/dev/null)
    
    # Check for IPs exceeding threshold
    for ip in "${!failed_attempts[@]}"; do
        if [[ ${failed_attempts["$ip"]} -ge $threshold ]]; then
            suspicious_ips+=("$ip (${failed_attempts["$ip"]} attempts)")
        fi
    done
    
    if [[ ${#suspicious_ips[@]} -gt 0 ]]; then
        log_warn "Suspicious login activity detected:" "SECURITY"
        for ip_info in "${suspicious_ips[@]}"; do
            log_warn "  - $ip_info" "SECURITY"
        done
        return 1
    else
        log_success "No suspicious login activity detected" "SECURITY"
        return 0
    fi
}

# Generate security audit report
generate_security_audit() {
    local report_file="${1:-$SECURITY_LOG_DIR/security_audit_$(date +%Y%m%d_%H%M%S).log}"
    
    log_info "Starting security audit..." "SECURITY"
    
    {
        echo "Security Audit Report"
        echo "===================="
        echo "Generated: $(date)"
        echo "Host: $(hostname -f)"
        echo "User: $(whoami)"
        echo ""
        
        echo "SSH Configuration:"
        echo "-----------------"
        if validate_ssh_config; then
            echo "✓ SSH configuration is secure"
        else
            echo "✗ SSH configuration has issues (see details above)"
        fi
        echo ""
        
        echo "Password Policy:"
        echo "---------------"
        if check_password_policy; then
            echo "✓ Password policy is secure"
        else
            echo "✗ Password policy has issues (see details above)"
        fi
        echo ""
        
        echo "Failed Login Attempts:"
        echo "---------------------"
        if check_failed_logins; then
            echo "✓ No suspicious login activity"
        else
            echo "✗ Suspicious login activity detected (see details above)"
        fi
        echo ""
        
        echo "World-Writable Files:"
        echo "--------------------"
        if find_world_writable "/etc" >/dev/null 2>&1; then
            echo "✓ No world-writable files in /etc"
        else
            echo "✗ World-writable files found in /etc"
        fi
        echo ""
        
    } | tee "$report_file"
    
    log_success "Security audit completed. Report saved to: $report_file" "SECURITY"
    
    # Send notification if issues found
    if grep -q "✗" "$report_file"; then
        send_notification "WARN" "Security Audit Issues Found" "Security issues were detected during audit. Please review: $report_file" "SECURITY"
    fi
}

# Sanitize user input
sanitize_input() {
    local input="$1"
    local sanitized=""
    
    # Remove potentially dangerous characters
    sanitized=$(echo "$input" | tr -d '\`$(){}[]|&;<>"' | sed 's/\\/\\\\/g')
    
    echo "$sanitized"
}

# Validate input against pattern
validate_input() {
    local input="$1"
    local pattern="$2"
    local description="${3:-input}"
    
    if [[ ! "$input" =~ $pattern ]]; then
        log_error "Invalid $description: $input" "SECURITY"
        return 1
    fi
    
    return 0
}

# Initialize security module when sourced
init_security