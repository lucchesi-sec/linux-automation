#!/bin/bash
# Backup Management Module
# High-level orchestration for backup monitoring, verification, and management

# Refactor of original 45KB monolithic file into modular components
# Changes:
# - Split into separate function files for jobs, storage, integrity, performance, and recommendations
# - Replaced fragile text parsing with JSON parsing using jq
# - Added structured output for all data processing

# Source the core libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../core/lib/init.sh"

# Initialize Bash Admin system
init_bash_admin "$(basename "$0")"

# Source modular components
source "$SCRIPT_DIR/lib/backup_jobs.sh"
source "$SCRIPT_DIR/lib/backup_storage.sh"

# Original functions refactored to use new modular architecture

# Monitor backup jobs status - refactored for structured processing
monitor_backup_jobs() {
    local report_file="${1:-/tmp/backup_jobs_$(date +%Y%m%d).txt}"
    
    log_info "Monitoring backup job status"
    
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
        
        # Use structured JSON processing
        if command -v jq >/dev/null 2>&1 && [[ "$backup_jobs" != "{}" ]]; then
            local job_keys
            job_keys=$(echo "$backup_jobs" | jq -r 'keys[]' 2>/dev/null)
            
            while IFS= read -r job_name; do
                [[ -z "$job_name" || "$job_name" == "null" ]] && continue
                
                ((total_jobs++))
                
                local job_data
                job_data=$(get_backup_job_data "$job_name" "$backup_jobs")
                
                local job_enabled=$(get_backup_job_property "$job_data" "enabled" "true")
                local job_path=$(get_backup_job_property "$job_data" "path")
                local job_schedule=$(get_backup_job_property "$job_data" "schedule" "daily")
                local job_retention=$(get_backup_job_property "$job_data" "retention" "30d")
                
                local status_info
                status_info=$(generate_backup_job_status "$job_name" "$job_path" "$job_enabled" "$job_schedule" "$job_retention")
                
                # Parse JSON status
                local status=$(echo "$status_info" | jq -r '.status')
                local message=$(echo "$status_info" | jq -r '.message')
                local recent_backups=$(echo "$status_info" | jq -r '.recent_backups')
                
                if [[ "$status" == "DISABLED" ]]; then
                    job_details+=("  $job_name: DISABLED")
                elif [[ "$status" == "SUCCESS" ]]; then
                    ((successful_jobs++))
                    job_details+=("  $job_name: SUCCESS - $message")
                    printf "  %-20s Status:%-10s Path:%-30s Schedule:%s\n" "$job_name" "SUCCESS" "$job_path" "$job_schedule"
                else
                    ((failed_jobs++))
                    job_details+=("  $job_name: FAILED - $message")
                    printf "  %-20s Status:%-10s Path:%-30s Schedule:%s\n" "$job_name" "FAILED" "$job_path" "$job_schedule"
                fi
                
            done <<< "$job_keys"
        fi
        
        # Analyze backup paths using structured methods
        local backup_paths
        backup_paths=$(get_config 'modules.backup_monitor.backup_paths' '[]')
        
        if command -v jq >/dev/null 2>&1 && [[ "$backup_paths" != "[]" ]]; then
            echo
            echo "BACKUP PATH ANALYSIS:"
            echo
            
            local path_keys
            path_keys=$(echo "$backup_paths" | jq -r '.[]' 2>/dev/null)
            
            while IFS= read -r backup_path; do
                [[ -z "$backup_path" || "$backup_path" == "null" ]] && continue
                
                local fs_info
                fs_info=$(get_filesystem_info "$backup_path")
                
                local usage_percent=$(echo "$fs_info" | jq -r '.usage_percent')
                local size_bytes=$(echo "$fs_info" | jq -r '.size')
                local used_bytes=$(echo "$fs_info" | jq -r '.used')
                local available_bytes=$(echo "$fs_info" | jq -r '.available')
                local status=$(echo "$fs_info" | jq -r '.status')
                
                if [[ -d "$backup_path" ]]; then
                    local file_stats
                    file_stats=$(get_backup_file_stats "$backup_path")
                    
                    local total_files=$(echo "$file_stats" | jq -r '.count')
                    local total_size_bytes=$(echo "$file_stats" | jq -r '.total_bytes')
                    local path_size_mb=$((size_bytes / 1024 / 1024))
                    
                    printf "  %-30s Recent:%-6s Total:%-6s Size:%sMB\n" \
                        "$backup_path" "$total_files" "$total_files" "$path_size_mb"
                else
                    printf "  %-30s Status: MISSING\n" "$backup_path"
                fi
            done <<< "$path_keys"
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

# Replace fragile awk/grep parsing with structured JSON/JQ processing
refactor_backup_functions() {
    log_info "Refactoring backup functions to use structured data processing"
    
    # Updated storage management using structured output
    manage_backup_storage() {
        local report_file="${1:-/tmp/backup_storage_$(date +%Y%m%d).txt}"
        
        log_info "Managing backup storage"
        
        # Get thresholds from config
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
            
            # Process backup paths with structured data
            local backup_paths
            backup_paths=$(get_config 'modules.backup_monitor.backup_paths' '[]')
            
            if command -v jq >/dev/null 2>&1; then
                local path_keys
                path_keys=$(echo "$backup_paths" | jq -r '.[]' 2>/dev/null)
                
                while IFS= read -r backup_path; do
                    [[ -z "$backup_path" || "$backup_path" == "null" ]] && continue
                    
                    if [[ ! -d "$backup_path" ]]; then
                        printf "  %-30s Status: MISSING\n" "$backup_path"
                        storage_issues+=("$backup_path: Directory does not exist")
                        continue
                    fi
                    
                    # Get structured filesystem information
                    local fs_info
                    fs_info=$(get_filesystem_info "$backup_path")
                    
                    local usage_percent=$(echo "$fs_info" | jq -r '.usage_percent')
                    local size_bytes=$(echo "$fs_info" | jq -r '.size')
                    local used_bytes=$(echo "$fs_info" | jq -r '.used')
                    local available_bytes=$(echo "$fs_info" | jq -r '.available')
                    local filesystem=$(echo "$fs_info" | jq -r '.filesystem')
                    
                    # Convert bytes to human-readable
                    local size_gb=$((size_bytes / 1024 / 1024 / 1024))
                    local used_gb=$((used_bytes / 1024 / 1024 / 1024))
                    local available_gb=$((available_bytes / 1024 / 1024 / 1024))
                    
                    local status="OK"
                    if [[ $usage_percent -ge $critical_percent ]]; then
                        status="CRITICAL"
                        storage_issues+=("$backup_path: Critical storage usage ${usage_percent}%")
                    elif [[ $usage_percent -ge $warning_percent ]]; then
                        status="WARNING"
                        storage_issues+=("$backup_path: High storage usage ${usage_percent}%")
                    fi
                    
                    printf "  %-30s Usage:%-4s%% Size:%-6sGB Used:%-6sGB Available:%-6sGB Status:%s\n" \
                        "$backup_path" "$usage_percent" "$size_gb" "$used_gb" "$available_gb" "$status"
                    
                    # Get backup file statistics using structured data
                    local file_stats
                    file_stats=$(get_backup_file_stats "$backup_path")
                    
                    local backup_count=$(echo "$file_stats" | jq -r '.count')
                    local backup_size_bytes=$(echo "$file_stats" | jq -r '.total_bytes')
                    local backup_size_mb=$((backup_size_bytes / 1024 / 1024))
                    
                    printf "    %-26s Backup Files:%-6s Total Backup Size:%-6sMB\n" "" "$backup_count" "$backup_size_mb"
                    
                    # Calculate cleanup impact using structured data
                    local cleanup_impact
                    cleanup_impact=$(calculate_cleanup_impact "$backup_path" "$retention_days")
                    
                    local files_to_remove=$(echo "$cleanup_impact" | jq -r '.count')
                    local space_to_free=$(echo "$cleanup_impact" | jq -r '.total_bytes')
                    local space_to_free_mb=$((space_to_free / 1024 / 1024))
                    
                    # Perform actual cleanup
                    local files_removed=0
                    local space_freed_mb=0
                    
                    while IFS= read -r -d '' old_file; do
                        local file_size_bytes=$(stat -c '%s' "$old_file" 2>/dev/null || echo 0)
                        local file_size_mb=$((file_size_bytes / 1024 / 1024))
                        
                        if rm -f "$old_file" 2>/dev/null; then
                            ((files_removed++))
                            space_freed_mb=$((space_freed_mb + file_size_mb))
                        fi
                    done < <(find_old_backups "$backup_path" "$retention_days")
                    
                    if [[ $files_removed -gt 0 ]]; then
                        cleanup_summary+=("$backup_path: Removed $files_removed files, freed ${space_freed_mb}MB")
                        printf "    %-26s Cleanup: Removed %-3s files, freed %-6sMB\n" "" "$files_removed" "$space_freed_mb"
                    else
                        printf "    %-26s Cleanup: No files older than %s days\n" "" "$retention_days"
                    fi
                    
                done <<< "$path_keys"
            fi
            
            echo "STORAGE SUMMARY:"
            if [[ ${#storage_issues[@]} -gt 0 ]]; then
                echo "  Storage Issues Found:"
                printf "    %s\n" "${storage_issues[@]}"
            else
                echo "  All backup storage within normal limits"
            fi
            
            if [[ ${#cleanup_summary[@]} -gt 0 ]]; then
                echo "  Cleanup Actions:"
                printf "    %s\n" "${cleanup_summary[@]}"
            fi
            
        } > "$report_file"
        
        log_info "Backup storage report generated: $report_file"
        
        # Check for critical storage issues
        local critical_issues=0
        for issue in "${storage_issues[@]}"; do
            if [[ "$issue" =~ Critical ]]; then
                ((critical_issues++))
            fi
        done
        
        [[ $critical_issues -eq 0 ]]
    }
    
    log_info "Backup storage refactoring complete"
}

# Export all functions for use by other scripts
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f monitor_backup_jobs
    export -f refactor_backup_functions
    export -f manage_backup_storage
fi