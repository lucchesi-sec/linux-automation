#!/bin/bash
# Backup Monitoring Module
# Provides functions for backup verification and monitoring

# Source core libraries
source "$(dirname "$0")/../../core/lib/init.sh"

# Verify backup integrity and completeness
verify_backup_integrity() {
    local backup_path="$1"
    local expected_size="$2"
    local max_age_hours="${3:-24}"
    
    if [[ -z "$backup_path" ]]; then
        log_error "Backup path required for integrity verification"
        return 1
    fi
    
    log_info "Verifying backup integrity: $backup_path"
    
    # Check if backup exists
    if [[ ! -e "$backup_path" ]]; then
        log_error "Backup file/directory not found: $backup_path"
        return 1
    fi
    
    # Check backup age
    local backup_age_seconds
    if [[ -f "$backup_path" ]]; then
        backup_age_seconds=$(( $(date +%s) - $(stat -c %Y "$backup_path") ))
    else
        backup_age_seconds=$(( $(date +%s) - $(find "$backup_path" -type f -printf '%T@\n' | sort -n | tail -1 | cut -d. -f1) ))
    fi
    
    local max_age_seconds=$((max_age_hours * 3600))
    if [[ $backup_age_seconds -gt $max_age_seconds ]]; then
        log_error "Backup is too old: $((backup_age_seconds / 3600)) hours (max: $max_age_hours hours)"
        return 1
    fi
    
    # Check backup size if expected size provided
    if [[ -n "$expected_size" ]]; then
        local actual_size
        if [[ -f "$backup_path" ]]; then
            actual_size=$(stat -c %s "$backup_path")
        else
            actual_size=$(du -sb "$backup_path" | cut -f1)
        fi
        
        local size_diff=$((actual_size - expected_size))
        local size_diff_percent=$((size_diff * 100 / expected_size))
        
        # Allow 10% variance in backup size
        if [[ $size_diff_percent -gt 10 || $size_diff_percent -lt -10 ]]; then
            log_warn "Backup size variance: ${size_diff_percent}% (expected: $expected_size, actual: $actual_size)"
        fi
    fi
    
    # Verify file integrity based on backup type
    if [[ "$backup_path" =~ \.tar\.gz$ || "$backup_path" =~ \.tgz$ ]]; then
        if ! tar -tzf "$backup_path" >/dev/null 2>&1; then
            log_error "Backup archive integrity check failed: $backup_path"
            return 1
        fi
    elif [[ "$backup_path" =~ \.zip$ ]]; then
        if ! unzip -t "$backup_path" >/dev/null 2>&1; then
            log_error "Backup archive integrity check failed: $backup_path"
            return 1
        fi
    elif [[ "$backup_path" =~ \.sql$ || "$backup_path" =~ \.sql\.gz$ ]]; then
        # Basic SQL dump validation
        if [[ "$backup_path" =~ \.gz$ ]]; then
            if ! zcat "$backup_path" | head -20 | grep -q "SQL dump\|CREATE\|INSERT"; then
                log_error "SQL backup validation failed: $backup_path"
                return 1
            fi
        else
            if ! head -20 "$backup_path" | grep -q "SQL dump\|CREATE\|INSERT"; then
                log_error "SQL backup validation failed: $backup_path"
                return 1
            fi
        fi
    fi
    
    log_success "Backup integrity verification passed: $backup_path"
    return 0
}

# Monitor backup processes and report status
monitor_backup_jobs() {
    local config_file="${1:-$(get_config 'backup.config_file')}"
    local report_file="${2:-/tmp/backup_status_$(date +%Y%m%d).txt}"
    local failed_backups=()
    local successful_backups=()
    
    log_info "Monitoring backup jobs status"
    
    # Read backup configuration
    if [[ ! -f "$config_file" ]]; then
        log_error "Backup configuration file not found: $config_file"
        return 1
    fi
    
    # Parse backup jobs from config
    while IFS=',' read -r job_name backup_path schedule retention; do
        # Skip comments and empty lines
        [[ "$job_name" =~ ^#.*$ || -z "$job_name" ]] && continue
        
        log_debug "Checking backup job: $job_name"
        
        # Check if backup exists and is recent
        if verify_backup_integrity "$backup_path" "" 24; then
            successful_backups+=("$job_name: OK")
            log_success "Backup job $job_name: SUCCESS"
        else
            failed_backups+=("$job_name: FAILED")
            log_error "Backup job $job_name: FAILED"
        fi
        
    done < "$config_file"
    
    # Generate status report
    {
        echo "Backup Jobs Status Report - $(date)"
        echo "===================================="
        echo
        echo "SUCCESSFUL BACKUPS:"
        if [[ ${#successful_backups[@]} -eq 0 ]]; then
            echo "  None"
        else
            printf "  %s\n" "${successful_backups[@]}"
        fi
        echo
        echo "FAILED BACKUPS:"
        if [[ ${#failed_backups[@]} -eq 0 ]]; then
            echo "  None"
        else
            printf "  %s\n" "${failed_backups[@]}"
        fi
        echo
        echo "SUMMARY:"
        echo "  Total Jobs: $((${#successful_backups[@]} + ${#failed_backups[@]}))"
        echo "  Successful: ${#successful_backups[@]}"
        echo "  Failed: ${#failed_backups[@]}"
    } > "$report_file"
    
    log_info "Backup status report generated: $report_file"
    
    # Send notification if failures detected
    if [[ ${#failed_backups[@]} -gt 0 ]]; then
        send_notification "admin" "Backup Job Failures" \
            "Found ${#failed_backups[@]} failed backup jobs. Check $report_file for details."
    fi
    
    return ${#failed_backups[@]}
}

# Check backup storage space and cleanup old backups
manage_backup_storage() {
    local backup_dir="$1"
    local retention_days="${2:-30}"
    local warning_threshold="${3:-85}"
    local critical_threshold="${4:-95}"
    
    if [[ -z "$backup_dir" ]]; then
        log_error "Backup directory required"
        return 1
    fi
    
    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup directory not found: $backup_dir"
        return 1
    fi
    
    log_info "Managing backup storage: $backup_dir"
    
    # Check disk space usage
    local usage_percent=$(df "$backup_dir" | awk 'NR==2 {print int($5)}')
    log_info "Backup storage usage: ${usage_percent}%"
    
    if [[ $usage_percent -ge $critical_threshold ]]; then
        log_error "CRITICAL: Backup storage usage at ${usage_percent}% (threshold: ${critical_threshold}%)"
        send_notification "admin" "Critical Backup Storage" \
            "Backup storage at ${usage_percent}% capacity. Immediate attention required."
    elif [[ $usage_percent -ge $warning_threshold ]]; then
        log_warn "WARNING: Backup storage usage at ${usage_percent}% (threshold: ${warning_threshold}%)"
        send_notification "admin" "Backup Storage Warning" \
            "Backup storage at ${usage_percent}% capacity. Consider cleanup."
    fi
    
    # Clean up old backups
    local files_removed=0
    local space_freed=0
    
    log_info "Removing backups older than $retention_days days"
    
    while IFS= read -r -d '' file; do
        local file_size=$(stat -c %s "$file")
        if rm -f "$file"; then
            ((files_removed++))
            space_freed=$((space_freed + file_size))
            log_debug "Removed old backup: $file"
        fi
    done < <(find "$backup_dir" -type f -mtime +$retention_days -print0 2>/dev/null)
    
    if [[ $files_removed -gt 0 ]]; then
        local space_freed_mb=$((space_freed / 1024 / 1024))
        log_info "Cleanup completed: $files_removed files removed, ${space_freed_mb}MB freed"
    else
        log_info "No old backups found for cleanup"
    fi
    
    return 0
}

# Test backup restoration process
test_backup_restore() {
    local backup_file="$1"
    local test_dir="${2:-/tmp/backup_restore_test_$(date +%s)}"
    local restore_files="${3:-5}"  # Number of files to test restore
    
    if [[ -z "$backup_file" ]]; then
        log_error "Backup file required for restore test"
        return 1
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    log_info "Testing backup restore: $backup_file"
    
    # Create test directory
    mkdir -p "$test_dir"
    
    local restore_success=true
    
    # Test restore based on backup type
    if [[ "$backup_file" =~ \.tar\.gz$ || "$backup_file" =~ \.tgz$ ]]; then
        # Extract a few files to test
        if tar -tzf "$backup_file" | head -$restore_files | xargs tar -xzf "$backup_file" -C "$test_dir" 2>/dev/null; then
            log_success "Tar archive restore test successful"
        else
            log_error "Tar archive restore test failed"
            restore_success=false
        fi
    elif [[ "$backup_file" =~ \.zip$ ]]; then
        # Extract a few files to test
        if unzip -q "$backup_file" -d "$test_dir" $(unzip -Z1 "$backup_file" | head -$restore_files) 2>/dev/null; then
            log_success "Zip archive restore test successful"
        else
            log_error "Zip archive restore test failed"
            restore_success=false
        fi
    else
        log_warn "Cannot test restore for backup type: $backup_file"
    fi
    
    # Cleanup test directory
    rm -rf "$test_dir"
    
    if $restore_success; then
        log_success "Backup restore test completed successfully"
        return 0
    else
        log_error "Backup restore test failed"
        return 1
    fi
}

# Export functions for use by other scripts
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f verify_backup_integrity
    export -f monitor_backup_jobs
    export -f manage_backup_storage
    export -f test_backup_restore
fi