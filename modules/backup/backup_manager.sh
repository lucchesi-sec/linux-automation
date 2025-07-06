#!/bin/bash
# Backup Management Module
# Comprehensive backup monitoring, verification, and management system

# Source core libraries
source "$(dirname "$0")/../../core/lib/init.sh"

# Monitor backup jobs status and report findings
monitor_backup_jobs() {
    local report_file="${1:-/tmp/backup_jobs_$(date +%Y%m%d).txt}"
    
    log_info "Monitoring backup job status"
    
    # Get backup configuration from config
    local backup_jobs
    backup_jobs=$(get_config 'modules.backup_monitor.backup_jobs' '{}')
    
    local total_jobs=0
    local successful_jobs=0
    local failed_jobs=0
    local job_details=()
    
    {
        echo "Backup Jobs Status Report - $(date)"
        echo "======================================"
        echo
        echo "BACKUP JOB ANALYSIS:"
        echo
        
        # Check each configured backup job
        if command -v jq >/dev/null 2>&1 && [[ "$backup_jobs" != "{}" ]]; then
            while IFS= read -r job_name; do
                [[ -z "$job_name" || "$job_name" == "null" ]] && continue
                
                ((total_jobs++))
                
                local job_enabled=$(echo "$backup_jobs" | jq -r ".$job_name.enabled // true")
                local job_path=$(echo "$backup_jobs" | jq -r ".$job_name.path // \"\"")
                local job_schedule=$(echo "$backup_jobs" | jq -r ".$job_name.schedule // \"daily\"")
                local job_retention=$(echo "$backup_jobs" | jq -r ".$job_name.retention // \"30d\"")
                
                if [[ "$job_enabled" != "true" ]]; then
                    job_details+=("  $job_name: DISABLED")
                    continue
                fi
                
                # Check if backup path has recent backups
                local recent_backup_count=0
                if [[ -d "$job_path" ]]; then
                    recent_backup_count=$(find "$job_path" -type f -mtime -1 \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.sql.gz" \) 2>/dev/null | wc -l)
                elif [[ -f "$job_path" ]]; then
                    # Single file backup - check if recent
                    if [[ $(find "$(dirname "$job_path")" -name "$(basename "$job_path")" -mtime -1 2>/dev/null | wc -l) -gt 0 ]]; then
                        recent_backup_count=1
                    fi
                fi
                
                if [[ $recent_backup_count -gt 0 ]]; then
                    ((successful_jobs++))
                    job_details+=("  $job_name: SUCCESS - $recent_backup_count recent backup(s)")
                    printf "  %-20s Status:%-10s Path:%-30s Schedule:%s\\n" "$job_name" "SUCCESS" "$job_path" "$job_schedule"
                else
                    ((failed_jobs++))
                    job_details+=("  $job_name: FAILED - No recent backups found")
                    printf "  %-20s Status:%-10s Path:%-30s Schedule:%s\\n" "$job_name" "FAILED" "$job_path" "$job_schedule"
                fi
                
            done < <(echo "$backup_jobs" | jq -r 'keys[]' 2>/dev/null)
        fi
        
        # Also check standard backup directories
        local backup_paths
        backup_paths=$(get_config 'modules.backup_monitor.backup_paths' '[]')
        
        if command -v jq >/dev/null 2>&1 && [[ "$backup_paths" != "[]" ]]; then
            echo
            echo "BACKUP PATH ANALYSIS:"
            echo
            
            while IFS= read -r backup_path; do
                [[ -z "$backup_path" || "$backup_path" == "null" ]] && continue
                
                if [[ -d "$backup_path" ]]; then
                    local recent_files=$(find "$backup_path" -type f -mtime -1 \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.sql.gz" \) 2>/dev/null | wc -l)
                    local total_files=$(find "$backup_path" -type f \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.sql.gz" \) 2>/dev/null | wc -l)
                    local path_size=$(du -sh "$backup_path" 2>/dev/null | cut -f1 || echo "N/A")
                    
                    printf "  %-30s Recent:%-6s Total:%-6s Size:%s\\n" "$backup_path" "$recent_files" "$total_files" "$path_size"
                else
                    printf "  %-30s Status: MISSING\\n" "$backup_path"
                fi
            done < <(echo "$backup_paths" | jq -r '.[]' 2>/dev/null)
        fi
        
        echo
        echo "SUMMARY STATISTICS:"
        echo "  Total Jobs Configured: $total_jobs"
        echo "  Successful Jobs: $successful_jobs"
        echo "  Failed Jobs: $failed_jobs"
        echo "  Success Rate: $(( total_jobs > 0 ? successful_jobs * 100 / total_jobs : 0 ))%"
        
    } > "$report_file"
    
    log_info "Backup jobs report generated: $report_file"
    
    # Return failure if any jobs failed
    [[ $failed_jobs -eq 0 ]]
}

# Verify backup integrity with comprehensive checks
verify_backup_integrity() {
    local report_file="${1:-/tmp/backup_integrity_$(date +%Y%m%d).txt}"
    
    log_info "Verifying backup integrity"
    
    local total_backups=0
    local verified_backups=0
    local failed_backups=0
    local integrity_issues=()
    
    # Get integrity check settings
    local checksum_validation=$(get_config 'modules.backup_monitor.integrity_checks.checksum_validation' 'true')
    local size_validation=$(get_config 'modules.backup_monitor.integrity_checks.size_validation' 'true')
    
    {
        echo "Backup Integrity Verification Report - $(date)"
        echo "=============================================="
        echo
        echo "INTEGRITY CHECK CONFIGURATION:"
        echo "  Checksum Validation: $checksum_validation"
        echo "  Size Validation: $size_validation"
        echo
        echo "BACKUP FILE ANALYSIS:"
        echo
        
        # Find all backup files from configured paths
        local backup_paths
        backup_paths=$(get_config 'modules.backup_monitor.backup_paths' '["/backup/daily", "/backup/weekly", "/mnt/backup"]')
        
        if command -v jq >/dev/null 2>&1; then
            while IFS= read -r backup_path; do
                [[ -z "$backup_path" || "$backup_path" == "null" ]] && continue
                
                if [[ ! -d "$backup_path" ]]; then
                    continue
                fi
                
                # Check backup files in this path
                while IFS= read -r -d '' backup_file; do
                    ((total_backups++))
                    
                    local file_status="OK"
                    local file_issues=""
                    
                    # Basic existence and readability
                    if [[ ! -r "$backup_file" ]]; then
                        file_status="FAILED"
                        file_issues="$file_issues [UNREADABLE]"
                        ((failed_backups++))
                        integrity_issues+=("$backup_file: Unreadable file")
                        continue
                    fi
                    
                    # Size validation
                    if [[ "$size_validation" == "true" ]]; then
                        local file_size=$(stat -c %s "$backup_file" 2>/dev/null || echo 0)
                        if [[ $file_size -lt 1024 ]]; then  # Less than 1KB is suspicious
                            file_status="WARNING"
                            file_issues="$file_issues [SMALL_SIZE:${file_size}B]"
                        fi
                    fi
                    
                    # File type specific integrity checks
                    local file_ext="${backup_file##*.}"
                    case "$file_ext" in
                        "gz"|"tgz")
                            if [[ "$backup_file" =~ \.tar\.gz$ ]]; then
                                if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
                                    file_status="FAILED"
                                    file_issues="$file_issues [TAR_CORRUPT]"
                                    ((failed_backups++))
                                    integrity_issues+=("$backup_file: Corrupt tar.gz archive")
                                else
                                    ((verified_backups++))
                                fi
                            elif [[ "$backup_file" =~ \.sql\.gz$ ]]; then
                                if ! zcat "$backup_file" | head -10 | grep -q "CREATE\|INSERT\|SQL" 2>/dev/null; then
                                    file_status="FAILED"
                                    file_issues="$file_issues [SQL_INVALID]"
                                    ((failed_backups++))
                                    integrity_issues+=("$backup_file: Invalid SQL dump")
                                else
                                    ((verified_backups++))
                                fi
                            fi
                            ;;
                        "zip")
                            if ! unzip -t "$backup_file" >/dev/null 2>&1; then
                                file_status="FAILED"
                                file_issues="$file_issues [ZIP_CORRUPT]"
                                ((failed_backups++))
                                integrity_issues+=("$backup_file: Corrupt zip archive")
                            else
                                ((verified_backups++))
                            fi
                            ;;
                        "sql")
                            if ! head -10 "$backup_file" | grep -q "CREATE\|INSERT\|SQL" 2>/dev/null; then
                                file_status="FAILED"
                                file_issues="$file_issues [SQL_INVALID]"
                                ((failed_backups++))
                                integrity_issues+=("$backup_file: Invalid SQL dump")
                            else
                                ((verified_backups++))
                            fi
                            ;;
                        *)
                            # Unknown file type - basic size check only
                            ((verified_backups++))
                            file_issues="$file_issues [UNKNOWN_TYPE]"
                            ;;
                    esac
                    
                    # Checksum validation if enabled and .sha256 file exists
                    if [[ "$checksum_validation" == "true" && -f "${backup_file}.sha256" ]]; then
                        if ! sha256sum -c "${backup_file}.sha256" >/dev/null 2>&1; then
                            file_status="FAILED"
                            file_issues="$file_issues [CHECKSUM_MISMATCH]"
                            if [[ "$file_status" != "FAILED" ]]; then
                                ((failed_backups++))
                                ((verified_backups--))
                            fi
                            integrity_issues+=("$backup_file: Checksum verification failed")
                        fi
                    fi
                    
                    # Output file status
                    local file_age_hours=$(( ($(date +%s) - $(stat -c %Y "$backup_file")) / 3600 ))
                    printf "  %-50s Status:%-10s Age:%-8s %s\\n" "$(basename "$backup_file")" "$file_status" "${file_age_hours}h" "$file_issues"
                    
                done < <(find "$backup_path" -type f \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.sql.gz" -o -name "*.sql" \) -print0 2>/dev/null)
                
            done < <(echo "$backup_paths" | jq -r '.[]' 2>/dev/null)
        fi
        
        echo
        echo "INTEGRITY SUMMARY:"
        echo "  Total Backups Checked: $total_backups"
        echo "  Verified Successfully: $verified_backups"
        echo "  Failed Verification: $failed_backups"
        if [[ $total_backups -gt 0 ]]; then
            echo "  Success Rate: $(( verified_backups * 100 / total_backups ))%"
        fi
        
        if [[ ${#integrity_issues[@]} -gt 0 ]]; then
            echo
            echo "INTEGRITY ISSUES FOUND:"
            printf "  %s\\n" "${integrity_issues[@]}"
        fi
        
    } > "$report_file"
    
    log_info "Backup integrity report generated: $report_file"
    
    # Return success if no failures
    [[ $failed_backups -eq 0 ]]
}

# Manage backup storage and cleanup
manage_backup_storage() {
    local report_file="${1:-/tmp/backup_storage_$(date +%Y%m%d).txt}"
    
    log_info "Managing backup storage"
    
    # Get storage thresholds from config
    local warning_percent=$(get_config 'modules.backup_monitor.storage_thresholds.warning_percent' '80')
    local critical_percent=$(get_config 'modules.backup_monitor.storage_thresholds.critical_percent' '90')
    local retention_days=$(get_config 'modules.backup_monitor.retention_days' '30')
    
    local storage_issues=()
    local cleanup_summary=()
    
    {
        echo "Backup Storage Management Report - $(date)"
        echo "=========================================="
        echo
        echo "STORAGE CONFIGURATION:"
        echo "  Warning Threshold: ${warning_percent}%"
        echo "  Critical Threshold: ${critical_percent}%"
        echo "  Retention Period: ${retention_days} days"
        echo
        echo "STORAGE ANALYSIS:"
        echo
        
        # Check each backup path
        local backup_paths
        backup_paths=$(get_config 'modules.backup_monitor.backup_paths' '["/backup/daily", "/backup/weekly", "/mnt/backup"]')
        
        if command -v jq >/dev/null 2>&1; then
            while IFS= read -r backup_path; do
                [[ -z "$backup_path" || "$backup_path" == "null" ]] && continue
                
                if [[ ! -d "$backup_path" ]]; then
                    printf "  %-30s Status: MISSING\\n" "$backup_path"
                    storage_issues+=("$backup_path: Directory does not exist")
                    continue
                fi
                
                # Get disk usage for this path
                local df_output
                df_output=$(df "$backup_path" 2>/dev/null | tail -1)
                
                if [[ -n "$df_output" ]]; then
                    local usage_percent=$(echo "$df_output" | awk '{gsub(/%/, "", $5); print $5}')
                    local size=$(echo "$df_output" | awk '{print $2}')
                    local used=$(echo "$df_output" | awk '{print $3}')
                    local available=$(echo "$df_output" | awk '{print $4}')
                    local filesystem=$(echo "$df_output" | awk '{print $1}')
                    
                    # Convert to human readable
                    local size_gb=$(( size / 1024 / 1024 ))
                    local used_gb=$(( used / 1024 / 1024 ))
                    local available_gb=$(( available / 1024 / 1024 ))
                    
                    local status="OK"
                    if [[ $usage_percent -ge $critical_percent ]]; then
                        status="CRITICAL"
                        storage_issues+=("$backup_path: Critical storage usage ${usage_percent}%")
                    elif [[ $usage_percent -ge $warning_percent ]]; then
                        status="WARNING"
                        storage_issues+=("$backup_path: High storage usage ${usage_percent}%")
                    fi
                    
                    printf "  %-30s Usage:%-4s%% Size:%-6sGB Used:%-6sGB Available:%-6sGB Status:%s\\n" \
                        "$backup_path" "$usage_percent" "$size_gb" "$used_gb" "$available_gb" "$status"
                    
                    # Count backup files and total size
                    local backup_count=$(find "$backup_path" -type f \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.sql.gz" \) 2>/dev/null | wc -l)
                    local backup_size_mb=$(find "$backup_path" -type f \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.sql.gz" \) -exec stat -c %s {} + 2>/dev/null | awk '{sum+=$1} END {print int(sum/1024/1024)}')
                    
                    printf "    %-26s Backup Files:%-6s Total Backup Size:%-6sMB\\n" "" "$backup_count" "$backup_size_mb"
                    
                    # Cleanup old backups
                    local files_removed=0
                    local space_freed_mb=0
                    
                    while IFS= read -r -d '' old_file; do
                        local file_size_mb=$(stat -c %s "$old_file" 2>/dev/null | awk '{print int($1/1024/1024)}')
                        if rm -f "$old_file" 2>/dev/null; then
                            ((files_removed++))
                            space_freed_mb=$((space_freed_mb + file_size_mb))
                        fi
                    done < <(find "$backup_path" -type f -mtime +$retention_days \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.sql.gz" \) -print0 2>/dev/null)
                    
                    if [[ $files_removed -gt 0 ]]; then
                        cleanup_summary+=("$backup_path: Removed $files_removed files, freed ${space_freed_mb}MB")
                        printf "    %-26s Cleanup: Removed %-3s files, freed %-6sMB\\n" "" "$files_removed" "$space_freed_mb"
                    else
                        printf "    %-26s Cleanup: No files older than %s days\\n" "" "$retention_days"
                    fi
                fi
                
                echo
                
            done < <(echo "$backup_paths" | jq -r '.[]' 2>/dev/null)
        fi
        
        echo "STORAGE SUMMARY:"
        if [[ ${#storage_issues[@]} -gt 0 ]]; then
            echo "  Storage Issues Found:"
            printf "    %s\\n" "${storage_issues[@]}"
        else
            echo "  All backup storage within normal limits"
        fi
        
        if [[ ${#cleanup_summary[@]} -gt 0 ]]; then
            echo "  Cleanup Actions:"
            printf "    %s\\n" "${cleanup_summary[@]}"
        fi
        
    } > "$report_file"
    
    log_info "Backup storage report generated: $report_file"
    
    # Return failure if critical storage issues found
    local critical_issues=0
    for issue in "${storage_issues[@]}"; do
        if [[ "$issue" =~ Critical ]]; then
            ((critical_issues++))
        fi
    done
    
    [[ $critical_issues -eq 0 ]]
}

# Analyze backup performance and timing patterns
analyze_backup_performance() {
    local report_file="${1:-/tmp/backup_performance_$(date +%Y%m%d).txt}"
    
    log_info "Analyzing backup performance"
    
    local performance_data=()
    local timing_issues=()
    
    {
        echo "Backup Performance Analysis Report - $(date)"
        echo "==========================================="
        echo
        echo "BACKUP TIMING ANALYSIS:"
        echo
        
        # Analyze backup files by age and size trends
        local backup_paths
        backup_paths=$(get_config 'modules.backup_monitor.backup_paths' '["/backup/daily", "/backup/weekly", "/mnt/backup"]')
        
        if command -v jq >/dev/null 2>&1; then
            while IFS= read -r backup_path; do
                [[ -z "$backup_path" || "$backup_path" == "null" ]] && continue
                
                if [[ ! -d "$backup_path" ]]; then
                    continue
                fi
                
                echo "  Backup Path: $backup_path"
                echo "  ----------------------------------------"
                
                # Get backup files sorted by modification time
                local recent_backups=()
                while IFS= read -r backup_info; do
                    recent_backups+=("$backup_info")
                done < <(find "$backup_path" -type f \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.sql.gz" \) -printf "%T@ %s %p\n" 2>/dev/null | sort -nr | head -7)
                
                if [[ ${#recent_backups[@]} -gt 0 ]]; then
                    printf "    %-20s %-10s %-15s %-10s\\n" "Backup File" "Size (MB)" "Date" "Age (hours)"
                    echo "    --------------------------------------------------------------------"
                    
                    local total_size=0
                    local backup_dates=()
                    
                    for backup_info in "${recent_backups[@]}"; do
                        local timestamp=$(echo "$backup_info" | cut -d' ' -f1)
                        local size_bytes=$(echo "$backup_info" | cut -d' ' -f2)
                        local filepath=$(echo "$backup_info" | cut -d' ' -f3-)
                        
                        local size_mb=$((size_bytes / 1024 / 1024))
                        local backup_date=$(date -d "@${timestamp%.*}" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "Unknown")
                        local age_hours=$(( ($(date +%s) - ${timestamp%.*}) / 3600 ))
                        
                        total_size=$((total_size + size_mb))
                        backup_dates+=("$age_hours")
                        
                        printf "    %-20s %-10s %-15s %-10s\\n" "$(basename "$filepath")" "${size_mb}" "$backup_date" "${age_hours}"
                    done
                    
                    # Calculate average backup size and frequency
                    local avg_size=$((total_size / ${#recent_backups[@]}))
                    echo
                    echo "    Performance Metrics:"
                    echo "      Average Backup Size: ${avg_size}MB"
                    echo "      Total Backups Analyzed: ${#recent_backups[@]}"
                    
                    # Check backup frequency patterns
                    if [[ ${#backup_dates[@]} -gt 1 ]]; then
                        local max_gap=0
                        local min_gap=9999
                        local total_gap=0
                        local gap_count=0
                        
                        for ((i=0; i<${#backup_dates[@]}-1; i++)); do
                            local gap=$((${backup_dates[i]} - ${backup_dates[i+1]}))
                            if [[ $gap -gt $max_gap ]]; then max_gap=$gap; fi
                            if [[ $gap -lt $min_gap ]]; then min_gap=$gap; fi
                            total_gap=$((total_gap + gap))
                            ((gap_count++))
                        done
                        
                        if [[ $gap_count -gt 0 ]]; then
                            local avg_gap=$((total_gap / gap_count))
                            echo "      Backup Frequency (hours):"
                            echo "        Average Gap: $avg_gap"
                            echo "        Min Gap: $min_gap"
                            echo "        Max Gap: $max_gap"
                            
                            # Flag potential timing issues
                            if [[ $max_gap -gt 48 ]]; then
                                timing_issues+=("$backup_path: Large gap detected (${max_gap}h) - possible missed backups")
                            fi
                            if [[ $avg_gap -gt 36 && "$backup_path" =~ daily ]]; then
                                timing_issues+=("$backup_path: Daily backups averaging ${avg_gap}h intervals")
                            fi
                        fi
                    fi
                else
                    echo "    No backup files found"
                fi
                
                echo
                
            done < <(echo "$backup_paths" | jq -r '.[]' 2>/dev/null)
        fi
        
        echo "PERFORMANCE SUMMARY:"
        if [[ ${#timing_issues[@]} -gt 0 ]]; then
            echo "  Timing Issues Detected:"
            printf "    %s\\n" "${timing_issues[@]}"
        else
            echo "  Backup timing appears consistent"
        fi
        
    } > "$report_file"
    
    log_info "Backup performance report generated: $report_file"
    
    # Return success if no critical timing issues
    [[ ${#timing_issues[@]} -eq 0 ]]
}

# Generate intelligent backup recommendations
generate_backup_recommendations() {
    local report_file="${1:-/tmp/backup_recommendations_$(date +%Y%m%d).txt}"
    
    log_info "Generating backup recommendations"
    
    local recommendations=()
    local priority_actions=()
    
    {
        echo "Backup System Recommendations - $(date)"
        echo "======================================="
        echo
        
        # Analyze current backup configuration
        local backup_paths
        backup_paths=$(get_config 'modules.backup_monitor.backup_paths' '[]')
        
        local retention_days=$(get_config 'modules.backup_monitor.retention_days' '30')
        local verification_enabled=$(get_config 'modules.backup_monitor.verification_enabled' 'true')
        local checksum_validation=$(get_config 'modules.backup_monitor.integrity_checks.checksum_validation' 'true')
        
        echo "CURRENT CONFIGURATION ANALYSIS:"
        echo "  Configured Backup Paths: $(echo "$backup_paths" | jq length 2>/dev/null || echo "0")"
        echo "  Retention Period: $retention_days days"
        echo "  Verification Enabled: $verification_enabled"
        echo "  Checksum Validation: $checksum_validation"
        echo
        
        # Check for missing checksum files
        local missing_checksums=0
        if [[ "$checksum_validation" == "true" ]] && command -v jq >/dev/null 2>&1; then
            while IFS= read -r backup_path; do
                [[ -z "$backup_path" || "$backup_path" == "null" ]] && continue
                
                if [[ -d "$backup_path" ]]; then
                    while IFS= read -r -d '' backup_file; do
                        if [[ ! -f "${backup_file}.sha256" ]]; then
                            ((missing_checksums++))
                        fi
                    done < <(find "$backup_path" -type f \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.sql.gz" \) -print0 2>/dev/null)
                fi
            done < <(echo "$backup_paths" | jq -r '.[]' 2>/dev/null)
        fi
        
        echo "RECOMMENDATIONS:"
        echo
        
        # Security and integrity recommendations
        if [[ $missing_checksums -gt 0 ]]; then
            recommendations+=("SECURITY: Generate SHA256 checksums for $missing_checksums backup files to enable integrity verification")
            priority_actions+=("Create checksum files for existing backups")
        fi
        
        if [[ "$verification_enabled" != "true" ]]; then
            recommendations+=("RELIABILITY: Enable backup verification to detect corrupted backups early")
            priority_actions+=("Enable backup verification in configuration")
        fi
        
        # Storage optimization recommendations
        local total_storage_usage=0
        local storage_count=0
        
        if command -v jq >/dev/null 2>&1; then
            while IFS= read -r backup_path; do
                [[ -z "$backup_path" || "$backup_path" == "null" ]] && continue
                
                if [[ -d "$backup_path" ]]; then
                    local usage_percent=$(df "$backup_path" 2>/dev/null | tail -1 | awk '{gsub(/%/, "", $5); print $5}')
                    if [[ -n "$usage_percent" && "$usage_percent" -gt 0 ]]; then
                        total_storage_usage=$((total_storage_usage + usage_percent))
                        ((storage_count++))
                    fi
                fi
            done < <(echo "$backup_paths" | jq -r '.[]' 2>/dev/null)
        fi
        
        if [[ $storage_count -gt 0 ]]; then
            local avg_usage=$((total_storage_usage / storage_count))
            
            if [[ $avg_usage -gt 85 ]]; then
                recommendations+=("STORAGE: Average storage usage is ${avg_usage}% - consider additional storage or shorter retention")
                priority_actions+=("Expand backup storage capacity")
            elif [[ $avg_usage -gt 70 ]]; then
                recommendations+=("STORAGE: Monitor storage usage (${avg_usage}%) and plan for capacity expansion")
            fi
        fi
        
        # Backup frequency recommendations
        local backup_jobs
        backup_jobs=$(get_config 'modules.backup_monitor.backup_jobs' '{}')
        
        if command -v jq >/dev/null 2>&1 && [[ "$backup_jobs" != "{}" ]]; then
            local daily_jobs=$(echo "$backup_jobs" | jq '[.[] | select(.schedule == "daily")] | length' 2>/dev/null || echo 0)
            local weekly_jobs=$(echo "$backup_jobs" | jq '[.[] | select(.schedule == "weekly")] | length' 2>/dev/null || echo 0)
            
            if [[ $daily_jobs -eq 0 ]]; then
                recommendations+=("FREQUENCY: No daily backups configured - consider daily backups for critical data")
                priority_actions+=("Configure daily backup jobs for critical systems")
            fi
            
            if [[ $weekly_jobs -eq 0 && $daily_jobs -lt 3 ]]; then
                recommendations+=("FREQUENCY: Consider weekly backups for comprehensive system state")
            fi
        fi
        
        # Backup testing recommendations
        local restore_testing=$(get_config 'modules.backup_monitor.integrity_checks.restore_testing' 'false')
        if [[ "$restore_testing" != "true" ]]; then
            recommendations+=("TESTING: Enable restore testing to verify backup recoverability")
            priority_actions+=("Implement automated restore testing")
        fi
        
        # Offsite backup recommendations
        local offsite_configured=false
        if command -v jq >/dev/null 2>&1; then
            while IFS= read -r backup_path; do
                [[ -z "$backup_path" || "$backup_path" == "null" ]] && continue
                
                if [[ "$backup_path" =~ ^/mnt/ || "$backup_path" =~ remote ]]; then
                    offsite_configured=true
                    break
                fi
            done < <(echo "$backup_paths" | jq -r '.[]' 2>/dev/null)
        fi
        
        if [[ "$offsite_configured" != "true" ]]; then
            recommendations+=("DISASTER_RECOVERY: Configure offsite/remote backup storage for disaster recovery")
            priority_actions+=("Set up offsite backup replication")
        fi
        
        # Output recommendations
        if [[ ${#recommendations[@]} -gt 0 ]]; then
            local priority_count=1
            for recommendation in "${recommendations[@]}"; do
                local category=$(echo "$recommendation" | cut -d: -f1)
                local description=$(echo "$recommendation" | cut -d: -f2-)
                printf "  %d. [%s]%s\\n" $priority_count "$category" "$description"
                ((priority_count++))
            done
        else
            echo "  Backup configuration appears optimal - no immediate recommendations"
        fi
        
        echo
        echo "PRIORITY ACTIONS:"
        if [[ ${#priority_actions[@]} -gt 0 ]]; then
            for action in "${priority_actions[@]}"; do
                echo "  • $action"
            done
        else
            echo "  No immediate priority actions required"
        fi
        
        echo
        echo "BEST PRACTICES REMINDER:"
        echo "  • Test backup restoration regularly"
        echo "  • Monitor backup storage capacity"
        echo "  • Verify backup integrity automatically"
        echo "  • Maintain multiple backup copies (3-2-1 rule)"
        echo "  • Document backup and recovery procedures"
        echo "  • Review and update retention policies periodically"
        
    } > "$report_file"
    
    log_info "Backup recommendations generated: $report_file"
    return 0
}

# Generate comprehensive HTML backup management report
generate_backup_report() {
    local report_file="${1:-/var/log/bash-admin/daily-reports/backup_management_$(date +%Y%m%d).html}"
    
    log_info "Generating comprehensive backup report"
    
    # Ensure report directory exists
    mkdir -p "$(dirname "$report_file")"
    
    # Generate all component reports first
    local report_dir="/var/log/bash-admin/daily-reports"
    local today=$(date +%Y%m%d)
    
    monitor_backup_jobs "$report_dir/backup_jobs_$today.txt"
    verify_backup_integrity "$report_dir/backup_integrity_$today.txt"
    manage_backup_storage "$report_dir/backup_storage_$today.txt"
    analyze_backup_performance "$report_dir/backup_performance_$today.txt"
    generate_backup_recommendations "$report_dir/backup_recommendations_$today.txt"
    
    # Get summary statistics
    local total_backup_paths=$(get_config 'modules.backup_monitor.backup_paths' '[]' | jq length 2>/dev/null || echo "0")
    local backup_enabled=$(get_config 'modules.backup_monitor.enabled' 'true')
    local verification_enabled=$(get_config 'modules.backup_monitor.verification_enabled' 'true')
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Backup Management Report - $(date)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
        .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 15px; margin-bottom: 20px; }
        .summary-card { background: #f8f9fa; border: 1px solid #dee2e6; border-radius: 8px; padding: 15px; }
        .summary-card h3 { margin-top: 0; color: #495057; }
        .metric-good { color: #28a745; font-weight: bold; }
        .metric-warning { color: #ffc107; font-weight: bold; }
        .metric-danger { color: #dc3545; font-weight: bold; }
        .tabs { border-bottom: 2px solid #dee2e6; margin-bottom: 20px; }
        .tab-button { background: none; border: none; padding: 12px 24px; cursor: pointer; font-size: 16px; border-bottom: 3px solid transparent; }
        .tab-button.active { border-bottom-color: #007bff; color: #007bff; font-weight: bold; }
        .tab-button:hover { background-color: #f8f9fa; }
        .tab-content { display: none; }
        .tab-content.active { display: block; }
        .section { background: white; border: 1px solid #dee2e6; border-radius: 8px; padding: 20px; margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { border: 1px solid #dee2e6; padding: 12px; text-align: left; }
        th { background-color: #f8f9fa; font-weight: bold; }
        .status-success { background-color: #d4edda; color: #155724; }
        .status-warning { background-color: #fff3cd; color: #856404; }
        .status-danger { background-color: #f8d7da; color: #721c24; }
        .progress-bar { width: 100%; height: 20px; background-color: #e9ecef; border-radius: 10px; overflow: hidden; }
        .progress-fill { height: 100%; background: linear-gradient(90deg, #28a745, #20c997); transition: width 0.3s ease; }
        .alert { padding: 15px; border-radius: 5px; margin: 10px 0; }
        .alert-info { background-color: #d1ecf1; border: 1px solid #bee5eb; color: #0c5460; }
        .alert-warning { background-color: #fff3cd; border: 1px solid #ffeaa7; color: #856404; }
        .alert-danger { background-color: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; }
        pre { background-color: #f8f9fa; padding: 15px; border-radius: 5px; overflow-x: auto; font-size: 14px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🗂️ Backup Management Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Server:</strong> $(hostname)</p>
        <p><strong>Module Status:</strong> $(echo "$backup_enabled" | sed 's/true/✅ Enabled/g' | sed 's/false/❌ Disabled/g')</p>
    </div>

    <div class="summary-grid">
        <div class="summary-card">
            <h3>📊 Backup Overview</h3>
            <p><strong>Backup Paths:</strong> <span class="metric-good">$total_backup_paths</span></p>
            <p><strong>Verification:</strong> $(echo "$verification_enabled" | sed 's/true/<span class="metric-good">Enabled<\/span>/g' | sed 's/false/<span class="metric-warning">Disabled<\/span>/g')</p>
            <p><strong>Last Check:</strong> $(date '+%H:%M')</p>
        </div>
        
        <div class="summary-card">
            <h3>💾 Storage Status</h3>
EOF

    # Add dynamic storage information
    if command -v jq >/dev/null 2>&1; then
        local backup_paths
        backup_paths=$(get_config 'modules.backup_monitor.backup_paths' '[]')
        
        local total_usage=0
        local path_count=0
        
        while IFS= read -r backup_path; do
            [[ -z "$backup_path" || "$backup_path" == "null" ]] && continue
            
            if [[ -d "$backup_path" ]]; then
                local usage_percent=$(df "$backup_path" 2>/dev/null | tail -1 | awk '{gsub(/%/, "", $5); print $5}')
                if [[ -n "$usage_percent" && "$usage_percent" -gt 0 ]]; then
                    total_usage=$((total_usage + usage_percent))
                    ((path_count++))
                fi
            fi
        done < <(echo "$backup_paths" | jq -r '.[]' 2>/dev/null)
        
        if [[ $path_count -gt 0 ]]; then
            local avg_usage=$((total_usage / path_count))
            local status_class="metric-good"
            if [[ $avg_usage -gt 90 ]]; then
                status_class="metric-danger"
            elif [[ $avg_usage -gt 80 ]]; then
                status_class="metric-warning"
            fi
            
            cat >> "$report_file" << EOF
            <p><strong>Average Usage:</strong> <span class="$status_class">${avg_usage}%</span></p>
            <div class="progress-bar">
                <div class="progress-fill" style="width: ${avg_usage}%"></div>
            </div>
EOF
        else
            cat >> "$report_file" << 'EOF'
            <p><strong>Status:</strong> <span class="metric-warning">No accessible paths</span></p>
EOF
        fi
    fi

    cat >> "$report_file" << 'EOF'
        </div>
        
        <div class="summary-card">
            <h3>🔍 Recent Activity</h3>
EOF

    # Add recent backup count
    local recent_backups=0
    if command -v jq >/dev/null 2>&1; then
        local backup_paths
        backup_paths=$(get_config 'modules.backup_monitor.backup_paths' '[]')
        
        while IFS= read -r backup_path; do
            [[ -z "$backup_path" || "$backup_path" == "null" ]] && continue
            
            if [[ -d "$backup_path" ]]; then
                local path_recent=$(find "$backup_path" -type f -mtime -1 \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.sql.gz" \) 2>/dev/null | wc -l)
                recent_backups=$((recent_backups + path_recent))
            fi
        done < <(echo "$backup_paths" | jq -r '.[]' 2>/dev/null)
    fi

    cat >> "$report_file" << EOF
            <p><strong>Recent Backups (24h):</strong> <span class="metric-good">$recent_backups</span></p>
            <p><strong>Status:</strong> $([ $recent_backups -gt 0 ] && echo '<span class="metric-good">Active</span>' || echo '<span class="metric-warning">No Recent</span>')</p>
            <p><strong>Next Check:</strong> $(date -d 'tomorrow 06:00' '+%m/%d %H:%M')</p>
EOF

    cat >> "$report_file" << 'EOF'
        </div>
        
        <div class="summary-card">
            <h3>⚡ System Health</h3>
EOF

    # System health indicators
    local health_score=100
    local health_issues=()
    
    # Check if backups are recent
    if [[ $recent_backups -eq 0 ]]; then
        health_score=$((health_score - 30))
        health_issues+=("No recent backups")
    fi
    
    # Check verification status
    if [[ "$verification_enabled" != "true" ]]; then
        health_score=$((health_score - 20))
        health_issues+=("Verification disabled")
    fi
    
    local health_class="metric-good"
    local health_status="Excellent"
    if [[ $health_score -lt 70 ]]; then
        health_class="metric-danger"
        health_status="Needs Attention"
    elif [[ $health_score -lt 85 ]]; then
        health_class="metric-warning"
        health_status="Good"
    fi

    cat >> "$report_file" << EOF
            <p><strong>Health Score:</strong> <span class="$health_class">${health_score}/100</span></p>
            <p><strong>Status:</strong> <span class="$health_class">$health_status</span></p>
            <div class="progress-bar">
                <div class="progress-fill" style="width: ${health_score}%"></div>
            </div>
EOF

    cat >> "$report_file" << 'EOF'
        </div>
    </div>

    <div class="tabs">
        <button class="tab-button active" onclick="showTab('jobs')">📋 Backup Jobs</button>
        <button class="tab-button" onclick="showTab('integrity')">🔒 Integrity</button>
        <button class="tab-button" onclick="showTab('storage')">💾 Storage</button>
        <button class="tab-button" onclick="showTab('performance')">📈 Performance</button>
        <button class="tab-button" onclick="showTab('recommendations')">💡 Recommendations</button>
    </div>

    <div id="jobs-tab" class="tab-content active">
        <div class="section">
            <h2>📋 Backup Jobs Status</h2>
EOF

    # Include backup jobs report content
    if [[ -f "$report_dir/backup_jobs_$today.txt" ]]; then
        echo "            <pre>" >> "$report_file"
        cat "$report_dir/backup_jobs_$today.txt" >> "$report_file"
        echo "            </pre>" >> "$report_file"
    else
        echo "            <div class='alert alert-warning'>Backup jobs report not available</div>" >> "$report_file"
    fi

    cat >> "$report_file" << 'EOF'
        </div>
    </div>

    <div id="integrity-tab" class="tab-content">
        <div class="section">
            <h2>🔒 Backup Integrity Verification</h2>
EOF

    # Include integrity report content
    if [[ -f "$report_dir/backup_integrity_$today.txt" ]]; then
        echo "            <pre>" >> "$report_file"
        cat "$report_dir/backup_integrity_$today.txt" >> "$report_file"
        echo "            </pre>" >> "$report_file"
    else
        echo "            <div class='alert alert-warning'>Integrity verification report not available</div>" >> "$report_file"
    fi

    cat >> "$report_file" << 'EOF'
        </div>
    </div>

    <div id="storage-tab" class="tab-content">
        <div class="section">
            <h2>💾 Storage Management</h2>
EOF

    # Include storage report content
    if [[ -f "$report_dir/backup_storage_$today.txt" ]]; then
        echo "            <pre>" >> "$report_file"
        cat "$report_dir/backup_storage_$today.txt" >> "$report_file"
        echo "            </pre>" >> "$report_file"
    else
        echo "            <div class='alert alert-warning'>Storage management report not available</div>" >> "$report_file"
    fi

    cat >> "$report_file" << 'EOF'
        </div>
    </div>

    <div id="performance-tab" class="tab-content">
        <div class="section">
            <h2>📈 Performance Analysis</h2>
EOF

    # Include performance report content
    if [[ -f "$report_dir/backup_performance_$today.txt" ]]; then
        echo "            <pre>" >> "$report_file"
        cat "$report_dir/backup_performance_$today.txt" >> "$report_file"
        echo "            </pre>" >> "$report_file"
    else
        echo "            <div class='alert alert-warning'>Performance analysis report not available</div>" >> "$report_file"
    fi

    cat >> "$report_file" << 'EOF'
        </div>
    </div>

    <div id="recommendations-tab" class="tab-content">
        <div class="section">
            <h2>💡 Backup Recommendations</h2>
EOF

    # Include recommendations report content
    if [[ -f "$report_dir/backup_recommendations_$today.txt" ]]; then
        echo "            <pre>" >> "$report_file"
        cat "$report_dir/backup_recommendations_$today.txt" >> "$report_file"
        echo "            </pre>" >> "$report_file"
    else
        echo "            <div class='alert alert-warning'>Recommendations report not available</div>" >> "$report_file"
    fi

    cat >> "$report_file" << 'EOF'
        </div>
    </div>

    <div class="section">
        <h2>📁 Quick Links</h2>
        <ul>
EOF

    # Add links to individual reports
    cat >> "$report_file" << EOF
            <li><a href="backup_jobs_$today.txt">📋 Backup Jobs Detail Report</a></li>
            <li><a href="backup_integrity_$today.txt">🔒 Integrity Verification Detail</a></li>
            <li><a href="backup_storage_$today.txt">💾 Storage Management Detail</a></li>
            <li><a href="backup_performance_$today.txt">📈 Performance Analysis Detail</a></li>
            <li><a href="backup_recommendations_$today.txt">💡 Recommendations Detail</a></li>
EOF

    cat >> "$report_file" << 'EOF'
        </ul>
    </div>

    <div class="section">
        <p><em>📊 Report generated by Linux Automation System - Backup Management Module</em></p>
        <p><em>🕐 Generated at $(date)</em></p>
        <p><em>🔄 Next backup check scheduled for $(date -d 'tomorrow 06:00' '+%Y-%m-%d at %H:%M')</em></p>
    </div>

    <script>
        function showTab(tabName) {
            // Hide all tab contents
            var contents = document.getElementsByClassName('tab-content');
            for (var i = 0; i < contents.length; i++) {
                contents[i].classList.remove('active');
            }
            
            // Remove active class from all buttons
            var buttons = document.getElementsByClassName('tab-button');
            for (var i = 0; i < buttons.length; i++) {
                buttons[i].classList.remove('active');
            }
            
            // Show selected tab and mark button as active
            document.getElementById(tabName + '-tab').classList.add('active');
            event.target.classList.add('active');
        }
    </script>
</body>
</html>
EOF

    log_info "Comprehensive backup report generated: $report_file"
    return 0
}

# Main backup management orchestration function
run_backup_management() {
    log_info "Starting comprehensive backup management"
    
    local overall_status=0
    local report_dir="/var/log/bash-admin/daily-reports"
    local today=$(date +%Y%m%d)
    
    # Ensure report directory exists
    mkdir -p "$report_dir"
    
    # Check if backup management is enabled
    local enabled=$(get_config 'modules.backup_monitor.enabled' 'true')
    if [[ "$enabled" != "true" ]]; then
        log_info "Backup management module is disabled"
        return 0
    fi
    
    # Run all backup management functions
    log_info "Monitoring backup jobs..."
    if ! monitor_backup_jobs "$report_dir/backup_jobs_$today.txt"; then
        log_warn "Backup job monitoring found issues"
        overall_status=1
    fi
    
    log_info "Verifying backup integrity..."
    if ! verify_backup_integrity "$report_dir/backup_integrity_$today.txt"; then
        log_warn "Backup integrity verification found issues"
        overall_status=1
    fi
    
    log_info "Managing backup storage..."
    if ! manage_backup_storage "$report_dir/backup_storage_$today.txt"; then
        log_warn "Backup storage management found issues"
        overall_status=1
    fi
    
    log_info "Analyzing backup performance..."
    if ! analyze_backup_performance "$report_dir/backup_performance_$today.txt"; then
        log_warn "Backup performance analysis found issues"
        overall_status=1
    fi
    
    log_info "Generating recommendations..."
    generate_backup_recommendations "$report_dir/backup_recommendations_$today.txt"
    
    log_info "Creating comprehensive report..."
    if ! generate_backup_report "$report_dir/backup_management_$today.html"; then
        log_warn "Backup management report completed with issues detected"
        overall_status=1
    fi
    
    # Send notification if issues detected
    if [[ $overall_status -ne 0 ]]; then
        local recipient=$(get_config "notifications.recipients.admin")
        if [[ -n "$recipient" ]]; then
            send_notification "$recipient" "Backup Management Issues" \
                "Backup management completed with issues. Check $report_dir/backup_management_$today.html for details."
        fi
    fi
    
    return $overall_status
}

# Export functions for use by other scripts
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f monitor_backup_jobs
    export -f verify_backup_integrity
    export -f manage_backup_storage
    export -f analyze_backup_performance
    export -f generate_backup_recommendations
    export -f generate_backup_report
    export -f run_backup_management
fi