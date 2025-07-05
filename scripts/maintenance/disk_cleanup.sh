#!/bin/bash

# Disk Cleanup and Maintenance Script
# Automated disk space cleanup with configurable retention policies

# Source the core library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../core/lib/init.sh"

# Initialize
init_bash_admin "$(basename "$0")"

# Clean temporary files
clean_temp_files() {
    log_info "Cleaning temporary files" "DISK_CLEANUP"
    
    local temp_dirs=("/tmp" "/var/tmp")
    local files_cleaned=0
    local space_freed=0
    
    for temp_dir in "${temp_dirs[@]}"; do
        if [[ -d "$temp_dir" ]]; then
            log_debug "Cleaning directory: $temp_dir" "DISK_CLEANUP"
            
            # Find and remove files older than 7 days
            local old_files
            old_files=$(find "$temp_dir" -type f -mtime +7 -not -path "*/.*" 2>/dev/null | wc -l)
            
            if [[ "$old_files" -gt 0 ]]; then
                # Calculate space before cleanup
                local space_before
                space_before=$(du -s "$temp_dir" 2>/dev/null | awk '{print $1}')
                
                # Remove old files
                find "$temp_dir" -type f -mtime +7 -not -path "*/.*" -delete 2>/dev/null
                
                # Calculate space after cleanup
                local space_after
                space_after=$(du -s "$temp_dir" 2>/dev/null | awk '{print $1}')
                
                local space_diff=$((space_before - space_after))
                files_cleaned=$((files_cleaned + old_files))
                space_freed=$((space_freed + space_diff))
                
                log_info "Cleaned $old_files files from $temp_dir" "DISK_CLEANUP"
            fi
        fi
    done
    
    log_success "Temporary file cleanup completed: $files_cleaned files, $((space_freed / 1024)) MB freed" "DISK_CLEANUP"
}

# Clean package cache
clean_package_cache() {
    log_info "Cleaning package cache" "DISK_CLEANUP"
    
    local space_freed=0
    
    # Detect package manager and clean cache
    if command -v apt-get >/dev/null 2>&1; then
        log_debug "Cleaning APT package cache" "DISK_CLEANUP"
        local cache_size_before
        cache_size_before=$(du -s /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
        
        execute_privileged "apt-get clean" "Cleaning APT cache"
        execute_privileged "apt-get autoremove -y" "Removing unused packages"
        
        local cache_size_after
        cache_size_after=$(du -s /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
        space_freed=$((cache_size_before - cache_size_after))
        
    elif command -v yum >/dev/null 2>&1; then
        log_debug "Cleaning YUM package cache" "DISK_CLEANUP"
        execute_privileged "yum clean all" "Cleaning YUM cache"
        
    elif command -v dnf >/dev/null 2>&1; then
        log_debug "Cleaning DNF package cache" "DISK_CLEANUP"
        execute_privileged "dnf clean all" "Cleaning DNF cache"
        
    elif command -v zypper >/dev/null 2>&1; then
        log_debug "Cleaning Zypper package cache" "DISK_CLEANUP"
        execute_privileged "zypper clean --all" "Cleaning Zypper cache"
    else
        log_warn "No supported package manager found for cache cleanup" "DISK_CLEANUP"
        return 0
    fi
    
    log_success "Package cache cleanup completed: $((space_freed / 1024)) MB freed" "DISK_CLEANUP"
}

# Clean log files
clean_log_files() {
    log_info "Cleaning old log files" "DISK_CLEANUP"
    
    local retention_days=$(get_config 'monitoring.log_rotation_days' '30')
    local log_dirs=("/var/log" "/var/log/apache2" "/var/log/nginx" "/var/log/mysql")
    local files_cleaned=0
    
    for log_dir in "${log_dirs[@]}"; do
        if [[ -d "$log_dir" ]]; then
            log_debug "Processing log directory: $log_dir" "DISK_CLEANUP"
            
            # Find old log files (compressed and uncompressed)
            local old_logs
            old_logs=$(find "$log_dir" -type f \( -name "*.log.gz" -o -name "*.log.[0-9]*" \) -mtime +"$retention_days" 2>/dev/null | wc -l)
            
            if [[ "$old_logs" -gt 0 ]]; then
                # Remove old log files
                find "$log_dir" -type f \( -name "*.log.gz" -o -name "*.log.[0-9]*" \) -mtime +"$retention_days" -delete 2>/dev/null
                files_cleaned=$((files_cleaned + old_logs))
                log_info "Cleaned $old_logs old log files from $log_dir" "DISK_CLEANUP"
            fi
        fi
    done
    
    # Clean systemd journal logs
    if command -v journalctl >/dev/null 2>&1; then
        log_debug "Cleaning systemd journal logs" "DISK_CLEANUP"
        execute_privileged "journalctl --vacuum-time=${retention_days}d" "Cleaning systemd journal"
    fi
    
    log_success "Log file cleanup completed: $files_cleaned files cleaned" "DISK_CLEANUP"
}

# Clean user cache directories
clean_user_caches() {
    log_info "Cleaning user cache directories" "DISK_CLEANUP"
    
    local cache_dirs=()
    local current_user=$(whoami)
    
    # Add common cache directories
    if [[ -d "/home/$current_user/.cache" ]]; then
        cache_dirs+=("/home/$current_user/.cache")
    fi
    
    if [[ -d "/home/$current_user/.local/share/Trash" ]]; then
        cache_dirs+=("/home/$current_user/.local/share/Trash")
    fi
    
    local files_cleaned=0
    
    for cache_dir in "${cache_dirs[@]}"; do
        if [[ -d "$cache_dir" ]]; then
            log_debug "Cleaning cache directory: $cache_dir" "DISK_CLEANUP"
            
            # Find files older than 30 days
            local old_files
            old_files=$(find "$cache_dir" -type f -mtime +30 2>/dev/null | wc -l)
            
            if [[ "$old_files" -gt 0 ]]; then
                find "$cache_dir" -type f -mtime +30 -delete 2>/dev/null
                files_cleaned=$((files_cleaned + old_files))
                log_info "Cleaned $old_files files from $cache_dir" "DISK_CLEANUP"
            fi
        fi
    done
    
    log_success "User cache cleanup completed: $files_cleaned files cleaned" "DISK_CLEANUP"
}

# Clean Docker resources (if Docker is installed)
clean_docker_resources() {
    if ! command -v docker >/dev/null 2>&1; then
        log_debug "Docker not installed, skipping Docker cleanup" "DISK_CLEANUP"
        return 0
    fi
    
    log_info "Cleaning Docker resources" "DISK_CLEANUP"
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        log_warn "Docker daemon not running, skipping Docker cleanup" "DISK_CLEANUP"
        return 0
    fi
    
    # Clean unused Docker resources
    local cleanup_output
    cleanup_output=$(docker system prune -f 2>&1)
    log_info "Docker cleanup: $cleanup_output" "DISK_CLEANUP"
    
    # Clean unused images
    if docker images -q --filter "dangling=true" | grep -q .; then
        docker rmi $(docker images -q --filter "dangling=true") >/dev/null 2>&1
        log_info "Removed dangling Docker images" "DISK_CLEANUP"
    fi
    
    log_success "Docker cleanup completed" "DISK_CLEANUP"
}

# Generate cleanup report
generate_cleanup_report() {
    log_info "Generating disk cleanup report" "DISK_CLEANUP"
    
    local report_dir=$(get_config 'paths.report_dir' '/tmp/bash-admin')
    local report_file="$report_dir/disk-cleanup-$(date '+%Y%m%d-%H%M%S').html"
    
    # Create report directory
    mkdir -p "$report_dir"
    
    # Get current disk usage
    local disk_usage="<h2>Disk Usage After Cleanup</h2>
<table>
<tr><th>Filesystem</th><th>Size</th><th>Used</th><th>Available</th><th>Use%</th><th>Mounted on</th></tr>"
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            disk_usage="$disk_usage
<tr><td>$(echo "$line" | awk '{print $1}')</td><td>$(echo "$line" | awk '{print $2}')</td><td>$(echo "$line" | awk '{print $3}')</td><td>$(echo "$line" | awk '{print $4}')</td><td>$(echo "$line" | awk '{print $5}')</td><td>$(echo "$line" | awk '{print $6}')</td></tr>"
        fi
    done < <(df -h | grep -E '^/dev/')
    
    disk_usage="$disk_usage</table>"
    
    # Cleanup summary
    local cleanup_summary="<h2>Cleanup Summary</h2>
<table>
<tr><th>Operation</th><th>Status</th></tr>
<tr><td>Temporary Files</td><td><span class=\"success\">Completed</span></td></tr>
<tr><td>Package Cache</td><td><span class=\"success\">Completed</span></td></tr>
<tr><td>Log Files</td><td><span class=\"success\">Completed</span></td></tr>
<tr><td>User Caches</td><td><span class=\"success\">Completed</span></td></tr>"

    if command -v docker >/dev/null 2>&1; then
        cleanup_summary="$cleanup_summary
<tr><td>Docker Resources</td><td><span class=\"success\">Completed</span></td></tr>"
    fi
    
    cleanup_summary="$cleanup_summary</table>"
    
    # Combine all sections
    local full_report="$cleanup_summary$disk_usage"
    
    # Generate HTML report
    generate_html_report "Disk Cleanup Report" "$full_report" "$report_file"
    
    echo "$report_file"
}

# Main function
main() {
    log_info "Starting automated disk cleanup" "DISK_CLEANUP"
    
    # Check available disk space before cleanup
    local space_before
    space_before=$(df / | tail -1 | awk '{print $4}')
    
    # Perform cleanup operations
    clean_temp_files
    clean_package_cache
    clean_log_files
    clean_user_caches
    clean_docker_resources
    
    # Check available disk space after cleanup
    local space_after
    space_after=$(df / | tail -1 | awk '{print $4}')
    
    local space_freed=$((space_after - space_before))
    
    # Generate report
    local report_file
    report_file=$(generate_cleanup_report)
    
    # Send notification
    local message="Disk cleanup completed on $(hostname -f)
Space freed: $((space_freed / 1024 / 1024)) GB
Available space: $((space_after / 1024 / 1024)) GB"
    
    send_notification "INFO" "Disk Cleanup Completed" "$message" "DISK_CLEANUP"
    
    # Send report via email if configured
    if [[ $(get_config 'reporting.auto_email' 'true') == "true" ]]; then
        send_report "$report_file" "Disk Cleanup Report - $(hostname -f)" "$(get_config 'email.recipients.operations')"
    fi
    
    log_success "Disk cleanup completed successfully" "DISK_CLEANUP"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi