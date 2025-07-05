#!/bin/bash

# System Report Generation Script
# Generates comprehensive system reports similar to PowerShell version

# Source the core library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../core/lib/init.sh"

# Initialize
init_bash_admin "$(basename "$0")"

# Generate system summary report
generate_system_summary() {
    log_info "Generating system summary report" "SYSTEM_REPORT"
    
    local report_data=""
    local hostname=$(hostname -f)
    local kernel=$(uname -r)
    local os_release=""
    
    # Get OS information
    if [[ -f /etc/os-release ]]; then
        os_release=$(grep "PRETTY_NAME" /etc/os-release | cut -d'"' -f2)
    elif [[ -f /etc/redhat-release ]]; then
        os_release=$(cat /etc/redhat-release)
    else
        os_release=$(uname -s)
    fi
    
    # System information
    report_data="<h2>System Overview</h2>
<table>
<tr><th>Hostname</th><td>$hostname</td></tr>
<tr><th>Operating System</th><td>$os_release</td></tr>
<tr><th>Kernel Version</th><td>$kernel</td></tr>
<tr><th>Architecture</th><td>$(uname -m)</td></tr>
<tr><th>Boot Time</th><td>$(who -b 2>/dev/null | awk '{print $3, $4}' || uptime -s 2>/dev/null || echo 'Unknown')</td></tr>
<tr><th>Current Time</th><td>$(date)</td></tr>
<tr><th>Timezone</th><td>$(timedatectl show --property=Timezone --value 2>/dev/null || date +%Z)</td></tr>
<tr><th>Uptime</th><td>$(uptime -p 2>/dev/null || uptime)</td></tr>
</table>"
    
    # CPU information
    local cpu_info=""
    if [[ -f /proc/cpuinfo ]]; then
        local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//')
        local cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
        cpu_info="<h2>CPU Information</h2>
<table>
<tr><th>Model</th><td>$cpu_model</td></tr>
<tr><th>Cores</th><td>$cpu_cores</td></tr>
<tr><th>Load Average</th><td>$(uptime | awk -F'load average:' '{print $2}')</td></tr>
</table>"
    fi
    
    # Memory information
    local mem_info=""
    if command -v free >/dev/null 2>&1; then
        local mem_total=$(free -h | grep "^Mem:" | awk '{print $2}')
        local mem_used=$(free -h | grep "^Mem:" | awk '{print $3}')
        local mem_available=$(free -h | grep "^Mem:" | awk '{print $7}')
        local swap_total=$(free -h | grep "^Swap:" | awk '{print $2}')
        local swap_used=$(free -h | grep "^Swap:" | awk '{print $3}')
        
        mem_info="<h2>Memory Information</h2>
<table>
<tr><th>Total RAM</th><td>$mem_total</td></tr>
<tr><th>Used RAM</th><td>$mem_used</td></tr>
<tr><th>Available RAM</th><td>$mem_available</td></tr>
<tr><th>Total Swap</th><td>$swap_total</td></tr>
<tr><th>Used Swap</th><td>$swap_used</td></tr>
</table>"
    fi
    
    # Disk information
    local disk_info="<h2>Disk Usage</h2>
<table>
<tr><th>Filesystem</th><th>Size</th><th>Used</th><th>Available</th><th>Use%</th><th>Mounted on</th></tr>"
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            disk_info="$disk_info
<tr><td>$(echo "$line" | awk '{print $1}')</td><td>$(echo "$line" | awk '{print $2}')</td><td>$(echo "$line" | awk '{print $3}')</td><td>$(echo "$line" | awk '{print $4}')</td><td>$(echo "$line" | awk '{print $5}')</td><td>$(echo "$line" | awk '{print $6}')</td></tr>"
        fi
    done < <(df -h | grep -E '^/dev/')
    
    disk_info="$disk_info</table>"
    
    # Network information
    local network_info="<h2>Network Interfaces</h2>
<table>
<tr><th>Interface</th><th>Status</th><th>IP Address</th></tr>"
    
    for interface in $(ls /sys/class/net/ | grep -v lo); do
        local status="Down"
        local ip_addr="N/A"
        
        if [[ -f "/sys/class/net/$interface/operstate" ]]; then
            local state=$(cat "/sys/class/net/$interface/operstate")
            if [[ "$state" == "up" ]]; then
                status="Up"
                ip_addr=$(ip addr show "$interface" | grep "inet " | head -1 | awk '{print $2}' | cut -d/ -f1)
            fi
        fi
        
        network_info="$network_info
<tr><td>$interface</td><td>$status</td><td>$ip_addr</td></tr>"
    done
    
    network_info="$network_info</table>"
    
    # Combine all sections
    echo "$report_data$cpu_info$mem_info$disk_info$network_info"
}

# Generate user activity report
generate_user_activity() {
    log_info "Generating user activity report" "SYSTEM_REPORT"
    
    local user_info="<h2>User Activity</h2>"
    
    # Currently logged in users
    user_info="$user_info
<h3>Currently Logged In Users</h3>
<table>
<tr><th>User</th><th>Terminal</th><th>Login Time</th><th>From</th></tr>"
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local user=$(echo "$line" | awk '{print $1}')
            local tty=$(echo "$line" | awk '{print $2}')
            local time=$(echo "$line" | awk '{print $3, $4, $5, $6}')
            local from=$(echo "$line" | awk '{print $7}')
            
            user_info="$user_info
<tr><td>$user</td><td>$tty</td><td>$time</td><td>$from</td></tr>"
        fi
    done < <(who 2>/dev/null)
    
    user_info="$user_info</table>"
    
    # Last login information
    user_info="$user_info
<h3>Recent Login History</h3>
<pre>$(last -10 2>/dev/null | head -10)</pre>"
    
    # User accounts summary
    local total_users=$(getent passwd | wc -l)
    local system_users=$(getent passwd | awk -F: '$3 < 1000 {print $1}' | wc -l)
    local regular_users=$(getent passwd | awk -F: '$3 >= 1000 {print $1}' | wc -l)
    
    user_info="$user_info
<h3>User Accounts Summary</h3>
<table>
<tr><th>Total Users</th><td>$total_users</td></tr>
<tr><th>System Users</th><td>$system_users</td></tr>
<tr><th>Regular Users</th><td>$regular_users</td></tr>
</table>"
    
    echo "$user_info"
}

# Generate service status report
generate_service_status() {
    log_info "Generating service status report" "SYSTEM_REPORT"
    
    local service_info="<h2>Service Status</h2>"
    
    # Get configured services to monitor
    local services
    services=$(get_config 'maintenance.services_to_monitor' 'sshd systemd-resolved cron')
    
    # Convert JSON array to space-separated if needed
    if [[ "$services" == *"["* ]]; then
        services=$(echo "$services" | jq -r '.[]' 2>/dev/null | tr '\n' ' ' || echo "sshd systemd-resolved cron")
    fi
    
    service_info="$service_info
<h3>Critical Services</h3>
<table>
<tr><th>Service</th><th>Status</th><th>Enabled</th><th>Uptime</th></tr>"
    
    for service in $services; do
        local status="Unknown"
        local enabled="Unknown"
        local uptime="N/A"
        
        if systemctl is-active "$service" >/dev/null 2>&1; then
            status="<span class=\"success\">Active</span>"
        else
            status="<span class=\"error\">Inactive</span>"
        fi
        
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            enabled="Yes"
        else
            enabled="No"
        fi
        
        # Get service uptime
        local start_time
        start_time=$(systemctl show "$service" --property=ActiveEnterTimestamp --value 2>/dev/null)
        if [[ -n "$start_time" ]] && [[ "$start_time" != "0" ]]; then
            uptime=$(date -d "$start_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Unknown")
        fi
        
        service_info="$service_info
<tr><td>$service</td><td>$status</td><td>$enabled</td><td>$uptime</td></tr>"
    done
    
    service_info="$service_info</table>"
    
    # Failed services
    local failed_services
    failed_services=$(systemctl list-units --failed --no-legend 2>/dev/null | head -10)
    
    if [[ -n "$failed_services" ]]; then
        service_info="$service_info
<h3>Failed Services</h3>
<pre>$failed_services</pre>"
    else
        service_info="$service_info
<h3>Failed Services</h3>
<p class=\"success\">No failed services found.</p>"
    fi
    
    echo "$service_info"
}

# Generate security summary
generate_security_summary() {
    log_info "Generating security summary" "SYSTEM_REPORT"
    
    local security_info="<h2>Security Summary</h2>"
    
    # SSH configuration check
    local ssh_status="Unknown"
    if systemctl is-active sshd >/dev/null 2>&1; then
        ssh_status="<span class=\"success\">Active</span>"
    else
        ssh_status="<span class=\"warning\">Inactive</span>"
    fi
    
    # Firewall status
    local firewall_status="Unknown"
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "Status: active"; then
            firewall_status="<span class=\"success\">UFW Active</span>"
        else
            firewall_status="<span class=\"warning\">UFW Inactive</span>"
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        if firewall-cmd --state >/dev/null 2>&1; then
            firewall_status="<span class=\"success\">FirewallD Active</span>"
        else
            firewall_status="<span class=\"warning\">FirewallD Inactive</span>"
        fi
    fi
    
    security_info="$security_info
<table>
<tr><th>SSH Service</th><td>$ssh_status</td></tr>
<tr><th>Firewall</th><td>$firewall_status</td></tr>
</table>"
    
    # Recent authentication failures
    local auth_failures=""
    if [[ -f /var/log/auth.log ]]; then
        auth_failures=$(grep "authentication failure" /var/log/auth.log 2>/dev/null | tail -5)
    elif [[ -f /var/log/secure ]]; then
        auth_failures=$(grep "authentication failure" /var/log/secure 2>/dev/null | tail -5)
    fi
    
    if [[ -n "$auth_failures" ]]; then
        security_info="$security_info
<h3>Recent Authentication Failures</h3>
<pre>$auth_failures</pre>"
    fi
    
    echo "$security_info"
}

# Main report generation function
main() {
    require_config "paths.report_dir"
    
    local report_dir=$(get_config 'paths.report_dir' '/tmp/bash-admin')
    local report_file="$report_dir/system-report-$(date '+%Y%m%d-%H%M%S').html"
    
    log_info "Generating comprehensive system report" "SYSTEM_REPORT"
    
    # Create report directory
    mkdir -p "$report_dir"
    
    # Generate all report sections
    local system_summary
    system_summary=$(generate_system_summary)
    
    local user_activity
    user_activity=$(generate_user_activity)
    
    local service_status
    service_status=$(generate_service_status)
    
    local security_summary
    security_summary=$(generate_security_summary)
    
    # Combine all sections
    local full_report="$system_summary$user_activity$service_status$security_summary"
    
    # Generate HTML report
    generate_html_report "Comprehensive System Report" "$full_report" "$report_file"
    
    log_success "System report generated: $report_file" "SYSTEM_REPORT"
    
    # Send notification and email if configured
    if [[ $(get_config 'notifications.enabled' 'true') == "true" ]]; then
        send_notification "INFO" "System Report Generated" "Comprehensive system report generated on $(hostname -f)" "SYSTEM_REPORT"
        
        if [[ $(get_config 'reporting.auto_email' 'true') == "true" ]]; then
            send_report "$report_file" "System Report - $(hostname -f)" "$(get_config 'email.recipients.operations')"
        fi
    fi
    
    echo "$report_file"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi