#!/bin/bash
# Daily Package Check Script
# Executes comprehensive package management as part of daily administration

# Source the core library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../core/lib/init.sh"

# Initialize
init_bash_admin "$(basename "$0")"

# Source package management module
source "$SCRIPT_DIR/../../modules/packages/package_manager.sh"

# Main execution
main() {
    log_info "Starting daily package check" "DAILY_PACKAGE"
    
    # Run comprehensive package management
    if run_package_management; then
        log_success "Daily package check completed successfully" "DAILY_PACKAGE"
        exit 0
    else
        log_error "Daily package check completed with pending updates" "DAILY_PACKAGE"
        exit 1
    fi
}

# Execute main function
main "$@"