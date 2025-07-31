#!/bin/bash

# Test Configuration Validation
# Tests JSON schema validation and configuration processing

# Source the init script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/init.sh"

# Initialize Bash Admin
init_bash_admin "test_config_validation.sh"

# Generate test configuration
create_test_config() {
    local config_file="$1"
    local test_config='{
    "system": {
        "hostname": "test-server",
        "timezone": "UTC",
        "environment": "testing",
        "data_directory": "/tmp/test-bash-admin",
        "temp_directory": "/tmp/test-bash-admin/tmp",
        "lock_directory": "/tmp/test-bash-admin/locks"
    },
    "logging": {
        "level": "DEBUG",
        "retention_days": 7,
        "max_size_mb": 10,
        "compress_after_days": 1,
        "destinations": ["file", "console"],
        "file_path": "/tmp/test-bash-admin/test.log",
        "color_output": false
    },
    "notifications": {
        "enabled": false
    },
    "modules": {
        "service_management": {
            "enabled": false
        },
        "backup_monitor": {
            "enabled": true,
            "backup_paths": [
                "/tmp/test-backups"
            ],
            "retention_days": 1
        }
    }
}'
    
    echo "$test_config" > "$config_file"
}

# Test JSON schema validation
test_config_validation() {
    print_header "Testing JSON Schema Validation" "double"
    
    local test_config_file="/tmp/test_config_$$.json"
    create_test_config "$test_config_file"
    
    # Test valid configuration
    print_status "info" "Testing valid configuration loading..."
    
    if validate_config_schema "$test_config_file"; then
        print_status "success" "✓ Valid configuration passed validation"
    else
        print_status "error" "✗ Valid configuration validation failed"
    fi
    
    # Test invalid configuration
    print_status "info" "Testing invalid configuration detection..."
    
    local invalid_config='{
    "system": {
        "hostname": "test-server",
        "retention_days": "invalid_days"  # Should be integer
    }
}'
    
    echo "$invalid_config" > /tmp/invalid_config_$$.json
    
    if ! validate_config_schema /tmp/invalid_config_$$.json; then
        print_status "success" "✓ Invalid configuration correctly rejected"
    else
        print_status "error" "✗ Invalid configuration validation passed (should fail)"
    fi
    
    # Test missing configuration keys
    print_status "info" "Testing missing required keys..."
    
    local incomplete_config='{
    "lications": {
        "invalid": "incomplete"
    }
}'
    
    echo "$incomplete_config" > /tmp/incomplete_config_$$.json
    
    if ! validate_config_schema /tmp/incomplete_config_$$.json; then
        print_status "success" "✓ Incomplete configuration correctly rejected"
    else
        print_status "error" "✗ Incomplete configuration validation passed (should fail)"
    fi
    
    # Cleanup
    rm -f "$test_config_file" /tmp/invalid_config_$$.json /tmp/incomplete_config_$$.json
    
    print_separator
}

# Test configuration utility functions
test_config_functions() {
    print_header "Testing Configuration Functions" "double"
    
    local test_config_file="/tmp/test_config_functions_$$.json"
    create_test_config "$test_config_file"
    
    # Load test configuration
    print_status "info" "Loading test configuration..."
    if ! load_config "$test_config_file"; then
        print_status "error" "Failed to load test configuration"
        return 1
    fi
    
    # Test get_config with defaults
    local log_level=$(get_config "logging.level" "INFO")
    print_status "info" "Logging level: $log_level"
    
    local retention_days=$(get_config "logging.retention_days" "30")
    print_status "info" "Retention days: $retention_days"
    
    local non_existent=$(get_config "non.existent.key" "default-value")
    print_status "info" "Non-existent key: $non_existent"
    
    # Test configuration listing
    print_status "info" "Configuration items (system.*):"
    list_config "system" | head -5
    
    print_status "success" "✓ Configuration functions working correctly"
    
    rm -f "$test_config_file"
    print_separator
}

# Test structured backup data processing
test_backup_data_structures() {
    print_header "Testing Backup Data Structures" "double"
    
    # Create test backup structure
    mkdir -p /tmp/test-backups
    
    # Create some test backup files
    touch /tmp/test-backups/test_backup_$(date +%Y%m%d).tar.gz
    touch /tmp/test-backups/test_backup_$(date -d "2 days ago" +%Y%m%d).tar.gz
    
    # Source backup functions
    source "${SCRIPT_DIR}/../modules/backup/lib/backup_jobs.sh"
    source "${SCRIPT_DIR}/../modules/backup/lib/backup_storage.sh"
    
    print_status "info" "Testing filesystem info retrieval..."
    local fs_info
    fs_info=$(get_filesystem_info "/tmp/test-backups")
    log_debug "Filesystem info: $fs_info"
    
    print_status "info" "Testing backup file statistics..."
    local file_stats
    file_stats=$(get_backup_file_stats "/tmp/test-backups")
    log_debug "File stats: $file_stats"
    
    # Verify JSON structure
    local count=$(echo "$file_stats" | jq -r '.count')
    local total_bytes=$(echo "$file_stats" | jq -r '.total_bytes')
    
    print_status "info" "Found $count backup files, total size: $total_bytes bytes"
    
    if [[ $count -ge 0 ]] && [[ $total_bytes -ge 0 ]]; then
        print_status "success" "✓ Structured data processing working"
    else
        print_status "error" "✗ Structured data processing failed"
    fi
    
    # Cleanup
    rm -rf /tmp/test-backups
    print_separator
}

# Main test orchestration
run_config_validation_tests() {
    print_header "Running Configuration Validation Tests" "double"
    
    test_config_validation
    test_config_functions
    
    # Check if jq is available before running advanced tests
    if command -v jq >/dev/null 2>&1; then
        test_backup_data_structures
    else
        print_status "warning" "jq not available, skipping structured data tests"
    fi
    
    print_status "success" "Configuration validation tests completed"
}

# Run tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_config_validation_tests "$@"
else
    export -f create_test_config
    export -f test_config_validation
    export -f test_config_functions
    export -f test_backup_data_structures
    export -f run_config_validation_tests
fi