#!/bin/bash
# Package Management Module
# Provides functions for security updates monitoring and automated installation

# Source core libraries
source "$(dirname "$0")/../../core/lib/init.sh"

# Detect the package manager on this system
detect_package_manager() {
    local package_manager=""
    
    if command -v apt-get >/dev/null 2>&1; then
        package_manager="apt"
    elif command -v dnf >/dev/null 2>&1; then
        package_manager="dnf"
    elif command -v yum >/dev/null 2>&1; then
        package_manager="yum"
    elif command -v zypper >/dev/null 2>&1; then
        package_manager="zypper"
    elif command -v pacman >/dev/null 2>&1; then
        package_manager="pacman"
    else
        log_error "No supported package manager found"
        return 1
    fi
    
    log_debug "Detected package manager: $package_manager"
    echo "$package_manager"
    return 0
}

# Update package cache/repositories
update_package_cache() {
    local package_manager="${1:-$(detect_package_manager)}"
    local update_sources="${2:-$(get_config 'modules.package_management.update_sources' 'true')}"
    
    if [[ "$update_sources" != "true" ]]; then
        log_debug "Package cache update disabled in configuration"
        return 0
    fi
    
    log_info "Updating package cache for $package_manager"
    
    case "$package_manager" in
        "apt")
            if apt-get update >/dev/null 2>&1; then
                log_success "Package cache updated successfully"
                return 0
            else
                log_error "Failed to update package cache"
                return 1
            fi
            ;;
        "dnf")
            if dnf check-update >/dev/null 2>&1 || [[ $? -eq 100 ]]; then
                log_success "Package cache updated successfully"
                return 0
            else
                log_error "Failed to update package cache"
                return 1
            fi
            ;;
        "yum")
            if yum check-update >/dev/null 2>&1 || [[ $? -eq 100 ]]; then
                log_success "Package cache updated successfully"
                return 0
            else
                log_error "Failed to update package cache"
                return 1
            fi
            ;;
        "zypper")
            if zypper refresh >/dev/null 2>&1; then
                log_success "Package cache updated successfully"
                return 0
            else
                log_error "Failed to update package cache"
                return 1
            fi
            ;;
        "pacman")
            if pacman -Sy >/dev/null 2>&1; then
                log_success "Package cache updated successfully"
                return 0
            else
                log_error "Failed to update package cache"
                return 1
            fi
            ;;
        *)
            log_error "Unsupported package manager: $package_manager"
            return 1
            ;;
    esac
}

# Check for available security updates
check_security_updates() {
    local package_manager="${1:-$(detect_package_manager)}"
    local report_file="${2:-/tmp/security_updates_$(date +%Y%m%d).txt}"
    local critical_updates=()
    local important_updates=()
    local moderate_updates=()
    local low_updates=()
    local total_updates=0
    
    log_info "Checking for security updates using $package_manager"
    
    # Update package cache first
    update_package_cache "$package_manager"
    
    case "$package_manager" in
        "apt")
            # For APT, we need to check for security updates
            local security_updates
            security_updates=$(apt list --upgradable 2>/dev/null | grep -E "(security|Security)" || true)
            
            if [[ -n "$security_updates" ]]; then
                while IFS= read -r line; do
                    if [[ -n "$line" && "$line" != *"WARNING"* ]]; then
                        local package_name
                        package_name=$(echo "$line" | cut -d'/' -f1)
                        
                        # Categorize by urgency (simplified for APT)
                        if echo "$line" | grep -qi "critical"; then
                            critical_updates+=("$package_name")
                        elif echo "$line" | grep -qi "important"; then
                            important_updates+=("$package_name")
                        else
                            moderate_updates+=("$package_name")
                        fi
                        ((total_updates++))
                    fi
                done <<< "$security_updates"
            fi
            ;;
        "dnf")
            # DNF security updates
            local security_info
            security_info=$(dnf updateinfo list security 2>/dev/null || true)
            
            if [[ -n "$security_info" ]]; then
                while IFS= read -r line; do
                    if [[ "$line" == *"Critical"* ]]; then
                        local package_name
                        package_name=$(echo "$line" | awk '{print $3}')
                        critical_updates+=("$package_name")
                        ((total_updates++))
                    elif [[ "$line" == *"Important"* ]]; then
                        local package_name
                        package_name=$(echo "$line" | awk '{print $3}')
                        important_updates+=("$package_name")
                        ((total_updates++))
                    elif [[ "$line" == *"Moderate"* ]]; then
                        local package_name
                        package_name=$(echo "$line" | awk '{print $3}')
                        moderate_updates+=("$package_name")
                        ((total_updates++))
                    elif [[ "$line" == *"Low"* ]]; then
                        local package_name
                        package_name=$(echo "$line" | awk '{print $3}')
                        low_updates+=("$package_name")
                        ((total_updates++))
                    fi
                done <<< "$security_info"
            fi
            ;;
        "yum")
            # YUM security updates
            local security_info
            security_info=$(yum updateinfo list security 2>/dev/null || true)
            
            if [[ -n "$security_info" ]]; then
                while IFS= read -r line; do
                    if [[ "$line" == *"Critical"* ]]; then
                        local package_name
                        package_name=$(echo "$line" | awk '{print $3}')
                        critical_updates+=("$package_name")
                        ((total_updates++))
                    elif [[ "$line" == *"Important"* ]]; then
                        local package_name
                        package_name=$(echo "$line" | awk '{print $3}')
                        important_updates+=("$package_name")
                        ((total_updates++))
                    elif [[ "$line" == *"Moderate"* ]]; then
                        local package_name
                        package_name=$(echo "$line" | awk '{print $3}')
                        moderate_updates+=("$package_name")
                        ((total_updates++))
                    elif [[ "$line" == *"Low"* ]]; then
                        local package_name
                        package_name=$(echo "$line" | awk '{print $3}')
                        low_updates+=("$package_name")
                        ((total_updates++))
                    fi
                done <<< "$security_info"
            fi
            ;;
        "zypper")
            # ZYPPER security patches
            local security_patches
            security_patches=$(zypper list-patches --category security 2>/dev/null | grep "needed" || true)
            
            if [[ -n "$security_patches" ]]; then
                while IFS= read -r line; do
                    if [[ -n "$line" ]]; then
                        local patch_name
                        patch_name=$(echo "$line" | awk '{print $2}')
                        
                        # Categorize by priority
                        if echo "$line" | grep -qi "critical"; then
                            critical_updates+=("$patch_name")
                        elif echo "$line" | grep -qi "important"; then
                            important_updates+=("$patch_name")
                        else
                            moderate_updates+=("$patch_name")
                        fi
                        ((total_updates++))
                    fi
                done <<< "$security_patches"
            fi
            ;;
        *)
            log_error "Security update checking not implemented for $package_manager"
            return 1
            ;;
    esac
    
    # Generate report
    {
        echo "Security Updates Report - $(date)"
        echo "=================================="
        echo
        echo "SUMMARY:"
        echo "  Total Security Updates: $total_updates"
        echo "  Critical: ${#critical_updates[@]}"
        echo "  Important: ${#important_updates[@]}"
        echo "  Moderate: ${#moderate_updates[@]}"
        echo "  Low: ${#low_updates[@]}"
        echo
        
        if [[ ${#critical_updates[@]} -gt 0 ]]; then
            echo "CRITICAL UPDATES:"
            printf "  %s\n" "${critical_updates[@]}"
            echo
        fi
        
        if [[ ${#important_updates[@]} -gt 0 ]]; then
            echo "IMPORTANT UPDATES:"
            printf "  %s\n" "${important_updates[@]}"
            echo
        fi
        
        if [[ ${#moderate_updates[@]} -gt 0 ]]; then
            echo "MODERATE UPDATES:"
            printf "  %s\n" "${moderate_updates[@]}"
            echo
        fi
        
        if [[ ${#low_updates[@]} -gt 0 ]]; then
            echo "LOW PRIORITY UPDATES:"
            printf "  %s\n" "${low_updates[@]}"
            echo
        fi
        
        if [[ $total_updates -eq 0 ]]; then
            echo "No security updates available."
        fi
        
    } > "$report_file"
    
    log_info "Security updates report generated: $report_file"
    
    # Send notification if critical updates available
    if [[ ${#critical_updates[@]} -gt 0 ]]; then
        send_notification "admin" "Critical Security Updates Available" \
            "Found ${#critical_updates[@]} critical security updates: ${critical_updates[*]}. Check $report_file for details."
    fi
    
    return $total_updates
}

# Create system snapshot before updates
create_system_snapshot() {
    local snapshot_enabled="${1:-$(get_config 'modules.package_management.create_snapshots' 'true')}"
    local snapshot_name="pre-update-$(date +%Y%m%d-%H%M%S)"
    
    if [[ "$snapshot_enabled" != "true" ]]; then
        log_debug "System snapshots disabled in configuration"
        return 0
    fi
    
    log_info "Creating system snapshot: $snapshot_name"
    
    # Try different snapshot tools
    if command -v timeshift >/dev/null 2>&1; then
        if timeshift --create --comments "$snapshot_name" >/dev/null 2>&1; then
            log_success "System snapshot created with timeshift: $snapshot_name"
            return 0
        else
            log_warn "Failed to create timeshift snapshot"
        fi
    elif command -v snapper >/dev/null 2>&1; then
        if snapper create --description "$snapshot_name" >/dev/null 2>&1; then
            log_success "System snapshot created with snapper: $snapshot_name"
            return 0
        else
            log_warn "Failed to create snapper snapshot"
        fi
    elif command -v lvm >/dev/null 2>&1; then
        # Basic LVM snapshot (requires manual configuration)
        log_info "LVM detected but automated snapshots require manual setup"
        return 0
    else
        log_warn "No snapshot tool available (timeshift, snapper, or lvm)"
        return 0
    fi
    
    return 1
}

# Install security updates based on configuration
install_security_updates() {
    local package_manager="${1:-$(detect_package_manager)}"
    local auto_install="${2:-$(get_config 'modules.package_management.auto_install_security' 'false')}"
    local severity_levels="${3:-$(get_config 'modules.package_management.severity_levels' 'critical')}"
    local exclude_packages="${4:-$(get_config 'modules.package_management.exclude_packages' '')}"
    
    if [[ "$auto_install" != "true" ]]; then
        log_info "Auto-installation of security updates is disabled"
        return 0
    fi
    
    log_info "Starting security update installation process"
    
    # Create snapshot before updates
    create_system_snapshot
    
    local updates_installed=0
    local installation_failed=0
    
    # Get current security updates
    local temp_report="/tmp/security_check_temp_$(date +%s).txt"
    check_security_updates "$package_manager" "$temp_report" >/dev/null 2>&1
    
    # Parse severity levels (space-separated or JSON array)
    local install_levels="$severity_levels"
    if [[ "$severity_levels" == *"["* ]]; then
        install_levels=$(echo "$severity_levels" | jq -r '.[]' 2>/dev/null | tr '\n' ' ' || echo "critical")
    fi
    
    log_debug "Will install updates for severity levels: $install_levels"
    
    case "$package_manager" in
        "apt")
            # Install security updates for APT
            if echo "$install_levels" | grep -q "critical\|important\|moderate\|low"; then
                log_info "Installing security updates via apt"
                
                if apt-get -y upgrade >/dev/null 2>&1; then
                    updates_installed=1
                    log_success "Security updates installed successfully"
                else
                    installation_failed=1
                    log_error "Failed to install security updates"
                fi
            fi
            ;;
        "dnf")
            # Install security updates for DNF
            if dnf upgrade --security -y >/dev/null 2>&1; then
                updates_installed=1
                log_success "Security updates installed successfully"
            else
                installation_failed=1
                log_error "Failed to install security updates"
            fi
            ;;
        "yum")
            # Install security updates for YUM
            if yum update --security -y >/dev/null 2>&1; then
                updates_installed=1
                log_success "Security updates installed successfully"
            else
                installation_failed=1
                log_error "Failed to install security updates"
            fi
            ;;
        "zypper")
            # Install security patches for ZYPPER
            if zypper patch --category security --non-interactive >/dev/null 2>&1; then
                updates_installed=1
                log_success "Security patches installed successfully"
            else
                installation_failed=1
                log_error "Failed to install security patches"
            fi
            ;;
        *)
            log_error "Auto-installation not implemented for $package_manager"
            return 1
            ;;
    esac
    
    # Check if reboot is required
    local reboot_required=false
    if [[ -f /var/run/reboot-required ]] || \
       [[ "$package_manager" == "dnf" && $(dnf needs-restarting -r >/dev/null 2>&1; echo $?) -eq 1 ]] || \
       [[ "$package_manager" == "yum" && $(needs-restarting -r >/dev/null 2>&1; echo $?) -eq 1 ]] || \
       [[ "$package_manager" == "zypper" && $(zypper ps -s >/dev/null 2>&1; echo $?) -eq 102 ]]; then
        reboot_required=true
    fi
    
    if [[ "$reboot_required" == "true" ]]; then
        local auto_reboot="${5:-$(get_config 'modules.package_management.reboot_if_required' 'false')}"
        
        if [[ "$auto_reboot" == "true" ]]; then
            log_warn "System reboot required after updates - scheduling reboot in 5 minutes"
            send_notification "admin" "System Reboot Scheduled" \
                "Security updates installed successfully. System will reboot in 5 minutes."
            shutdown -r +5 "Reboot required after security updates" &
        else
            log_warn "System reboot required after updates - please reboot manually"
            send_notification "admin" "Reboot Required" \
                "Security updates installed successfully. Please reboot the system at your earliest convenience."
        fi
    fi
    
    # Clean up
    rm -f "$temp_report"
    
    if [[ $installation_failed -gt 0 ]]; then
        send_notification "admin" "Security Update Installation Failed" \
            "Some security updates failed to install. Please check system logs for details."
        return 1
    fi
    
    return 0
}

# Generate comprehensive HTML package management report
generate_package_report() {
    local report_file="${1:-/tmp/package_report_$(date +%Y%m%d_%H%M%S).html}"
    local package_manager="${2:-$(detect_package_manager)}"
    
    log_info "Generating comprehensive package management report"
    
    # Get security updates data
    local temp_report="/tmp/package_check_temp_$(date +%s).txt"
    check_security_updates "$package_manager" "$temp_report" >/dev/null 2>&1
    local total_updates=$?
    
    # Parse the temp report for data
    local critical_count=0
    local important_count=0
    local moderate_count=0
    local low_count=0
    
    if [[ -f "$temp_report" ]]; then
        critical_count=$(grep -A 100 "CRITICAL UPDATES:" "$temp_report" | grep -B 100 "IMPORTANT UPDATES:\|MODERATE UPDATES:\|LOW PRIORITY UPDATES:\|$" | grep -c "^  " 2>/dev/null || echo 0)
        important_count=$(grep -A 100 "IMPORTANT UPDATES:" "$temp_report" | grep -B 100 "MODERATE UPDATES:\|LOW PRIORITY UPDATES:\|$" | grep -c "^  " 2>/dev/null || echo 0)
        moderate_count=$(grep -A 100 "MODERATE UPDATES:" "$temp_report" | grep -B 100 "LOW PRIORITY UPDATES:\|$" | grep -c "^  " 2>/dev/null || echo 0)
        low_count=$(grep -A 100 "LOW PRIORITY UPDATES:" "$temp_report" | grep -c "^  " 2>/dev/null || echo 0)
    fi
    
    # Get system information
    local last_update_check=$(stat -c %y "$temp_report" 2>/dev/null | cut -d'.' -f1 || echo "Unknown")
    local auto_install_enabled=$(get_config 'modules.package_management.auto_install_security' 'false')
    local snapshot_enabled=$(get_config 'modules.package_management.create_snapshots' 'true')
    
    # Generate HTML content
    local html_content="
<h2>Package Management Status</h2>
<div class=\"summary-stats\">
    <div class=\"stat-box\">
        <div class=\"stat-number\">$total_updates</div>
        <div class=\"stat-label\">Total Security Updates</div>
    </div>
    <div class=\"stat-box\">
        <div class=\"stat-number\">$critical_count</div>
        <div class=\"stat-label\">Critical</div>
    </div>
    <div class=\"stat-box\">
        <div class=\"stat-number\">$important_count</div>
        <div class=\"stat-label\">Important</div>
    </div>
    <div class=\"stat-box\">
        <div class=\"stat-number\">$moderate_count</div>
        <div class=\"stat-label\">Moderate</div>
    </div>
</div>

<h3>Security Update Details</h3>
<table class=\"package-table\">
<thead>
<tr>
<th>Severity</th>
<th>Count</th>
<th>Status</th>
<th>Action Required</th>
</tr>
</thead>
<tbody>
<tr class=\"$([ $critical_count -gt 0 ] && echo 'error' || echo 'success')\">
<td>Critical</td>
<td>$critical_count</td>
<td>$([ $critical_count -gt 0 ] && echo '<span class=\"status-error\">UPDATES AVAILABLE</span>' || echo '<span class=\"status-success\">UP TO DATE</span>')</td>
<td>$([ $critical_count -gt 0 ] && echo 'Immediate installation recommended' || echo 'None')</td>
</tr>
<tr class=\"$([ $important_count -gt 0 ] && echo 'warning' || echo 'success')\">
<td>Important</td>
<td>$important_count</td>
<td>$([ $important_count -gt 0 ] && echo '<span class=\"status-warning\">UPDATES AVAILABLE</span>' || echo '<span class=\"status-success\">UP TO DATE</span>')</td>
<td>$([ $important_count -gt 0 ] && echo 'Installation within 24 hours' || echo 'None')</td>
</tr>
<tr class=\"$([ $moderate_count -gt 0 ] && echo 'warning' || echo 'success')\">
<td>Moderate</td>
<td>$moderate_count</td>
<td>$([ $moderate_count -gt 0 ] && echo '<span class=\"status-warning\">UPDATES AVAILABLE</span>' || echo '<span class=\"status-success\">UP TO DATE</span>')</td>
<td>$([ $moderate_count -gt 0 ] && echo 'Schedule for next maintenance window' || echo 'None')</td>
</tr>
<tr class=\"$([ $low_count -gt 0 ] && echo 'info' || echo 'success')\">
<td>Low</td>
<td>$low_count</td>
<td>$([ $low_count -gt 0 ] && echo '<span class=\"status-info\">UPDATES AVAILABLE</span>' || echo '<span class=\"status-success\">UP TO DATE</span>')</td>
<td>$([ $low_count -gt 0 ] && echo 'Install during regular maintenance' || echo 'None')</td>
</tr>
</tbody>
</table>

<h3>System Configuration</h3>
<table class=\"config-table\">
<thead>
<tr>
<th>Setting</th>
<th>Value</th>
<th>Status</th>
</tr>
</thead>
<tbody>
<tr>
<td>Package Manager</td>
<td>$package_manager</td>
<td><span class=\"status-success\">DETECTED</span></td>
</tr>
<tr>
<td>Auto-Install Security Updates</td>
<td>$auto_install_enabled</td>
<td>$([ "$auto_install_enabled" = "true" ] && echo '<span class=\"status-success\">ENABLED</span>' || echo '<span class=\"status-warning\">DISABLED</span>')</td>
</tr>
<tr>
<td>System Snapshots</td>
<td>$snapshot_enabled</td>
<td>$([ "$snapshot_enabled" = "true" ] && echo '<span class=\"status-success\">ENABLED</span>' || echo '<span class=\"status-warning\">DISABLED</span>')</td>
</tr>
<tr>
<td>Last Update Check</td>
<td>$last_update_check</td>
<td><span class=\"status-info\">INFO</span></td>
</tr>
</tbody>
</table>

<h3>Recommendations</h3>
<div class=\"recommendations-info\">"

    if [[ $critical_count -gt 0 ]]; then
        html_content="$html_content
<div class=\"summary-box summary-danger\">
<h4>Critical Security Updates Available</h4>
<ul>
<li>Install $critical_count critical security updates immediately</li>
<li>Consider enabling auto-installation for critical updates</li>
<li>Monitor system after updates for any issues</li>
</ul>
</div>"
    fi

    if [[ $important_count -gt 0 ]]; then
        html_content="$html_content
<div class=\"summary-box summary-warning\">
<h4>Important Security Updates Available</h4>
<ul>
<li>Schedule installation of $important_count important updates within 24 hours</li>
<li>Review update details before installation</li>
<li>Ensure system backups are current</li>
</ul>
</div>"
    fi

    if [[ $total_updates -eq 0 ]]; then
        html_content="$html_content
<div class=\"summary-box summary-success\">
<h4>System Security: Up to Date</h4>
<ul>
<li>No security updates currently available</li>
<li>System is running latest security patches</li>
<li>Continue regular update monitoring schedule</li>
</ul>
</div>"
    fi

    html_content="$html_content
</div>"
    
    # Generate the final HTML report
    generate_html_report "Package Management Report" "$html_content" "$report_file"
    
    # Clean up temp file
    rm -f "$temp_report"
    
    log_success "Package management report generated: $report_file"
    echo "$report_file"
}

# Comprehensive package management check
run_package_management() {
    local report_dir="${1:-$(get_config 'system.data_directory' '/var/log/bash-admin')}"
    local auto_install="${2:-$(get_config 'modules.package_management.auto_install_security' 'false')}"
    local today=$(date +%Y%m%d)
    
    mkdir -p "$report_dir"
    
    log_info "Running comprehensive package management check"
    
    local package_manager
    package_manager=$(detect_package_manager)
    if [[ $? -ne 0 ]]; then
        log_error "Failed to detect package manager"
        return 1
    fi
    
    local total_issues=0
    
    # Check for security updates
    local security_report="$report_dir/security_updates_$today.txt"
    check_security_updates "$package_manager" "$security_report"
    local updates_available=$?
    total_issues=$updates_available
    
    # Auto-install security updates if enabled
    if [[ "$auto_install" == "true" && $updates_available -gt 0 ]]; then
        log_info "Auto-installation is enabled, installing security updates"
        install_security_updates "$package_manager"
        local install_result=$?
        
        # Re-check after installation
        check_security_updates "$package_manager" "$security_report"
        updates_available=$?
        total_issues=$updates_available
    fi
    
    # Generate comprehensive HTML report
    generate_package_report "$report_dir/package_management_$today.html" "$package_manager"
    
    log_info "Package management check completed with $total_issues pending updates"
    return $total_issues
}

# Export functions for use by other scripts
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f detect_package_manager
    export -f update_package_cache
    export -f check_security_updates
    export -f create_system_snapshot
    export -f install_security_updates
    export -f generate_package_report
    export -f run_package_management
fi

# Main function for direct execution
main() {
    local action="${1:-check}"
    local target="${2:-}"
    
    case "$action" in
        "check"|"scan")
            check_security_updates "$(detect_package_manager)" "$target"
            ;;
        "install"|"update")
            install_security_updates "$(detect_package_manager)"
            ;;
        "snapshot")
            create_system_snapshot
            ;;
        "report")
            generate_package_report "$target"
            ;;
        "full"|"all")
            run_package_management
            ;;
        *)
            echo "Usage: $0 {check|install|snapshot|report|full} [target]"
            echo "  check:     Check for security updates"
            echo "  install:   Install security updates"
            echo "  snapshot:  Create system snapshot"
            echo "  report:    Generate HTML report"
            echo "  full:      Run complete package management"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi