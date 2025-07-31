#!/bin/bash

# Backup Jobs Management Functions
# Manages individual backup job configuration and status

# Construct JSON-formatted backup job data
get_backup_job_data() {
    local job_name="$1"
    local backup_jobs="$2"
    
    if [[ -z "$job_name" ]]; then
        echo "{}"
        return 1
    fi
    
    echo "$backup_jobs" | jq -r ".\"$job_name\" // {}" 2>/dev/null || echo "{}"
}

# Get specific job properties using structured output
get_backup_job_property() {
    local job_data="$1"
    local property="$2"
    local default_value="$3"
    
    local value=$(echo "$job_data" | jq -r ".$property // \"$default_value\"" 2>/dev/null)
    echo "$value"
}

# Count recent backups using structured data
get_recent_backup_count() {
    local path="$1"
    local max_age_hours="${2:-24}" # Default to 1 day
    
    if [[ ! -e "$path" ]]; then
        echo "0"
        return 1
    fi
    
    local cutoff_time=$(date -d "-$max_age_hours hours" +%s)
    local count=0
    
    if [[ -d "$path" ]]; then
        # Use find with printf to get structured output for filtering
        count=$(find "$path" -type f -name "*.tar.gz" -o -name "*.zip" -o -name "*.sql.gz" -print0 2>/dev/null | \
                xargs -0 stat -c '%Y' 2>/dev/null | \
                awk -v cutoff="$cutoff_time" '$1 > cutoff {count++} END {print count+0}' 2>/dev/null || echo "0")
    elif [[ -f "$path" ]]; then
        # Check single file
        local file_time=$(stat -c '%Y' "$path" 2>/dev/null || echo "0")
        if [[ $file_time -gt $cutoff_time ]]; then
            count=1
        fi
        echo "$count"
    else
        echo "0"
    fi
}

# Generate structured backup job status
generate_backup_job_status() {
    local job_name="$1"
    local job_path="$2"
    local job_enabled="$3"
    local job_schedule="$4"
    local job_retention="$5"
    
    local recent_count=$(get_recent_backup_count "$job_path")
    
    if [[ "$job_enabled" != "true" ]]; then
        echo '{"status": "DISABLED", "recent_backups": 0, "message": "Job is disabled", "path": "'$job_path'", "schedule": "'$job_schedule'"}'
    elif [[ $recent_count -gt 0 ]]; then
        echo '{"status": "SUCCESS", "recent_backups": '$recent_count', "message": "'$recent_count' recent backup(s)", "path": "'$job_path'", "schedule": "'$job_schedule'"}'
    else
        echo '{"status": "FAILED", "recent_backups": 0, "message": "No recent backups found", "path": "'$job_path'", "schedule": "'$job_schedule'"}'
    fi
}

# Export functions for use by other scripts
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f get_backup_job_data
    export -f get_backup_job_property
    export -f get_recent_backup_count
    export -f generate_backup_job_status
fi