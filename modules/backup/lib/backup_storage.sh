#!/bin/bash

# Backup Storage Management Functions
# Handles storage analysis, cleanup, and management

# Get filesystem information using structured command output
get_filesystem_info() {
    local path="$1"
    
    if [[ ! -d "$path" ]]; then
        echo '{"available": 0, "size": 0, "used": 0, "usage_percent": 0, "filesystem": "none", "status": "missing"}'
        return 1
    fi
    
    # Use df with --output for structured output and parse with jq
    local df_output
    df_output=$(df -B1 --output=source,size,used,avail,pcent,target "$path" 2>/dev/null | tail -n1)
    
    if [[ -z "$df_output" ]]; then
        echo '{"available": 0, "size": 0, "used": 0, "usage_percent": 0, "filesystem": "none", "status": "error"}'
        return 1
    fi
    
    # Create JSON structure from df output
    echo "$df_output" | awk '{
        gsub(/%/, "", $5);
        printf "{\"filesystem\":\"%s\",\"size\":%s,\"used\":%s,\"available\":%s,\"usage_percent\":%s}\n", $1, $2, $3, $4, $5
    }'
}

# Get backup file statistics using structured commands
get_backup_file_stats() {
    local path="$1"
    
    if [[ ! -d "$path" ]]; then
        echo '{"count": 0, "total_bytes": 0, "avg_bytes": 0, "newest_timestamp": 0, "oldest_timestamp": 0}'
        return 1
    fi
    
    # Use find with -printf for exact structure, then process with awk for counts
    local stats
    stats=$(
        find "$path" -type f \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.sql.gz" \) \
            -printf '%TY%Tm%Td%TH%TM%TS %s\n' 2>/dev/null | sort -n
    )
    
    if [[ -z "$stats" ]]; then
        echo '{"count": 0, "total_bytes": 0, "avg_bytes": 0, "newest_timestamp": 0, "oldest_timestamp": 0}'
        return 0
    fi
    
    # Process with awk to create JSON structure
    echo "$stats" | awk '{
        count++;
        total_bytes += $2;
        if (NR == 1) oldest = $2;
        timestamp = $1;
        newest = timestamp;
    } END {
        avg_bytes = count > 0 ? int(total_bytes/count) : 0;
        newest_timestamp = newest + 0;  # Convert to number
        oldest_timestamp = oldest + 0;  # Convert to number
        printf "{\"count\":%d,\"total_bytes\":%d,\"avg_bytes\":%d,\"newest_timestamp\":%.0f,\"oldest_timestamp\":%.0f}\n", count, total_bytes, avg_bytes, newest, oldest
    }' 2>/dev/null || echo '{"count": 0, "total_bytes": 0, "avg_bytes": 0, "newest_timestamp": 0, "oldest_timestamp": 0}'
}

# Find old backups for cleanup using structured output
find_old_backups() {
    local path="$1"
    local retention_days="$2"
    
    if [[ ! -d "$path" ]]; then
        return 0
    fi
    
    # Use find with -printf for structured output, then filter by modification time
    find "$path" -type f \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.sql.gz" \) \
         -mtime +"$retention_days" -print0 2>/dev/null
}

# Calculate cleanup impact with structured data
calculate_cleanup_impact() {
    local path="$1"
    local retention_days="$2"
    
    local old_total=0
    local old_count=0
    local old_files=""
    
    # Capture all old files for analysis
    while IFS= read -r -d '' file; do
        local size
        size=$(stat -c '%s' "$file" 2>/dev/null || echo 0)
        old_total=$((old_total + size))
        ((old_count++))
    done < <(find_old_backups "$path" "$retention_days")
    
    # Create JSON output
    echo "{\"count\": $old_count, \"total_bytes\": $old_total, \"human_readable\": \"$(printf '%.1f' "$(($old_total / 1024 / 1024))") MB\"}"
}

# Human-readable byte conversion
bytes_to_human() {
    local bytes="$1"
    
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes} B"
    elif [[ $bytes -lt 1048576 ]]; then
        printf "%.1f KB" "$((bytes / 1024)).0"
    elif [[ $bytes -lt 1073741824 ]]; then
        printf "%.1f MB" "$((bytes / 1024 / 1024)).0"
    else
        printf "%.1f GB" "$((bytes / 1024 / 1024 / 1024)).0"
    fi
}

# Export functions for use by other scripts
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f get_filesystem_info
    export -f get_backup_file_stats
    export -f find_old_backups
    export -f calculate_cleanup_impact
    export -f bytes_to_human
fi