#!/bin/bash
# Service Management Module
# Provides functions for SystemD service monitoring and management

# Source core libraries
source "$(dirname "$0")/../../core/lib/init.sh"

# Monitor critical services and return status
monitor_critical_services() {
    local config_services="${1:-}"
    local report_file="${2:-/tmp/service_status_$(date +%Y%m%d).txt}"
    local failed_services=()
    local successful_services=()
    local services_list
    
    log_info "Monitoring critical services"
    
    # Get services from config or use default
    if [[ -n "$config_services" ]]; then
        services_list="$config_services"
    else
        services_list=$(get_config 'modules.service_management.critical_services' 'sshd systemd-resolved cron NetworkManager')
    fi
    
    # Convert JSON array to space-separated if needed
    if [[ "$services_list" == *"["* ]]; then
        services_list=$(echo "$services_list" | jq -r '.[]' 2>/dev/null | tr '\n' ' ' || echo "sshd systemd-resolved cron NetworkManager")
    fi
    
    log_debug "Checking services: $services_list"
    
    for service in $services_list; do
        log_debug "Checking service: $service"
        
        if systemctl is-active "$service" >/dev/null 2>&1; then
            successful_services+=("$service")
            log_success "Service $service is running"
        else
            failed_services+=("$service")
            log_error "Service $service is not running"
            
            # Get service status for detailed logging
            local status_info
            status_info=$(systemctl status "$service" --no-pager -l 2>/dev/null | head -10)
            log_debug "Service $service status: $status_info"
        fi
    done    
    # Generate status report
    {
        echo "Service Status Report - $(date)"
        echo "================================"
        echo
        echo "RUNNING SERVICES:"
        if [[ ${#successful_services[@]} -eq 0 ]]; then
            echo "  None"
        else
            printf "  %s\n" "${successful_services[@]}"
        fi
        echo
        echo "FAILED SERVICES:"
        if [[ ${#failed_services[@]} -eq 0 ]]; then
            echo "  None"
        else
            printf "  %s\n" "${failed_services[@]}"
        fi
        echo
        echo "SUMMARY:"
        echo "  Total Services: $((${#successful_services[@]} + ${#failed_services[@]}))"
        echo "  Running: ${#successful_services[@]}"
        echo "  Failed: ${#failed_services[@]}"
    } > "$report_file"
    
    log_info "Service status report generated: $report_file"
    
    # Send notification if failures detected
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        send_notification "admin" "Service Failures Detected" \
            "Found ${#failed_services[@]} failed services: ${failed_services[*]}. Check $report_file for details."
    fi
    
    return ${#failed_services[@]}
}

# Restart failed services with exponential backoff
restart_failed_services() {
    local services_to_restart="${1:-}"
    local max_attempts="${2:-$(get_config 'modules.service_management.max_restart_attempts' '3')}"
    local base_delay="${3:-$(get_config 'modules.service_management.restart_delay_seconds' '30')}"
    local auto_restart_enabled="${4:-$(get_config 'modules.service_management.auto_restart' 'true')}"
    local restart_results=()
    local successful_restarts=()
    local failed_restarts=()    
    log_info "Starting service restart process"
    
    # Check if auto-restart is enabled
    if [[ "$auto_restart_enabled" != "true" ]]; then
        log_warn "Auto-restart is disabled in configuration"
        return 0
    fi
    
    # If no specific services provided, check for failed services
    if [[ -z "$services_to_restart" ]]; then
        local temp_report="/tmp/service_check_temp_$(date +%s).txt"
        monitor_critical_services "" "$temp_report" >/dev/null 2>&1
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            log_info "No failed services found to restart"
            return 0
        fi
        
        # Extract failed services from the temp report
        services_to_restart=$(grep -A 100 "FAILED SERVICES:" "$temp_report" | \
                             grep -B 100 "SUMMARY:" | \
                             grep "^  " | grep -v "None" | sed 's/^  //' | tr '\n' ' ')
        rm -f "$temp_report"
    fi
    
    log_info "Services to restart: $services_to_restart"
    
    for service in $services_to_restart; do
        log_info "Attempting to restart service: $service"
        local attempt=1
        local restart_successful=false
        
        while [[ $attempt -le $max_attempts ]]; do
            log_debug "Restart attempt $attempt/$max_attempts for $service"
            
            if systemctl restart "$service" >/dev/null 2>&1; then
                # Wait a moment and verify service is actually running
                sleep 5
                if systemctl is-active "$service" >/dev/null 2>&1; then
                    log_success "Service $service restarted successfully on attempt $attempt"
                    successful_restarts+=("$service")
                    restart_successful=true
                    break
                else
                    log_warn "Service $service restart command succeeded but service not running"
                fi
            else
                log_warn "Failed to restart $service on attempt $attempt"
            fi
            
            # Exponential backoff delay
            if [[ $attempt -lt $max_attempts ]]; then
                local delay=$((base_delay * attempt * attempt))
                log_debug "Waiting ${delay}s before next restart attempt for $service"
                sleep "$delay"
            fi
            
            ((attempt++))
        done
        
        if [[ "$restart_successful" != "true" ]]; then
            failed_restarts+=("$service")
            log_error "Failed to restart $service after $max_attempts attempts"
        fi
    done
    
    # Log summary
    if [[ ${#successful_restarts[@]} -gt 0 ]]; then
        log_success "Successfully restarted services: ${successful_restarts[*]}"
    fi
    
    if [[ ${#failed_restarts[@]} -gt 0 ]]; then
        log_error "Failed to restart services: ${failed_restarts[*]}"
        send_notification "admin" "Service Restart Failures" \
            "Failed to restart ${#failed_restarts[@]} services: ${failed_restarts[*]}. Manual intervention required."
    fi
    
    return ${#failed_restarts[@]}
}
# Analyze service dependencies and relationships
analyze_service_dependencies() {
    local target_service="${1:-}"
    local report_file="${2:-/tmp/service_dependencies_$(date +%Y%m%d).txt}"
    local dependency_map=()
    local circular_deps=()
    
    log_info "Analyzing service dependencies"
    
    if [[ -n "$target_service" ]]; then
        log_debug "Analyzing dependencies for specific service: $target_service"
        services_to_analyze="$target_service"
    else
        # Get critical services from config
        local services_list
        services_list=$(get_config 'modules.service_management.critical_services' 'sshd systemd-resolved cron NetworkManager')
        
        # Convert JSON array to space-separated if needed
        if [[ "$services_list" == *"["* ]]; then
            services_to_analyze=$(echo "$services_list" | jq -r '.[]' 2>/dev/null | tr '\n' ' ' || echo "sshd systemd-resolved cron NetworkManager")
        else
            services_to_analyze="$services_list"
        fi
    fi
    
    {
        echo "Service Dependencies Analysis - $(date)"
        echo "======================================="
        echo
        
        for service in $services_to_analyze; do
            echo "SERVICE: $service"
            echo "-------------------"
            
            # Check if service exists
            if ! systemctl list-unit-files "$service.service" >/dev/null 2>&1; then
                echo "  Status: Service not found"
                echo
                continue
            fi
            
            # Get service status
            local status
            if systemctl is-active "$service" >/dev/null 2>&1; then
                status="ACTIVE"
            else
                status="INACTIVE"
            fi
            echo "  Status: $status"
            
            # Get dependencies (what this service requires)
            echo "  Requires:"
            local requires
            requires=$(systemctl show "$service" --property=Requires --value 2>/dev/null)
            if [[ -n "$requires" && "$requires" != " " ]]; then
                echo "    $requires" | tr ' ' '\n' | sed 's/^/    /'
            else
                echo "    None"
            fi
            
            # Get what requires this service (reverse dependencies)
            echo "  Required by:"
            local required_by
            required_by=$(systemctl show "$service" --property=RequiredBy --value 2>/dev/null)
            if [[ -n "$required_by" && "$required_by" != " " ]]; then
                echo "    $required_by" | tr ' ' '\n' | sed 's/^/    /'
            else
                echo "    None"
            fi
            
            # Get wants relationships
            echo "  Wants:"
            local wants
            wants=$(systemctl show "$service" --property=Wants --value 2>/dev/null)
            if [[ -n "$wants" && "$wants" != " " ]]; then
                echo "    $wants" | tr ' ' '\n' | sed 's/^/    /'
            else
                echo "    None"
            fi
            
            echo
        done
        
    } > "$report_file"
    
    log_info "Service dependencies analysis generated: $report_file"
    return 0
}# Generate comprehensive HTML service report
generate_service_report() {
    local report_file="${1:-/tmp/service_report_$(date +%Y%m%d_%H%M%S).html}"
    local include_dependencies="${2:-true}"
    
    log_info "Generating comprehensive service report"
    
    # Get services list
    local services_list
    services_list=$(get_config 'modules.service_management.critical_services' 'sshd systemd-resolved cron NetworkManager')
    
    # Convert JSON array to space-separated if needed
    if [[ "$services_list" == *"["* ]]; then
        services_list=$(echo "$services_list" | jq -r '.[]' 2>/dev/null | tr '\n' ' ' || echo "sshd systemd-resolved cron NetworkManager")
    fi
    
    # Collect service status data
    local service_data=""
    local total_services=0
    local running_services=0
    local failed_services=0
    
    for service in $services_list; do
        ((total_services++))
        
        local status_class="error"
        local status_text="FAILED"
        local uptime_info=""
        local memory_info=""
        
        if systemctl is-active "$service" >/dev/null 2>&1; then
            ((running_services++))
            status_class="success"
            status_text="RUNNING"
            
            # Get additional info for running services
            local since_info
            since_info=$(systemctl show "$service" --property=ActiveEnterTimestamp --value 2>/dev/null)
            if [[ -n "$since_info" && "$since_info" != "n/a" ]]; then
                uptime_info="Since: $since_info"
            fi
            
            # Get memory usage if available
            local main_pid
            main_pid=$(systemctl show "$service" --property=MainPID --value 2>/dev/null)
            if [[ -n "$main_pid" && "$main_pid" != "0" ]]; then
                memory_info=$(ps -p "$main_pid" -o rss= 2>/dev/null | awk '{printf "%.1fMB", $1/1024}')
            fi
        else
            ((failed_services++))
        fi
        
        service_data="$service_data
<tr class=\"$status_class\">
<td>$service</td>
<td><span class=\"status-$status_class\">$status_text</span></td>
<td>$uptime_info</td>
<td>$memory_info</td>
</tr>"
    done
    
    # Generate HTML report
    local html_content="
<h2>Service Management Status</h2>
<div class=\"summary-stats\">
    <div class=\"stat-box\">
        <div class=\"stat-number\">$total_services</div>
        <div class=\"stat-label\">Total Services</div>
    </div>
    <div class=\"stat-box\">
        <div class=\"stat-number\">$running_services</div>
        <div class=\"stat-label\">Running</div>
    </div>
    <div class=\"stat-box\">
        <div class=\"stat-number\">$failed_services</div>
        <div class=\"stat-label\">Failed</div>
    </div>
</div>

<h3>Service Status Details</h3>
<table class=\"service-table\">
<thead>
<tr>
<th>Service Name</th>
<th>Status</th>
<th>Start Time</th>
<th>Memory Usage</th>
</tr>
</thead>
<tbody>$service_data
</tbody>
</table>"
    
    # Add dependency information if requested
    if [[ "$include_dependencies" == "true" ]]; then
        html_content="$html_content

<h3>Service Dependencies</h3>
<div class=\"dependencies-info\">
<p>Dependency analysis helps understand service relationships and restart order.</p>
<ul>"
        
        for service in $services_list; do
            if systemctl list-unit-files "$service.service" >/dev/null 2>&1; then
                local requires
                requires=$(systemctl show "$service" --property=Requires --value 2>/dev/null | wc -w)
                local required_by
                required_by=$(systemctl show "$service" --property=RequiredBy --value 2>/dev/null | wc -w)
                
                html_content="$html_content
<li><strong>$service</strong>: Requires $requires services, Required by $required_by services</li>"
            fi
        done
        
        html_content="$html_content
</ul>
</div>"
    fi
    
    # Generate the final HTML report
    generate_html_report "Service Management Report" "$html_content" "$report_file"
    
    log_success "Service management report generated: $report_file"
    echo "$report_file"
}# Comprehensive service management check
run_service_management() {
    local report_dir="${1:-$(get_config 'system.data_directory' '/var/log/bash-admin')}"
    local auto_restart="${2:-$(get_config 'modules.service_management.auto_restart' 'true')}"
    local today=$(date +%Y%m%d)
    
    mkdir -p "$report_dir"
    
    log_info "Running comprehensive service management check"
    
    local total_issues=0
    
    # Monitor critical services
    local service_report="$report_dir/service_status_$today.txt"
    monitor_critical_services "" "$service_report"
    local failed_count=$?
    total_issues=$((total_issues + failed_count))
    
    # Auto-restart failed services if enabled
    if [[ "$auto_restart" == "true" && $failed_count -gt 0 ]]; then
        log_info "Auto-restart is enabled, attempting to restart failed services"
        restart_failed_services
        local restart_failures=$?
        
        # Re-check services after restart attempts
        monitor_critical_services "" "$service_report"
        failed_count=$?
        total_issues=$failed_count
    fi
    
    # Generate dependency analysis
    analyze_service_dependencies "" "$report_dir/service_dependencies_$today.txt"
    
    # Generate comprehensive HTML report
    generate_service_report "$report_dir/service_management_$today.html" "true"
    
    log_info "Service management check completed with $total_issues issues"
    return $total_issues
}

# Export functions for use by other scripts
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f monitor_critical_services
    export -f restart_failed_services
    export -f analyze_service_dependencies
    export -f generate_service_report
    export -f run_service_management
fi

# Main function for direct execution
main() {
    local action="${1:-check}"
    local target="${2:-}"
    
    case "$action" in
        "check"|"monitor")
            monitor_critical_services "$target"
            ;;
        "restart")
            restart_failed_services "$target"
            ;;
        "dependencies"|"deps")
            analyze_service_dependencies "$target"
            ;;
        "report")
            generate_service_report "$target"
            ;;
        "full"|"all")
            run_service_management
            ;;
        *)
            echo "Usage: $0 {check|restart|dependencies|report|full} [target]"
            echo "  check:        Monitor critical services"
            echo "  restart:      Restart failed services"
            echo "  dependencies: Analyze service dependencies"
            echo "  report:       Generate HTML report"
            echo "  full:         Run complete service management"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi