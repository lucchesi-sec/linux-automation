#!/bin/bash
# Process Management Module
# Provides functions for system resource monitoring and process optimization

# Source core libraries
source "$(dirname "$0")/../../core/lib/init.sh"

# Get comprehensive system resource usage
get_system_resource_usage() {
    local report_file="${1:-/tmp/system_resources_$(date +%Y%m%d).txt}"
    local cpu_info memory_info disk_info network_info load_info
    
    log_info "Collecting system resource usage"
    
    # CPU Usage from /proc/stat
    local cpu_line
    cpu_line=$(grep "^cpu " /proc/stat 2>/dev/null || echo "cpu 0 0 0 0 0 0 0 0")
    local cpu_values=($cpu_line)
    local user=${cpu_values[1]}
    local nice=${cpu_values[2]}
    local system=${cpu_values[3]}
    local idle=${cpu_values[4]}
    local iowait=${cpu_values[5]:-0}
    local irq=${cpu_values[6]:-0}
    local softirq=${cpu_values[7]:-0}
    
    local total_cpu=$((user + nice + system + idle + iowait + irq + softirq))
    local cpu_usage_percent=0
    if [[ $total_cpu -gt 0 ]]; then
        cpu_usage_percent=$(( (total_cpu - idle) * 100 / total_cpu ))
    fi
    
    # Memory usage from /proc/meminfo
    local mem_total mem_free mem_available mem_cached mem_buffers
    mem_total=$(grep "^MemTotal:" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    mem_free=$(grep "^MemFree:" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    mem_available=$(grep "^MemAvailable:" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "$mem_free")
    mem_cached=$(grep "^Cached:" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    mem_buffers=$(grep "^Buffers:" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    
    local mem_used=$((mem_total - mem_available))
    local mem_usage_percent=0
    if [[ $mem_total -gt 0 ]]; then
        mem_usage_percent=$((mem_used * 100 / mem_total))
    fi
    
    # Load average
    local load_avg
    load_avg=$(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}' || echo "0.00 0.00 0.00")
    
    # Process count
    local process_count
    process_count=$(ps aux 2>/dev/null | wc -l || echo "0")
    process_count=$((process_count - 1)) # Subtract header line
    
    # Disk usage for root filesystem
    local disk_usage_percent disk_usage_info
    disk_usage_info=$(df / 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//' || echo "0")
    disk_usage_percent=${disk_usage_info:-0}
    
    # Network connections count
    local network_connections
    if command -v ss >/dev/null 2>&1; then
        network_connections=$(ss -tuln 2>/dev/null | wc -l || echo "0")
    elif command -v netstat >/dev/null 2>&1; then
        network_connections=$(netstat -tuln 2>/dev/null | wc -l || echo "0")
    else
        network_connections="N/A"
    fi
    
    # Generate resource usage report
    {
        echo "System Resource Usage Report - $(date)"
        echo "====================================="
        echo
        echo "CPU METRICS:"
        echo "  CPU Usage: ${cpu_usage_percent}%"
        echo "  Load Average: $load_avg"
        echo "  CPU Time Distribution:"
        echo "    User: $user"
        echo "    System: $system" 
        echo "    Idle: $idle"
        echo "    I/O Wait: $iowait"
        echo
        echo "MEMORY METRICS:"
        echo "  Memory Usage: ${mem_usage_percent}%"
        echo "  Total Memory: $(( mem_total / 1024 )) MB"
        echo "  Used Memory: $(( mem_used / 1024 )) MB"
        echo "  Available Memory: $(( mem_available / 1024 )) MB"
        echo "  Cached: $(( mem_cached / 1024 )) MB"
        echo "  Buffers: $(( mem_buffers / 1024 )) MB"
        echo
        echo "SYSTEM METRICS:"
        echo "  Disk Usage (/): ${disk_usage_percent}%"
        echo "  Process Count: $process_count"
        echo "  Network Connections: $network_connections"
        echo
        echo "THRESHOLDS:"
        local cpu_threshold=$(get_config 'modules.process_management.cpu_threshold_warning' '80')
        local mem_threshold=$(get_config 'modules.process_management.memory_threshold_warning' '85')
        local disk_threshold=$(get_config 'modules.process_management.disk_threshold_warning' '90')
        echo "  CPU Warning Threshold: ${cpu_threshold}%"
        echo "  Memory Warning Threshold: ${mem_threshold}%"
        echo "  Disk Warning Threshold: ${disk_threshold}%"
        echo
        echo "ALERTS:"
        if [[ $cpu_usage_percent -gt $cpu_threshold ]]; then
            echo "  ⚠️  HIGH CPU USAGE: ${cpu_usage_percent}% (threshold: ${cpu_threshold}%)"
        fi
        if [[ $mem_usage_percent -gt $mem_threshold ]]; then
            echo "  ⚠️  HIGH MEMORY USAGE: ${mem_usage_percent}% (threshold: ${mem_threshold}%)"
        fi
        if [[ $disk_usage_percent -gt $disk_threshold ]]; then
            echo "  ⚠️  HIGH DISK USAGE: ${disk_usage_percent}% (threshold: ${disk_threshold}%)"
        fi
        
        if [[ $cpu_usage_percent -le $cpu_threshold && $mem_usage_percent -le $mem_threshold && $disk_usage_percent -le $disk_threshold ]]; then
            echo "  ✅ All resource usage within normal limits"
        fi
        
    } > "$report_file"
    
    log_info "System resource usage report generated: $report_file"
    
    # Return number of alerts (for exit code)
    local alert_count=0
    [[ $cpu_usage_percent -gt $cpu_threshold ]] && ((alert_count++))
    [[ $mem_usage_percent -gt $mem_threshold ]] && ((alert_count++))
    [[ $disk_usage_percent -gt $disk_threshold ]] && ((alert_count++))
    
    # Send notification if any thresholds exceeded
    if [[ $alert_count -gt 0 ]]; then
        send_notification "admin" "Resource Usage Alert" \
            "System resource usage exceeded thresholds: CPU: ${cpu_usage_percent}%, Memory: ${mem_usage_percent}%, Disk: ${disk_usage_percent}%. Check $report_file for details."
    fi
    
    return $alert_count
}

# Monitor high resource consuming processes
monitor_high_resource_processes() {
    local report_file="${1:-/tmp/high_resource_processes_$(date +%Y%m%d).txt}"
    local process_limit="${2:-$(get_config 'modules.process_management.high_resource_processes' '10')}"
    local cpu_threshold="${3:-$(get_config 'modules.process_management.process_cpu_threshold' '10')}"
    local mem_threshold="${4:-$(get_config 'modules.process_management.process_memory_threshold' '5')}"
    
    log_info "Monitoring high resource consuming processes"
    
    local high_cpu_processes=()
    local high_mem_processes=()
    local suspicious_processes=()
    
    # Get process information sorted by CPU usage
    local cpu_processes
    cpu_processes=$(ps aux --sort=-%cpu 2>/dev/null | head -n $((process_limit + 1)) | tail -n +2 || echo "")
    
    # Get process information sorted by memory usage  
    local mem_processes
    mem_processes=$(ps aux --sort=-%mem 2>/dev/null | head -n $((process_limit + 1)) | tail -n +2 || echo "")
    
    {
        echo "High Resource Process Report - $(date)"
        echo "===================================="
        echo
        echo "TOP CPU CONSUMING PROCESSES:"
        echo "USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND"
        echo "$cpu_processes"
        echo
        echo "TOP MEMORY CONSUMING PROCESSES:"
        echo "USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND"
        echo "$mem_processes"
        echo
        
        # Analyze for suspicious processes
        echo "PROCESS ANALYSIS:"
        local alert_count=0
        
        # Check for high CPU processes
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local cpu_usage
                cpu_usage=$(echo "$line" | awk '{print $3}' | cut -d'.' -f1)
                local command
                command=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}')
                
                if [[ $cpu_usage -gt $cpu_threshold ]]; then
                    high_cpu_processes+=("$line")
                    echo "  ⚠️  HIGH CPU: $command (${cpu_usage}%)"
                    ((alert_count++))
                fi
            fi
        done <<< "$cpu_processes"
        
        # Check for high memory processes
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local mem_usage
                mem_usage=$(echo "$line" | awk '{print $4}' | cut -d'.' -f1)
                local command
                command=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}')
                
                if [[ $mem_usage -gt $mem_threshold ]]; then
                    high_mem_processes+=("$line")
                    echo "  ⚠️  HIGH MEMORY: $command (${mem_usage}%)"
                    ((alert_count++))
                fi
            fi
        done <<< "$mem_processes"
        
        if [[ $alert_count -eq 0 ]]; then
            echo "  ✅ No processes exceeding resource thresholds"
        fi
        
        echo
        echo "SUMMARY:"
        echo "  High CPU Processes: ${#high_cpu_processes[@]}"
        echo "  High Memory Processes: ${#high_mem_processes[@]}"
        echo "  Total Alerts: $alert_count"
        
    } > "$report_file"
    
    log_info "High resource process report generated: $report_file"
    
    # Send notification if high resource processes found
    if [[ $alert_count -gt 0 ]]; then
        send_notification "admin" "High Resource Process Alert" \
            "Found $alert_count processes exceeding resource thresholds. Check $report_file for details."
    fi
    
    return $alert_count
}

# Check for zombie processes and process anomalies
check_zombie_processes() {
    local report_file="${1:-/tmp/zombie_processes_$(date +%Y%m%d).txt}"
    local auto_cleanup="${2:-$(get_config 'modules.process_management.auto_kill_zombies' 'false')}"
    
    log_info "Checking for zombie processes and anomalies"
    
    local zombie_processes=()
    local defunct_processes=()
    local long_running_processes=()
    
    # Find zombie processes
    local zombie_pids
    zombie_pids=$(ps aux 2>/dev/null | awk '$8 ~ /^Z/ {print $2}' || echo "")
    
    # Find defunct processes
    local defunct_pids
    defunct_pids=$(ps aux 2>/dev/null | grep -i defunct | grep -v grep | awk '{print $2}' || echo "")
    
    # Find processes running for more than 24 hours with high CPU
    local long_running
    long_running=$(ps aux 2>/dev/null | awk '$10 ~ /[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/ && $3 > 1 {print $0}' || echo "")
    
    {
        echo "Zombie Process and Anomaly Report - $(date)"
        echo "==========================================="
        echo
        echo "ZOMBIE PROCESSES:"
        if [[ -n "$zombie_pids" && "$zombie_pids" != " " ]]; then
            while IFS= read -r pid; do
                if [[ -n "$pid" ]]; then
                    local zombie_info
                    zombie_info=$(ps -p "$pid" -o pid,ppid,user,stat,command 2>/dev/null || echo "PID not found")
                    zombie_processes+=("$zombie_info")
                    echo "  PID: $pid - $zombie_info"
                fi
            done <<< "$zombie_pids"
        else
            echo "  ✅ No zombie processes found"
        fi
        
        echo
        echo "DEFUNCT PROCESSES:"
        if [[ -n "$defunct_pids" && "$defunct_pids" != " " ]]; then
            while IFS= read -r pid; do
                if [[ -n "$pid" ]]; then
                    local defunct_info
                    defunct_info=$(ps -p "$pid" -o pid,ppid,user,stat,command 2>/dev/null || echo "PID not found")
                    defunct_processes+=("$defunct_info")
                    echo "  PID: $pid - $defunct_info"
                fi
            done <<< "$defunct_pids"
        else
            echo "  ✅ No defunct processes found"
        fi
        
        echo
        echo "LONG-RUNNING HIGH CPU PROCESSES:"
        if [[ -n "$long_running" ]]; then
            echo "$long_running"
            while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    long_running_processes+=("$line")
                fi
            done <<< "$long_running"
        else
            echo "  ✅ No suspicious long-running processes found"
        fi
        
        echo
        echo "PROCESS STATE SUMMARY:"
        local total_processes running_processes sleeping_processes stopped_processes
        total_processes=$(ps aux 2>/dev/null | wc -l || echo "1")
        total_processes=$((total_processes - 1)) # Subtract header
        
        running_processes=$(ps aux 2>/dev/null | awk '$8 ~ /^R/ {count++} END {print count+0}' || echo "0")
        sleeping_processes=$(ps aux 2>/dev/null | awk '$8 ~ /^S/ {count++} END {print count+0}' || echo "0")
        stopped_processes=$(ps aux 2>/dev/null | awk '$8 ~ /^T/ {count++} END {print count+0}' || echo "0")
        
        echo "  Total Processes: $total_processes"
        echo "  Running: $running_processes"
        echo "  Sleeping: $sleeping_processes"
        echo "  Stopped: $stopped_processes"
        echo "  Zombie: ${#zombie_processes[@]}"
        echo "  Defunct: ${#defunct_processes[@]}"
        
        echo
        echo "RECOMMENDATIONS:"
        if [[ ${#zombie_processes[@]} -gt 0 ]]; then
            echo "  ⚠️  $((${#zombie_processes[@]})) zombie processes detected"
            echo "     - Zombie processes should be cleaned up by their parent processes"
            echo "     - Consider restarting parent processes if zombies persist"
            if [[ "$auto_cleanup" == "true" ]]; then
                echo "     - Auto-cleanup is enabled but zombies require parent process handling"
            fi
        fi
        
        if [[ ${#long_running_processes[@]} -gt 0 ]]; then
            echo "  ⚠️  ${#long_running_processes[@]} long-running high CPU processes detected"
            echo "     - Review if these processes should be consuming high CPU for extended periods"
            echo "     - Consider process optimization or resource limits"
        fi
        
        if [[ ${#zombie_processes[@]} -eq 0 && ${#defunct_processes[@]} -eq 0 && ${#long_running_processes[@]} -eq 0 ]]; then
            echo "  ✅ Process health looks good - no anomalies detected"
        fi
        
    } > "$report_file"
    
    log_info "Zombie process and anomaly report generated: $report_file"
    
    # Calculate total anomalies
    local total_anomalies=$((${#zombie_processes[@]} + ${#defunct_processes[@]} + ${#long_running_processes[@]}))
    
    # Send notification if anomalies found
    if [[ $total_anomalies -gt 0 ]]; then
        send_notification "admin" "Process Anomaly Alert" \
            "Found $total_anomalies process anomalies: ${#zombie_processes[@]} zombies, ${#defunct_processes[@]} defunct, ${#long_running_processes[@]} long-running high CPU. Check $report_file for details."
    fi
    
    return $total_anomalies
}

# Generate optimization recommendations based on system analysis
generate_process_recommendations() {
    local report_file="${1:-/tmp/process_recommendations_$(date +%Y%m%d).txt}"
    
    log_info "Generating process optimization recommendations"
    
    # Gather current system metrics
    local cpu_usage mem_usage disk_usage load_avg process_count
    
    # Get CPU usage
    local cpu_line
    cpu_line=$(grep "^cpu " /proc/stat 2>/dev/null || echo "cpu 0 0 0 0 0 0 0 0")
    local cpu_values=($cpu_line)
    local total_cpu=$((${cpu_values[1]} + ${cpu_values[2]} + ${cpu_values[3]} + ${cpu_values[4]} + ${cpu_values[5]:-0} + ${cpu_values[6]:-0} + ${cpu_values[7]:-0}))
    cpu_usage=$(( (total_cpu - ${cpu_values[4]}) * 100 / total_cpu ))
    
    # Get memory usage
    local mem_total mem_available
    mem_total=$(grep "^MemTotal:" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "1")
    mem_available=$(grep "^MemAvailable:" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "1")
    mem_usage=$(( (mem_total - mem_available) * 100 / mem_total ))
    
    # Get disk usage
    disk_usage=$(df / 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//' || echo "0")
    
    # Get load average
    load_avg=$(cat /proc/loadavg 2>/dev/null | awk '{print $1}' || echo "0")
    
    # Get process count
    process_count=$(ps aux 2>/dev/null | wc -l || echo "1")
    process_count=$((process_count - 1))
    
    # CPU core count for load analysis
    local cpu_cores
    cpu_cores=$(nproc 2>/dev/null || echo "1")
    
    {
        echo "Process Optimization Recommendations - $(date)"
        echo "==============================================="
        echo
        echo "CURRENT SYSTEM STATE:"
        echo "  CPU Usage: ${cpu_usage}%"
        echo "  Memory Usage: ${mem_usage}%"
        echo "  Disk Usage: ${disk_usage}%"
        echo "  Load Average: $load_avg (${cpu_cores} cores)"
        echo "  Process Count: $process_count"
        echo
        echo "OPTIMIZATION RECOMMENDATIONS:"
        
        # CPU optimization recommendations
        if [[ $cpu_usage -gt 80 ]]; then
            echo
            echo "🔴 HIGH CPU USAGE (${cpu_usage}%):"
            echo "  • Identify and optimize CPU-intensive processes"
            echo "  • Consider process nice values for non-critical tasks"
            echo "  • Implement CPU limits using cgroups if available"
            echo "  • Review process scheduling and priority"
            echo "  • Consider horizontal scaling for high-load applications"
        elif [[ $cpu_usage -gt 60 ]]; then
            echo
            echo "🟡 MODERATE CPU USAGE (${cpu_usage}%):"
            echo "  • Monitor CPU trends during peak hours"
            echo "  • Consider optimizing frequent operations"
            echo "  • Review background processes and services"
        else
            echo
            echo "✅ CPU USAGE OPTIMAL (${cpu_usage}%):"
            echo "  • CPU utilization is within healthy range"
            echo "  • Current workload is well-managed"
        fi
        
        # Memory optimization recommendations
        if [[ $mem_usage -gt 85 ]]; then
            echo
            echo "🔴 HIGH MEMORY USAGE (${mem_usage}%):"
            echo "  • Identify memory leaks in applications"
            echo "  • Consider adding swap if not present"
            echo "  • Implement memory limits for processes"
            echo "  • Review caching strategies and buffer usage"
            echo "  • Consider memory optimization or system upgrade"
        elif [[ $mem_usage -gt 70 ]]; then
            echo
            echo "🟡 MODERATE MEMORY USAGE (${mem_usage}%):"
            echo "  • Monitor memory trends and growth patterns"
            echo "  • Review memory-intensive applications"
            echo "  • Consider memory cleanup procedures"
        else
            echo
            echo "✅ MEMORY USAGE OPTIMAL (${mem_usage}%):"
            echo "  • Memory utilization is healthy"
            echo "  • Good balance of used and available memory"
        fi
        
        # Load average recommendations
        local load_threshold=$((cpu_cores * 70 / 100))
        if (( $(echo "$load_avg > $cpu_cores" | bc -l 2>/dev/null || [[ ${load_avg%.*} -gt $cpu_cores ]] && echo 1 || echo 0) )); then
            echo
            echo "🔴 HIGH SYSTEM LOAD ($load_avg on ${cpu_cores} cores):"
            echo "  • System is overloaded - load exceeds CPU core count"
            echo "  • Reduce concurrent processes or increase system resources"
            echo "  • Implement load balancing or process queuing"
            echo "  • Consider system upgrade or workload distribution"
        elif (( $(echo "$load_avg > $load_threshold" | bc -l 2>/dev/null || [[ ${load_avg%.*} -gt $load_threshold ]] && echo 1 || echo 0) )); then
            echo
            echo "🟡 MODERATE SYSTEM LOAD ($load_avg on ${cpu_cores} cores):"
            echo "  • System approaching capacity limits"
            echo "  • Monitor load patterns and plan for growth"
            echo "  • Optimize process efficiency and scheduling"
        else
            echo
            echo "✅ SYSTEM LOAD OPTIMAL ($load_avg on ${cpu_cores} cores):"
            echo "  • Load average is within healthy range"
            echo "  • System has good capacity for additional work"
        fi
        
        # Process count recommendations
        if [[ $process_count -gt 500 ]]; then
            echo
            echo "🟡 HIGH PROCESS COUNT ($process_count):"
            echo "  • Review if all processes are necessary"
            echo "  • Consider process consolidation opportunities"
            echo "  • Implement process monitoring and cleanup"
        else
            echo
            echo "✅ PROCESS COUNT NORMAL ($process_count):"
            echo "  • Process count is within reasonable range"
        fi
        
        # General recommendations
        echo
        echo "GENERAL OPTIMIZATION STRATEGIES:"
        echo "  • Regular system monitoring and maintenance"
        echo "  • Implement automated resource alerting"
        echo "  • Use process resource limits (ulimit, cgroups)"
        echo "  • Optimize application startup and shutdown procedures"
        echo "  • Consider containerization for resource isolation"
        echo "  • Implement log rotation and cleanup procedures"
        echo "  • Regular security updates and patches"
        echo "  • Monitor for memory leaks and resource exhaustion"
        
        echo
        echo "MONITORING RECOMMENDATIONS:"
        echo "  • Set up continuous resource monitoring"
        echo "  • Implement alerting for resource thresholds"
        echo "  • Track resource usage trends over time"
        echo "  • Regular performance baseline reviews"
        echo "  • Automated anomaly detection for processes"
        
    } > "$report_file"
    
    log_success "Process optimization recommendations generated: $report_file"
    return 0
}

# Generate comprehensive HTML process management report
generate_process_report() {
    local report_file="${1:-/tmp/process_report_$(date +%Y%m%d_%H%M%S).html}"
    
    log_info "Generating comprehensive process management report"
    
    # Collect current system metrics
    local cpu_line cpu_values total_cpu cpu_usage
    cpu_line=$(grep "^cpu " /proc/stat 2>/dev/null || echo "cpu 0 0 0 0 0 0 0 0")
    cpu_values=($cpu_line)
    total_cpu=$((${cpu_values[1]} + ${cpu_values[2]} + ${cpu_values[3]} + ${cpu_values[4]} + ${cpu_values[5]:-0} + ${cpu_values[6]:-0} + ${cpu_values[7]:-0}))
    cpu_usage=$(( (total_cpu - ${cpu_values[4]}) * 100 / total_cpu ))
    
    local mem_total mem_available mem_usage
    mem_total=$(grep "^MemTotal:" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "1")
    mem_available=$(grep "^MemAvailable:" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "1")
    mem_usage=$(( (mem_total - mem_available) * 100 / mem_total ))
    
    local disk_usage load_avg process_count
    disk_usage=$(df / 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//' || echo "0")
    load_avg=$(cat /proc/loadavg 2>/dev/null | awk '{print $1}' || echo "0")
    process_count=$(ps aux 2>/dev/null | wc -l || echo "1")
    process_count=$((process_count - 1))
    
    # Get top processes
    local top_cpu_processes top_mem_processes
    top_cpu_processes=$(ps aux --sort=-%cpu 2>/dev/null | head -6 | tail -5 || echo "")
    top_mem_processes=$(ps aux --sort=-%mem 2>/dev/null | head -6 | tail -5 || echo "")
    
    # Get process state counts
    local running_count sleeping_count zombie_count
    running_count=$(ps aux 2>/dev/null | awk '$8 ~ /^R/ {count++} END {print count+0}' || echo "0")
    sleeping_count=$(ps aux 2>/dev/null | awk '$8 ~ /^S/ {count++} END {print count+0}' || echo "0")
    zombie_count=$(ps aux 2>/dev/null | awk '$8 ~ /^Z/ {count++} END {print count+0}' || echo "0")
    
    # Determine status classes
    local cpu_class="success"
    [[ $cpu_usage -gt 60 ]] && cpu_class="warning"
    [[ $cpu_usage -gt 80 ]] && cpu_class="error"
    
    local mem_class="success"
    [[ $mem_usage -gt 70 ]] && mem_class="warning"
    [[ $mem_usage -gt 85 ]] && mem_class="error"
    
    local zombie_class="success"
    [[ $zombie_count -gt 0 ]] && zombie_class="error"
    
    # Generate HTML content
    local html_content="
<h2>Process Management Status</h2>
<div class=\"summary-stats\">
    <div class=\"stat-box\">
        <div class=\"stat-number\">$cpu_usage%</div>
        <div class=\"stat-label\">CPU Usage</div>
    </div>
    <div class=\"stat-box\">
        <div class=\"stat-number\">$mem_usage%</div>
        <div class=\"stat-label\">Memory Usage</div>
    </div>
    <div class=\"stat-box\">
        <div class=\"stat-number\">$load_avg</div>
        <div class=\"stat-label\">Load Average</div>
    </div>
    <div class=\"stat-box\">
        <div class=\"stat-number\">$process_count</div>
        <div class=\"stat-label\">Total Processes</div>
    </div>
</div>

<h3>System Resource Overview</h3>
<table class=\"resource-table\">
<thead>
<tr>
<th>Resource</th>
<th>Usage</th>
<th>Status</th>
<th>Recommendation</th>
</tr>
</thead>
<tbody>
<tr class=\"$cpu_class\">
<td>CPU</td>
<td>${cpu_usage}%</td>
<td><span class=\"status-$cpu_class\">$([ $cpu_usage -gt 80 ] && echo 'HIGH' || [ $cpu_usage -gt 60 ] && echo 'MODERATE' || echo 'NORMAL')</span></td>
<td>$([ $cpu_usage -gt 80 ] && echo 'Optimize CPU-intensive processes' || [ $cpu_usage -gt 60 ] && echo 'Monitor CPU trends' || echo 'Usage within optimal range')</td>
</tr>
<tr class=\"$mem_class\">
<td>Memory</td>
<td>${mem_usage}%</td>
<td><span class=\"status-$mem_class\">$([ $mem_usage -gt 85 ] && echo 'HIGH' || [ $mem_usage -gt 70 ] && echo 'MODERATE' || echo 'NORMAL')</span></td>
<td>$([ $mem_usage -gt 85 ] && echo 'Check for memory leaks' || [ $mem_usage -gt 70 ] && echo 'Monitor memory trends' || echo 'Usage within optimal range')</td>
</tr>
<tr>
<td>Disk (/)</td>
<td>${disk_usage}%</td>
<td><span class=\"status-$([ $disk_usage -gt 90 ] && echo 'error' || [ $disk_usage -gt 80 ] && echo 'warning' || echo 'success')\">$([ $disk_usage -gt 90 ] && echo 'HIGH' || [ $disk_usage -gt 80 ] && echo 'MODERATE' || echo 'NORMAL')</span></td>
<td>$([ $disk_usage -gt 90 ] && echo 'Clean up disk space immediately' || [ $disk_usage -gt 80 ] && echo 'Plan disk cleanup' || echo 'Disk usage healthy')</td>
</tr>
<tr class=\"$zombie_class\">
<td>Zombies</td>
<td>$zombie_count</td>
<td><span class=\"status-$zombie_class\">$([ $zombie_count -gt 0 ] && echo 'DETECTED' || echo 'NONE')</span></td>
<td>$([ $zombie_count -gt 0 ] && echo 'Clean up zombie processes' || echo 'No action needed')</td>
</tr>
</tbody>
</table>

<h3>Process State Distribution</h3>
<table class=\"process-state-table\">
<thead>
<tr>
<th>State</th>
<th>Count</th>
<th>Percentage</th>
</tr>
</thead>
<tbody>
<tr>
<td>Running</td>
<td>$running_count</td>
<td>$(( running_count * 100 / process_count ))%</td>
</tr>
<tr>
<td>Sleeping</td>
<td>$sleeping_count</td>
<td>$(( sleeping_count * 100 / process_count ))%</td>
</tr>
<tr class=\"$zombie_class\">
<td>Zombie</td>
<td>$zombie_count</td>
<td>$(( zombie_count * 100 / process_count ))%</td>
</tr>
<tr>
<td>Other</td>
<td>$(( process_count - running_count - sleeping_count - zombie_count ))</td>
<td>$(( (process_count - running_count - sleeping_count - zombie_count) * 100 / process_count ))%</td>
</tr>
</tbody>
</table>

<h3>Top CPU Consuming Processes</h3>
<table class=\"top-processes-table\">
<thead>
<tr>
<th>User</th>
<th>PID</th>
<th>%CPU</th>
<th>%MEM</th>
<th>Command</th>
</tr>
</thead>
<tbody>"

    # Add top CPU processes
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local fields=($line)
            local user="${fields[0]}"
            local pid="${fields[1]}"
            local cpu="${fields[2]}"
            local mem="${fields[3]}"
            local command=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | cut -c1-50)
            html_content="$html_content
<tr>
<td>$user</td>
<td>$pid</td>
<td>$cpu%</td>
<td>$mem%</td>
<td>$command</td>
</tr>"
        fi
    done <<< "$top_cpu_processes"

    html_content="$html_content
</tbody>
</table>

<h3>Top Memory Consuming Processes</h3>
<table class=\"top-processes-table\">
<thead>
<tr>
<th>User</th>
<th>PID</th>
<th>%CPU</th>
<th>%MEM</th>
<th>Command</th>
</tr>
</thead>
<tbody>"

    # Add top memory processes
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local fields=($line)
            local user="${fields[0]}"
            local pid="${fields[1]}"
            local cpu="${fields[2]}"
            local mem="${fields[3]}"
            local command=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | cut -c1-50)
            html_content="$html_content
<tr>
<td>$user</td>
<td>$pid</td>
<td>$cpu%</td>
<td>$mem%</td>
<td>$command</td>
</tr>"
        fi
    done <<< "$top_mem_processes"

    html_content="$html_content
</tbody>
</table>

<h3>System Recommendations</h3>
<div class=\"recommendations-info\">"

    # Add recommendations based on current state
    if [[ $cpu_usage -gt 80 || $mem_usage -gt 85 || $zombie_count -gt 0 ]]; then
        html_content="$html_content
<div class=\"summary-box summary-danger\">
<h4>Immediate Attention Required</h4>
<ul>"
        [[ $cpu_usage -gt 80 ]] && html_content="$html_content
<li>High CPU usage ($cpu_usage%) - investigate CPU-intensive processes</li>"
        [[ $mem_usage -gt 85 ]] && html_content="$html_content
<li>High memory usage ($mem_usage%) - check for memory leaks</li>"
        [[ $zombie_count -gt 0 ]] && html_content="$html_content
<li>$zombie_count zombie processes detected - clean up required</li>"
        html_content="$html_content
</ul>
</div>"
    elif [[ $cpu_usage -gt 60 || $mem_usage -gt 70 ]]; then
        html_content="$html_content
<div class=\"summary-box summary-warning\">
<h4>Monitor Resource Usage</h4>
<ul>"
        [[ $cpu_usage -gt 60 ]] && html_content="$html_content
<li>Moderate CPU usage ($cpu_usage%) - monitor trends during peak hours</li>"
        [[ $mem_usage -gt 70 ]] && html_content="$html_content
<li>Moderate memory usage ($mem_usage%) - review memory-intensive applications</li>"
        html_content="$html_content
</ul>
</div>"
    else
        html_content="$html_content
<div class=\"summary-box summary-success\">
<h4>System Performance: Excellent</h4>
<ul>
<li>CPU usage within optimal range ($cpu_usage%)</li>
<li>Memory usage healthy ($mem_usage%)</li>
<li>No zombie processes detected</li>
<li>System operating efficiently</li>
</ul>
</div>"
    fi

    html_content="$html_content
</div>"
    
    # Generate the final HTML report
    generate_html_report "Process Management Report" "$html_content" "$report_file"
    
    log_success "Process management report generated: $report_file"
    echo "$report_file"
}

# Comprehensive process management check
run_process_management() {
    local report_dir="${1:-$(get_config 'system.data_directory' '/var/log/bash-admin')}"
    local today=$(date +%Y%m%d)
    
    mkdir -p "$report_dir"
    
    log_info "Running comprehensive process management check"
    
    local total_issues=0
    
    # Check system resource usage
    local resource_report="$report_dir/system_resources_$today.txt"
    get_system_resource_usage "$resource_report"
    local resource_alerts=$?
    total_issues=$((total_issues + resource_alerts))
    
    # Monitor high resource processes
    local high_resource_report="$report_dir/high_resource_processes_$today.txt"
    monitor_high_resource_processes "$high_resource_report"
    local high_resource_alerts=$?
    total_issues=$((total_issues + high_resource_alerts))
    
    # Check for zombie processes and anomalies
    local zombie_report="$report_dir/zombie_processes_$today.txt"
    check_zombie_processes "$zombie_report"
    local zombie_alerts=$?
    total_issues=$((total_issues + zombie_alerts))
    
    # Generate optimization recommendations
    generate_process_recommendations "$report_dir/process_recommendations_$today.txt"
    
    # Generate comprehensive HTML report
    generate_process_report "$report_dir/process_management_$today.html"
    
    log_info "Process management check completed with $total_issues issues/alerts"
    return $total_issues
}

# Export functions for use by other scripts
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f get_system_resource_usage
    export -f monitor_high_resource_processes
    export -f check_zombie_processes
    export -f generate_process_recommendations
    export -f generate_process_report
    export -f run_process_management
fi

# Main function for direct execution
main() {
    local action="${1:-check}"
    local target="${2:-}"
    
    case "$action" in
        "resources"|"usage")
            get_system_resource_usage "$target"
            ;;
        "processes"|"top")
            monitor_high_resource_processes "$target"
            ;;
        "zombies"|"anomalies")
            check_zombie_processes "$target"
            ;;
        "recommendations"|"optimize")
            generate_process_recommendations "$target"
            ;;
        "report")
            generate_process_report "$target"
            ;;
        "full"|"all"|"check")
            run_process_management
            ;;
        *)
            echo "Usage: $0 {resources|processes|zombies|recommendations|report|full} [target]"
            echo "  resources:       Get system resource usage"
            echo "  processes:       Monitor high resource processes"
            echo "  zombies:         Check for zombie/anomalous processes"
            echo "  recommendations: Generate optimization recommendations"
            echo "  report:          Generate HTML report"
            echo "  full:            Run complete process management"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi