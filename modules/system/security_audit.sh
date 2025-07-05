#!/bin/bash
# Security Audit Module
# Provides functions for daily security checks and compliance monitoring

# Source core libraries
source "$(dirname "$0")/../../core/lib/init.sh"

# Check file permissions for sensitive files
check_file_permissions() {
    local report_file="${1:-/tmp/file_permissions_$(date +%Y%m%d).txt}"
    local permission_issues=()
    
    log_info "Checking sensitive file permissions"
    
    # Define critical files and their expected permissions
    declare -A critical_files=(
        ["/etc/passwd"]="644"
        ["/etc/shadow"]="640"
        ["/etc/group"]="644"
        ["/etc/gshadow"]="640"
        ["/etc/sudoers"]="440"
        ["/etc/ssh/sshd_config"]="644"
        ["/root/.ssh/authorized_keys"]="600"
        ["/etc/crontab"]="644"
        ["/var/log/auth.log"]="640"
        ["/var/log/secure"]="600"
    )
    
    for file in "${!critical_files[@]}"; do
        if [[ -f "$file" ]]; then
            local current_perms=$(stat -c "%a" "$file")
            local expected_perms=${critical_files[$file]}
            
            if [[ "$current_perms" != "$expected_perms" ]]; then
                permission_issues+=("$file: $current_perms (expected: $expected_perms)")
                log_warn "Incorrect permissions on $file: $current_perms (expected: $expected_perms)"
            fi
        fi
    done
    
    # Check for world-writable files in system directories
    log_debug "Scanning for world-writable files"
    while IFS= read -r -d '' file; do
        permission_issues+=("World-writable file: $file")
        log_warn "Found world-writable file: $file"
    done < <(find /etc /usr /bin /sbin -type f -perm -002 -print0 2>/dev/null)
    
    # Generate report
    {
        echo "File Permissions Security Report - $(date)"
        echo "========================================"
        echo
        if [[ ${#permission_issues[@]} -eq 0 ]]; then
            echo "No permission issues found"
        else
            echo "PERMISSION ISSUES FOUND:"
            printf "%s\n" "${permission_issues[@]}"
        fi
    } > "$report_file"
    
    log_info "File permissions report generated: $report_file"
    
    if [[ ${#permission_issues[@]} -gt 0 ]]; then
        send_notification "security" "File Permission Issues" \
            "Found ${#permission_issues[@]} file permission issues. Check $report_file for details."
    fi
    
    return ${#permission_issues[@]}
}

# Check for suspicious processes and network connections
check_running_processes() {
    local report_file="${1:-/tmp/process_security_$(date +%Y%m%d).txt}"
    local suspicious_processes=()
    local suspicious_connections=()
    
    log_info "Checking for suspicious processes and connections"
    
    # Check for processes running as root that shouldn't be
    while read -r user pid cmd; do
        # Skip kernel threads
        [[ "$cmd" =~ ^\[.*\]$ ]] && continue
        
        # Check for suspicious commands running as root
        if [[ "$user" == "root" ]]; then
            case "$cmd" in
                *nc*|*netcat*|*socat*)
                    suspicious_processes+=("Root process: $pid $cmd")
                    ;;
                */tmp/*|*/dev/shm/*)
                    suspicious_processes+=("Root process from temp: $pid $cmd")
                    ;;
                *wget*|*curl*|*python*http*)
                    suspicious_processes+=("Root network tool: $pid $cmd")
                    ;;
            esac
        fi
    done < <(ps -eo user,pid,comm --no-headers)
    
    # Check for suspicious network connections
    if command -v netstat >/dev/null; then
        while read -r proto recv send local foreign state pid_program; do
            # Check for unexpected listening services
            if [[ "$state" == "LISTEN" ]]; then
                local port=$(echo "$local" | cut -d: -f2)
                case "$port" in
                    22|80|443|25|53|123) ;;  # Common legitimate ports
                    *)
                        if [[ "$port" -gt 1024 ]]; then
                            suspicious_connections+=("Unexpected listening port: $port ($pid_program)")
                        fi
                        ;;
                esac
            fi
            
            # Check for connections to suspicious destinations
            if [[ "$state" == "ESTABLISHED" ]]; then
                local remote_ip=$(echo "$foreign" | cut -d: -f1)
                # Skip local connections
                if [[ ! "$remote_ip" =~ ^(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.) ]]; then
                    suspicious_connections+=("External connection: $foreign ($pid_program)")
                fi
            fi
        done < <(netstat -tulpn 2>/dev/null | grep -E "(LISTEN|ESTABLISHED)")
    fi
    
    # Generate report
    {
        echo "Process and Network Security Report - $(date)"
        echo "==========================================="
        echo
        echo "SUSPICIOUS PROCESSES:"
        if [[ ${#suspicious_processes[@]} -eq 0 ]]; then
            echo "  None found"
        else
            printf "  %s\n" "${suspicious_processes[@]}"
        fi
        echo
        echo "SUSPICIOUS NETWORK CONNECTIONS:"
        if [[ ${#suspicious_connections[@]} -eq 0 ]]; then
            echo "  None found"
        else
            printf "  %s\n" "${suspicious_connections[@]}"
        fi
    } > "$report_file"
    
    log_info "Process security report generated: $report_file"
    
    local total_issues=$((${#suspicious_processes[@]} + ${#suspicious_connections[@]}))
    if [[ $total_issues -gt 0 ]]; then
        send_notification "security" "Suspicious Activity Detected" \
            "Found $total_issues suspicious processes/connections. Check $report_file for details."
    fi
    
    return $total_issues
}

# Check system configuration for security compliance
check_security_config() {
    local report_file="${1:-/tmp/security_config_$(date +%Y%m%d).txt}"
    local config_issues=()
    
    log_info "Checking security configuration compliance"
    
    # Check SSH configuration
    if [[ -f /etc/ssh/sshd_config ]]; then
        # Root login should be disabled
        if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config; then
            config_issues+=("SSH: Root login is enabled")
        fi
        
        # Password authentication should be disabled for key-based auth
        if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
            config_issues+=("SSH: Password authentication enabled")
        fi
        
        # Empty passwords should not be permitted
        if grep -q "^PermitEmptyPasswords yes" /etc/ssh/sshd_config; then
            config_issues+=("SSH: Empty passwords permitted")
        fi
    fi
    
    # Check firewall status
    if command -v ufw >/dev/null; then
        if ! ufw status | grep -q "Status: active"; then
            config_issues+=("Firewall: UFW is not active")
        fi
    elif command -v firewall-cmd >/dev/null; then
        if ! firewall-cmd --state 2>/dev/null | grep -q "running"; then
            config_issues+=("Firewall: FirewallD is not running")
        fi
    else
        config_issues+=("Firewall: No firewall service found")
    fi
    
    # Check for automatic updates
    if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
        if ! grep -q "APT::Periodic::Unattended-Upgrade \"1\"" /etc/apt/apt.conf.d/20auto-upgrades; then
            config_issues+=("Updates: Automatic security updates not enabled")
        fi
    fi
    
    # Check password policy
    if [[ -f /etc/login.defs ]]; then
        local pass_max_days=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}')
        if [[ -n "$pass_max_days" && $pass_max_days -gt 90 ]]; then
            config_issues+=("Password policy: Maximum password age too long ($pass_max_days days)")
        fi
    fi
    
    # Check for unnecessary services
    local unnecessary_services=("telnet" "rsh" "rlogin" "tftp")
    for service in "${unnecessary_services[@]}"; do
        if systemctl is-enabled "$service" 2>/dev/null | grep -q "enabled"; then
            config_issues+=("Services: Unnecessary service enabled: $service")
        fi
    done
    
    # Generate report
    {
        echo "Security Configuration Report - $(date)"
        echo "====================================="
        echo
        if [[ ${#config_issues[@]} -eq 0 ]]; then
            echo "No security configuration issues found"
        else
            echo "CONFIGURATION ISSUES FOUND:"
            printf "%s\n" "${config_issues[@]}"
        fi
    } > "$report_file"
    
    log_info "Security configuration report generated: $report_file"
    
    if [[ ${#config_issues[@]} -gt 0 ]]; then
        send_notification "security" "Security Configuration Issues" \
            "Found ${#config_issues[@]} security configuration issues. Check $report_file for details."
    fi
    
    return ${#config_issues[@]}
}

# Check for system vulnerabilities and updates
check_system_vulnerabilities() {
    local report_file="${1:-/tmp/vulnerability_scan_$(date +%Y%m%d).txt}"
    local vulnerabilities=()
    local security_updates=0
    
    log_info "Checking for system vulnerabilities and available updates"
    
    # Check for available security updates
    if command -v apt >/dev/null; then
        # Debian/Ubuntu systems
        apt update >/dev/null 2>&1
        security_updates=$(apt list --upgradable 2>/dev/null | grep -c "security")
        
        if [[ $security_updates -gt 0 ]]; then
            vulnerabilities+=("$security_updates security updates available")
        fi
        
        # Check for unattended-upgrades
        if ! dpkg -l | grep -q unattended-upgrades; then
            vulnerabilities+=("Unattended-upgrades package not installed")
        fi
    elif command -v yum >/dev/null; then
        # RHEL/CentOS systems
        security_updates=$(yum check-update --security -q 2>/dev/null | wc -l)
        
        if [[ $security_updates -gt 0 ]]; then
            vulnerabilities+=("$security_updates security updates available")
        fi
    fi
    
    # Check for known vulnerable packages
    local vulnerable_packages=()
    
    # Check OpenSSL version for known vulnerabilities
    if command -v openssl >/dev/null; then
        local openssl_version=$(openssl version | awk '{print $2}')
        # This is a simplified check - in practice, you'd check against CVE databases
        if [[ "$openssl_version" =~ ^1\.0\. ]]; then
            vulnerable_packages+=("OpenSSL $openssl_version (potentially vulnerable)")
        fi
    fi
    
    # Check for running services with known vulnerabilities
    local vulnerable_services=("apache2" "nginx" "mysql" "postgresql")
    for service in "${vulnerable_services[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            # In practice, you'd check version against vulnerability databases
            local service_version=$(systemctl show "$service" --property=Version 2>/dev/null | cut -d= -f2)
            if [[ -n "$service_version" ]]; then
                vulnerable_packages+=("$service $service_version (check for vulnerabilities)")
            fi
        fi
    done
    
    # Generate report
    {
        echo "Vulnerability Assessment Report - $(date)"
        echo "======================================"
        echo
        echo "SECURITY UPDATES:"
        if [[ $security_updates -eq 0 ]]; then
            echo "  No security updates available"
        else
            echo "  $security_updates security updates available"
        fi
        echo
        echo "POTENTIAL VULNERABILITIES:"
        if [[ ${#vulnerable_packages[@]} -eq 0 ]]; then
            echo "  No obvious vulnerabilities detected"
        else
            printf "  %s\n" "${vulnerable_packages[@]}"
        fi
        echo
        echo "ADDITIONAL ISSUES:"
        if [[ ${#vulnerabilities[@]} -eq 0 ]]; then
            echo "  None found"
        else
            printf "  %s\n" "${vulnerabilities[@]}"
        fi
    } > "$report_file"
    
    log_info "Vulnerability assessment report generated: $report_file"
    
    local total_issues=$((${#vulnerabilities[@]} + ${#vulnerable_packages[@]}))
    if [[ $security_updates -gt 0 || $total_issues -gt 0 ]]; then
        send_notification "security" "Security Updates Available" \
            "Found $security_updates security updates and $total_issues potential issues. Check $report_file for details."
    fi
    
    return $((security_updates + total_issues))
}

# Comprehensive security audit
run_security_audit() {
    local report_dir="${1:-/var/log/bash-admin/security-reports}"
    local today=$(date +%Y%m%d)
    
    mkdir -p "$report_dir"
    
    log_info "Running comprehensive security audit"
    
    local total_issues=0
    
    # Run all security checks
    check_file_permissions "$report_dir/file_permissions_$today.txt"
    total_issues=$((total_issues + $?))
    
    check_running_processes "$report_dir/process_security_$today.txt"
    total_issues=$((total_issues + $?))
    
    check_security_config "$report_dir/security_config_$today.txt"
    total_issues=$((total_issues + $?))
    
    check_system_vulnerabilities "$report_dir/vulnerability_scan_$today.txt"
    total_issues=$((total_issues + $?))
    
    log_info "Security audit completed with $total_issues total issues"
    return $total_issues
}

# Export functions for use by other scripts
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f check_file_permissions
    export -f check_running_processes
    export -f check_security_config
    export -f check_system_vulnerabilities
    export -f run_security_audit
fi