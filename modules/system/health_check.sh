#!/bin/bash

# System Health Check Module
# Performs comprehensive system health monitoring and reporting

# Source the core library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../core/lib/init.sh"

# Initialize
init_bash_admin "$(basename "$0")"

# Health check functions
check_disk_usage() {
    log_info "Checking disk usage" "HEALTH_CHECK"
    
    local threshold=$(get_config 'monitoring.disk_threshold' '90')
    local issues=()
    
    while IFS= read -r line; do
        local usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
        local mountpoint=$(echo "$line" | awk '{print $6}')
        
        if [[ "$usage" -gt "$threshold" ]]; then
            issues+=("$mountpoint: ${usage}% used (threshold: ${threshold}%)")
            log_warn "Disk usage high on $mountpoint: ${usage}%" "HEALTH_CHECK"
        fi
    done < <(df -h | grep -E '^/dev/' | grep -v '/boot')
    
    if [[ ${#issues[@]} -eq 0 ]]; then
        log_success "All disk usage within acceptable limits" "HEALTH_CHECK"
        return 0
    else
        log_error "Disk usage issues found: ${#issues[@]} filesystems" "HEALTH_CHECK"
        printf '%s\n' "${issues[@]}"
        return 1
    fi
}

check_memory_usage() {
    log_info "Checking memory usage" "HEALTH_CHECK"
    
    local threshold=$(get_config 'monitoring.memory_threshold' '85')
    
    # Get memory info
    local mem_info
    mem_info=$(free | grep '^Mem:')
    local total=$(echo "$mem_info" | awk '{print $2}')
    local used=$(echo "$mem_info" | awk '{print $3}')
    local usage=$((used * 100 / total))
    
    if [[ "$usage" -gt "$threshold" ]]; then
        log_warn "Memory usage high: ${usage}% (threshold: ${threshold}%)" "HEALTH_CHECK"
        return 1
    else
        log_success "Memory usage acceptable: ${usage}%" "HEALTH_CHECK"
        return 0
    fi
}

check_load_average() {
    log_info "Checking load average" "HEALTH_CHECK"
    
    local threshold=$(get_config 'monitoring.load_threshold' '5.0')
    local load_1min=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')
    
    # Compare using bc if available, otherwise use integer comparison
    if command -v bc >/dev/null 2>&1; then
        if (( $(echo "$load_1min > $threshold" | bc -l) )); then
            log_warn "Load average high: $load_1min (threshold: $threshold)" "HEALTH_CHECK"
            return 1
        fi
    else
        # Fallback to integer comparison
        local load_int=${load_1min%.*}
        local threshold_int=${threshold%.*}
        if [[ "$load_int" -gt "$threshold_int" ]]; then
            log_warn "Load average high: $load_1min (threshold: $threshold)" "HEALTH_CHECK"
            return 1
        fi
    fi
    
    log_success "Load average acceptable: $load_1min" "HEALTH_CHECK"
    return 0
}

check_critical_services() {
    log_info "Checking critical services" "HEALTH_CHECK"
    
    local services
    services=$(get_config 'maintenance.services_to_monitor' 'sshd systemd-resolved cron')
    local failed_services=()
    
    # Convert JSON array to space-separated if needed
    if [[ "$services" == *"["* ]]; then
        services=$(echo "$services" | jq -r '.[]' 2>/dev/null | tr '\n' ' ' || echo "sshd systemd-resolved cron")
    fi
    
    for service in $services; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            log_debug "Service $service is running" "HEALTH_CHECK"
        else
            failed_services+=("$service")
            log_error "Service $service is not running" "HEALTH_CHECK"
        fi
    done
    
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        log_success "All critical services are running" "HEALTH_CHECK"
        return 0
    else
        log_error "Failed services: ${failed_services[*]}" "HEALTH_CHECK"
        return 1
    fi
}

check_network_connectivity() {
    log_info "Checking network connectivity" "HEALTH_CHECK"
    
    local test_hosts=("8.8.8.8" "1.1.1.1")
    local failed_hosts=()
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 5 "$host" >/dev/null 2>&1; then
            log_debug "Network connectivity to $host: OK" "HEALTH_CHECK"
        else
            failed_hosts+=("$host")
            log_warn "Network connectivity to $host: FAILED" "HEALTH_CHECK"
        fi
    done
    
    if [[ ${#failed_hosts[@]} -eq 0 ]]; then
        log_success "Network connectivity check passed" "HEALTH_CHECK"
        return 0
    else
        log_error "Network connectivity issues with: ${failed_hosts[*]}" "HEALTH_CHECK"
        return 1
    fi
}

generate_health_report() {
    log_info "Generating health report" "HEALTH_CHECK"
    
    local report_dir=$(get_config 'paths.report_dir' '/tmp/bash-admin')
    local report_file="$report_dir/health-check-$(date '+%Y%m%d-%H%M%S').html"
    
    # Create report directory
    mkdir -p "$report_dir"
    
    # Collect system information
    local hostname=$(hostname -f)
    local kernel=$(uname -r)
    local uptime=$(uptime -p 2>/dev/null || uptime)
    local load=$(uptime | awk -F'load average:' '{print $2}')
    local memory=$(free -h | grep '^Mem:')
    local disk_info=$(df -h | grep -E '^/dev/')
    
    # Generate HTML report
    local html_data="
<h2>System Information</h2>
<table>
<tr><th>Hostname</th><td>$hostname</td></tr>
<tr><th>Kernel</th><td>$kernel</td></tr>
<tr><th>Uptime</th><td>$uptime</td></tr>
<tr><th>Load Average</th><td>$load</td></tr>
</table>

<h2>Memory Usage</h2>
<pre>$memory</pre>

<h2>Disk Usage</h2>
<table>
<tr><th>Filesystem</th><th>Size</th><th>Used</th><th>Available</th><th>Use%</th><th>Mounted on</th></tr>"

    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            html_data="$html_data
<tr><td>$(echo "$line" | awk '{print $1}')</td><td>$(echo "$line" | awk '{print $2}')</td><td>$(echo "$line" | awk '{print $3}')</td><td>$(echo "$line" | awk '{print $4}')</td><td>$(echo "$line" | awk '{print $5}')</td><td>$(echo "$line" | awk '{print $6}')</td></tr>"
        fi
    done <<< "$disk_info"
    
    html_data="$html_data
</table>

<h2>Health Check Results</h2>
<ul>
<li class=\"$(check_disk_usage >/dev/null 2>&1 && echo 'success' || echo 'error')\">Disk Usage Check</li>
<li class=\"$(check_memory_usage >/dev/null 2>&1 && echo 'success' || echo 'error')\">Memory Usage Check</li>
<li class=\"$(check_load_average >/dev/null 2>&1 && echo 'success' || echo 'error')\">Load Average Check</li>
<li class=\"$(check_critical_services >/dev/null 2>&1 && echo 'success' || echo 'error')\">Critical Services Check</li>
<li class=\"$(check_network_connectivity >/dev/null 2>&1 && echo 'success' || echo 'error')\">Network Connectivity Check</li>
</ul>"
    
    generate_html_report "System Health Check Report" "$html_data" "$report_file"
    
    echo "$report_file"
}

# Main function
main() {
    log_info "Starting system health check" "HEALTH_CHECK"
    
    local exit_code=0
    local checks=("check_disk_usage" "check_memory_usage" "check_load_average" "check_critical_services" "check_network_connectivity")
    local failed_checks=()
    
    # Run all health checks
    for check in "${checks[@]}"; do
        if ! $check; then
            failed_checks+=("$check")
            exit_code=1
        fi
    done
    
    # Generate report
    local report_file
    report_file=$(generate_health_report)
    
    # Send notification if configured
    if [[ $(get_config 'notifications.enabled' 'true') == "true" ]]; then
        local level="INFO"
        local title="System Health Check"
        local message="Health check completed on $(hostname -f)"
        
        if [[ $exit_code -ne 0 ]]; then
            level="WARNING"
            title="System Health Issues Detected"
            message="Health check found ${#failed_checks[@]} issues: ${failed_checks[*]}"
        fi
        
        send_notification "$level" "$title" "$message" "HEALTH_CHECK"
        
        # Send report via email if enabled
        if [[ $(get_config 'reporting.auto_email' 'true') == "true" ]]; then
            send_report "$report_file" "[$level] $title" "$(get_config 'email.recipients.operations')"
        fi
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "System health check completed successfully" "HEALTH_CHECK"
    else
        log_error "System health check completed with ${#failed_checks[@]} issues" "HEALTH_CHECK"
    fi
    
    exit $exit_code
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi