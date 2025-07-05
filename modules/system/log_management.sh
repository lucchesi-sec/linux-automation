#!/bin/bash
# Log Management Module
# Provides functions for log rotation, analysis, and maintenance

# Source core libraries
source "$(dirname "$0")/../../core/lib/init.sh"

# Analyze system logs for issues and patterns
analyze_system_logs() {
    local report_file="${1:-/tmp/log_analysis_$(date +%Y%m%d).txt}"
    local days_back="${2:-1}"
    local log_issues=()
    local error_patterns=()
    local warning_patterns=()
    
    log_info "Analyzing system logs for the last $days_back day(s)"
    
    # Define log files to analyze
    local log_files=(
        "/var/log/syslog"
        "/var/log/messages"
        "/var/log/auth.log"
        "/var/log/secure"
        "/var/log/kern.log"
        "/var/log/daemon.log"
    )
    
    # Error patterns to look for
    local error_regex="(ERROR|CRITICAL|FATAL|FAIL|panic|segfault|out of memory|disk full)"
    local warning_regex="(WARNING|WARN|deprecated)"
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            log_debug "Analyzing $log_file"
            
            # Get recent entries based on days_back
            local recent_entries
            if [[ $days_back -eq 1 ]]; then
                recent_entries=$(grep "$(date '+%b %d')" "$log_file" 2>/dev/null)
            else
                # For multiple days, use a more complex date range
                recent_entries=$(tail -10000 "$log_file" 2>/dev/null)
            fi
            
            # Count errors
            local error_count
            error_count=$(echo "$recent_entries" | grep -iE "$error_regex" | wc -l)
            if [[ $error_count -gt 0 ]]; then
                log_issues+=("$log_file: $error_count errors found")
                
                # Capture specific error patterns
                echo "$recent_entries" | grep -iE "$error_regex" | head -5 | while IFS= read -r line; do
                    error_patterns+=("$(basename "$log_file"): $(echo "$line" | cut -c1-100)")
                done
            fi
            
            # Count warnings
            local warning_count
            warning_count=$(echo "$recent_entries" | grep -iE "$warning_regex" | wc -l)
            if [[ $warning_count -gt 5 ]]; then  # Only report if more than 5 warnings
                log_issues+=("$log_file: $warning_count warnings found")
                
                # Capture specific warning patterns
                echo "$recent_entries" | grep -iE "$warning_regex" | head -3 | while IFS= read -r line; do
                    warning_patterns+=("$(basename "$log_file"): $(echo "$line" | cut -c1-100)")
                done
            fi
            
            # Check for disk space issues
            if echo "$recent_entries" | grep -q "No space left on device\|disk full"; then
                log_issues+=("$log_file: Disk space issues detected")
            fi
            
            # Check for memory issues
            if echo "$recent_entries" | grep -q "Out of memory\|killed process"; then
                log_issues+=("$log_file: Memory issues detected")
            fi
        fi
    done
    
    # Analyze service-specific logs
    analyze_service_logs log_issues
    
    # Generate report
    {
        echo "System Log Analysis Report - $(date)"
        echo "Last $days_back day(s) analyzed"
        echo "==================================="
        echo
        echo "LOG ISSUES SUMMARY:"
        if [[ ${#log_issues[@]} -eq 0 ]]; then
            echo "  No significant issues found"
        else
            printf "  %s\n" "${log_issues[@]}"
        fi
        echo
        echo "RECENT ERROR PATTERNS:"
        if [[ ${#error_patterns[@]} -eq 0 ]]; then
            echo "  No recent errors"
        else
            printf "  %s\n" "${error_patterns[@]}"
        fi
        echo
        echo "RECENT WARNING PATTERNS:"
        if [[ ${#warning_patterns[@]} -eq 0 ]]; then
            echo "  No significant warnings"
        else
            printf "  %s\n" "${warning_patterns[@]}"
        fi
    } > "$report_file"
    
    log_info "Log analysis report generated: $report_file"
    
    # Send notification if critical issues found
    local critical_issues=$(echo "${log_issues[@]}" | grep -c "error\|CRITICAL\|FATAL")
    if [[ $critical_issues -gt 0 ]]; then
        send_notification "admin" "Critical Log Issues Found" \
            "Found $critical_issues critical issues in system logs. Check $report_file for details."
    fi
    
    return ${#log_issues[@]}
}

# Analyze service-specific logs
analyze_service_logs() {
    local -n issues_ref=$1
    
    # Check Apache/Nginx logs if they exist
    local web_logs=("/var/log/apache2/error.log" "/var/log/nginx/error.log")
    for web_log in "${web_logs[@]}"; do
        if [[ -f "$web_log" ]]; then
            local web_errors
            web_errors=$(grep "$(date '+%Y/%m/%d\|%d/%b/%Y')" "$web_log" 2>/dev/null | wc -l)
            if [[ $web_errors -gt 10 ]]; then
                issues_ref+=("$(basename "$(dirname "$web_log")"): $web_errors web server errors")
            fi
        fi
    done
    
    # Check database logs
    local db_logs=("/var/log/mysql/error.log" "/var/log/postgresql/postgresql.log")
    for db_log in "${db_logs[@]}"; do
        if [[ -f "$db_log" ]]; then
            local db_errors
            db_errors=$(grep "$(date '+%Y-%m-%d')" "$db_log" 2>/dev/null | grep -i error | wc -l)
            if [[ $db_errors -gt 0 ]]; then
                issues_ref+=("$(basename "$(dirname "$db_log")"): $db_errors database errors")
            fi
        fi
    done
}

# Rotate logs and clean up old log files
rotate_logs() {
    local retention_days="${1:-30}"
    local compress_days="${2:-7}"
    local log_dirs=("/var/log" "/var/log/bash-admin")
    local files_rotated=0
    local space_freed=0
    
    log_info "Rotating logs with retention of $retention_days days"
    
    for log_dir in "${log_dirs[@]}"; do
        if [[ -d "$log_dir" ]]; then
            # Compress old log files
            while IFS= read -r -d '' file; do
                if [[ ! "$file" =~ \.gz$ && ! "$file" =~ \.bz2$ ]]; then
                    local file_size=$(stat -c %s "$file" 2>/dev/null || echo 0)
                    if gzip "$file" 2>/dev/null; then
                        ((files_rotated++))
                        space_freed=$((space_freed + file_size))
                        log_debug "Compressed log file: $file"
                    fi
                fi
            done < <(find "$log_dir" -type f -name "*.log" -mtime +$compress_days -print0 2>/dev/null)
            
            # Remove very old log files
            while IFS= read -r -d '' file; do
                local file_size=$(stat -c %s "$file" 2>/dev/null || echo 0)
                if rm -f "$file" 2>/dev/null; then
                    ((files_rotated++))
                    space_freed=$((space_freed + file_size))
                    log_debug "Removed old log file: $file"
                fi
            done < <(find "$log_dir" -type f \( -name "*.log.gz" -o -name "*.log.bz2" \) -mtime +$retention_days -print0 2>/dev/null)
        fi
    done
    
    # Clean up bash-admin specific logs
    cleanup_admin_logs "$retention_days"
    
    local space_freed_mb=$((space_freed / 1024 / 1024))
    log_info "Log rotation completed: $files_rotated files processed, ${space_freed_mb}MB freed"
    
    return 0
}

# Clean up bash-admin specific logs
cleanup_admin_logs() {
    local retention_days="$1"
    local admin_log_dirs=("/var/log/bash-admin" "/tmp")
    
    for admin_dir in "${admin_log_dirs[@]}"; do
        if [[ -d "$admin_dir" ]]; then
            # Remove old bash-admin report files
            find "$admin_dir" -name "*_$(date -d "${retention_days} days ago" +%Y%m%d).txt" -delete 2>/dev/null
            find "$admin_dir" -name "*_$(date -d "${retention_days} days ago" +%Y%m%d).html" -delete 2>/dev/null
            
            # Remove old temporary files created by our scripts
            find "$admin_dir" -name "*.tmp" -mtime +1 -delete 2>/dev/null
            find "$admin_dir" -name "*_report_*.txt" -mtime +$retention_days -delete 2>/dev/null
        fi
    done
}

# Monitor log file growth and disk usage
monitor_log_growth() {
    local report_file="${1:-/tmp/log_growth_$(date +%Y%m%d).txt}"
    local warning_size_mb="${2:-100}"
    local critical_size_mb="${3:-500}"
    local growth_issues=()
    
    log_info "Monitoring log file growth (warning: ${warning_size_mb}MB, critical: ${critical_size_mb}MB)"
    
    # Check size of major log files
    local log_files=(
        "/var/log/syslog"
        "/var/log/auth.log" 
        "/var/log/kern.log"
        "/var/log/daemon.log"
        "/var/log/messages"
        "/var/log/apache2/access.log"
        "/var/log/nginx/access.log"
        "/var/log/mysql/mysql.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            local size_bytes=$(stat -c %s "$log_file")
            local size_mb=$((size_bytes / 1024 / 1024))
            
            if [[ $size_mb -ge $critical_size_mb ]]; then
                growth_issues+=("CRITICAL: $log_file is ${size_mb}MB")
                log_error "Critical log size: $log_file (${size_mb}MB)"
            elif [[ $size_mb -ge $warning_size_mb ]]; then
                growth_issues+=("WARNING: $log_file is ${size_mb}MB")
                log_warn "Large log file: $log_file (${size_mb}MB)"
            fi
        fi
    done
    
    # Check overall log directory sizes
    local log_dirs=("/var/log" "/var/log/apache2" "/var/log/nginx")
    for log_dir in "${log_dirs[@]}"; do
        if [[ -d "$log_dir" ]]; then
            local dir_size_mb=$(du -sm "$log_dir" 2>/dev/null | cut -f1)
            if [[ $dir_size_mb -ge $((critical_size_mb * 2)) ]]; then
                growth_issues+=("CRITICAL: $log_dir directory is ${dir_size_mb}MB")
            elif [[ $dir_size_mb -ge $((warning_size_mb * 2)) ]]; then
                growth_issues+=("WARNING: $log_dir directory is ${dir_size_mb}MB")
            fi
        fi
    done
    
    # Generate report
    {
        echo "Log Growth Monitoring Report - $(date)"
        echo "======================================"
        echo
        if [[ ${#growth_issues[@]} -eq 0 ]]; then
            echo "No log growth issues detected"
        else
            echo "LOG GROWTH ISSUES:"
            printf "%s\n" "${growth_issues[@]}"
        fi
        echo
        echo "LOG DIRECTORY SIZES:"
        du -sh /var/log/* 2>/dev/null | sort -hr | head -10
    } > "$report_file"
    
    log_info "Log growth report generated: $report_file"
    
    # Send notification for critical issues
    local critical_count=$(echo "${growth_issues[@]}" | grep -c "CRITICAL")
    if [[ $critical_count -gt 0 ]]; then
        send_notification "admin" "Critical Log Growth" \
            "Found $critical_count critical log growth issues. Check $report_file for details."
    fi
    
    return ${#growth_issues[@]}
}

# Generate log statistics and insights
generate_log_stats() {
    local report_file="${1:-/tmp/log_stats_$(date +%Y%m%d).txt}"
    local days_back="${2:-7}"
    
    log_info "Generating log statistics for the last $days_back days"
    
    # Collect various log statistics
    local total_log_entries=0
    local error_entries=0
    local warning_entries=0
    local auth_failures=0
    local successful_logins=0
    
    # Count entries in main system logs
    if [[ -f /var/log/syslog ]]; then
        total_log_entries=$(wc -l < /var/log/syslog)
        error_entries=$(grep -c -i "error\|critical\|fatal" /var/log/syslog 2>/dev/null || echo 0)
        warning_entries=$(grep -c -i "warning\|warn" /var/log/syslog 2>/dev/null || echo 0)
    fi
    
    # Count authentication events
    if [[ -f /var/log/auth.log ]]; then
        auth_failures=$(grep -c "Failed password\|authentication failure" /var/log/auth.log 2>/dev/null || echo 0)
        successful_logins=$(grep -c "Accepted password\|Accepted publickey" /var/log/auth.log 2>/dev/null || echo 0)
    fi
    
    # Generate comprehensive statistics report
    {
        echo "Log Statistics Report - $(date)"
        echo "Last $days_back days analyzed"
        echo "=============================="
        echo
        echo "OVERALL STATISTICS:"
        echo "  Total log entries: $total_log_entries"
        echo "  Error entries: $error_entries"
        echo "  Warning entries: $warning_entries"
        echo "  Authentication failures: $auth_failures"
        echo "  Successful logins: $successful_logins"
        echo
        echo "TOP ERROR MESSAGES:"
        if [[ -f /var/log/syslog ]]; then
            grep -i "error\|critical\|fatal" /var/log/syslog 2>/dev/null | \
            awk '{for(i=4;i<=NF;i++) printf "%s ", $i; print ""}' | \
            sort | uniq -c | sort -nr | head -5
        fi
        echo
        echo "LOG FILE SIZES:"
        ls -lh /var/log/*.log 2>/dev/null | awk '{print $5 "\t" $9}' | sort -hr
        echo
        echo "DISK USAGE BY LOG DIRECTORY:"
        du -sh /var/log/* 2>/dev/null | sort -hr | head -10
    } > "$report_file"
    
    log_info "Log statistics report generated: $report_file"
    return 0
}

# Export functions for use by other scripts
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f analyze_system_logs
    export -f rotate_logs
    export -f monitor_log_growth
    export -f generate_log_stats
fi