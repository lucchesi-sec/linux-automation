#!/bin/bash

# Test script for Bash Admin Core Libraries
# This script tests the functionality of all core libraries

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the init script
source "$SCRIPT_DIR/lib/init.sh"

# Initialize Bash Admin
init_bash_admin "test_core_libs.sh"

# Test display functions
test_display() {
    print_header "Testing Display Module" "double"
    
    print_status "success" "This is a success message"
    print_status "error" "This is an error message"
    print_status "warning" "This is a warning message"
    print_status "info" "This is an info message"
    
    print_separator "dashed"
    
    # Test color output
    print_color "$COLOR_RED" "Red text"
    print_color "$COLOR_GREEN" "Green text"
    print_color "$COLOR_YELLOW" "Yellow text"
    print_color "$COLOR_BLUE" "Blue text"
    
    # Test progress bar
    echo "Testing progress bar:"
    for i in {1..10}; do
        print_progress_bar "$i" 10 30 "Processing"
        sleep 0.2
    done
    echo
    
    # Test spinner
    start_spinner "Testing spinner for 3 seconds..."
    sleep 3
    stop_spinner
    print_status "success" "Spinner test completed"
    
    # Test table
    local headers=("Column 1" "Column 2" "Column 3")
    local rows=("Row 1 Col 1|Row 1 Col 2|Row 1 Col 3" "Row 2 Col 1|Row 2 Col 2|Row 2 Col 3")
    echo "Testing table:"
    print_table headers rows
    
    # Test box
    echo "Testing box:"
    print_box "This is a boxed message
With multiple lines
And Unicode support" "rounded"
    
    print_separator
}

# Test configuration functions
test_config() {
    print_header "Testing Configuration Module"
    
    # Set and get config
    set_config "test.key" "test_value"
    local value=$(get_config "test.key")
    print_status "info" "Config test.key = $value"
    
    # Test has_config
    if has_config "test.key"; then
        print_status "success" "has_config working correctly"
    else
        print_status "error" "has_config not working"
    fi
    
    # List config
    echo "Current configuration (filtered for 'email'):"
    list_config "email"
    
    print_separator
}

# Test privilege functions
test_privileges() {
    print_header "Testing Privileges Module"
    
    if check_root_privileges; then
        print_status "info" "Running with root privileges"
    else
        print_status "warning" "Not running with root privileges"
    fi
    
    if check_sudo_privileges; then
        print_status "info" "Sudo privileges available"
    else
        print_status "warning" "Sudo privileges not available"
    fi
    
    # Test user info
    echo "Current user info:"
    get_user_info
    
    print_separator
}

# Test security functions
test_security() {
    print_header "Testing Security Module"
    
    # Test file permissions
    local test_file="/tmp/bash_admin_test_$$"
    touch "$test_file"
    chmod 644 "$test_file"
    
    if check_file_permissions "$test_file" "644"; then
        print_status "success" "File permission check passed"
    else
        print_status "error" "File permission check failed"
    fi
    
    # Set secure permissions
    set_secure_permissions "$test_file" "600"
    if check_file_permissions "$test_file" "600"; then
        print_status "success" "Secure permissions set correctly"
    fi
    
    rm -f "$test_file"
    
    # Test input sanitization
    local dirty_input='test$(whoami)`date`'
    local clean_input=$(sanitize_input "$dirty_input")
    print_status "info" "Sanitized input: '$dirty_input' -> '$clean_input'"
    
    # Test input validation
    if validate_input "test@example.com" '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' "email"; then
        print_status "success" "Email validation passed"
    fi
    
    print_separator
}

# Test error handling functions
test_error_handling() {
    print_header "Testing Error Handling Module"
    
    # Test safe execution
    print_status "info" "Testing safe command execution"
    safe_execute "echo 'Safe command executed'" "Testing safe echo"
    
    # Test with failure allowed
    print_status "info" "Testing command that fails (with allow_failure=true)"
    safe_execute "false" "Testing intentional failure" "true"
    
    # Test rollback
    print_status "info" "Testing rollback registration"
    register_rollback "echo 'Rollback action 1 executed'" "Test rollback 1"
    register_rollback "echo 'Rollback action 2 executed'" "Test rollback 2"
    
    # Clear rollback stack (simulating successful operation)
    clear_rollback_stack
    print_status "success" "Rollback stack cleared"
    
    # Test retry with backoff
    print_status "info" "Testing retry with backoff (will fail)"
    retry_with_backoff 2 1 "false" "Test retry operation" || print_status "warning" "Retry test completed (expected to fail)"
    
    print_separator
}

# Test dry-run functions
test_dry_run() {
    print_header "Testing Dry-Run Module"
    
    # Enable dry-run mode
    enable_dry_run
    
    # Test dry-run commands
    dry_run_execute "rm -rf /tmp/test" "Remove test directory" "DELETE"
    dry_run_execute "useradd testuser" "Create test user" "CREATE"
    dry_run_execute "apt-get update" "Update package list" "MODIFY"
    
    # Test file operations
    dry_run_file_operation "create" "/tmp/test_file" "Create test file"
    dry_run_file_operation "delete" "/tmp/test_file" "Delete test file"
    
    # Test user operations
    dry_run_user_operation "create" "testuser" "-m" "-s" "/bin/bash"
    
    # Test package operations
    dry_run_package_operation "install" "nginx"
    
    # Generate summary
    echo
    generate_dry_run_summary
    
    # Disable dry-run mode
    disable_dry_run
    
    print_separator
}

# Test notification functions (limited without actual email setup)
test_notifications() {
    print_header "Testing Notifications Module"
    
    # Test HTML report generation
    local report_file="/tmp/test_report_$$.html"
    local report_content="<h2>Test Report</h2><p>This is a test report.</p>"
    generate_html_report "Test Report" "$report_content" "$report_file"
    
    if [[ -f "$report_file" ]]; then
        print_status "success" "HTML report generated: $report_file"
        rm -f "$report_file"
    else
        print_status "error" "Failed to generate HTML report"
    fi
    
    print_separator
}

# Main test execution
main() {
    clear_screen "Bash Admin Core Library Test Suite"
    
    test_display
    test_config
    test_privileges
    test_security
    test_error_handling
    test_dry_run
    test_notifications
    
    print_header "Test Summary" "double"
    print_status "success" "All core library tests completed"
    print_status "info" "Total errors encountered: $ERROR_COUNT"
    
    # Generate error report if there were errors
    if [[ $ERROR_COUNT -gt 0 ]]; then
        local error_report=$(generate_error_report)
        print_status "warning" "Error report generated: $error_report"
    fi
}

# Run tests
main "$@"