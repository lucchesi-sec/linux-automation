#!/bin/bash
# Daily Service Check Script
# Executes comprehensive service management as part of daily administration

# Source the core library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../core/lib/init.sh"

# Initialize
init_bash_admin "$(basename "$0")"

# Source service management module
source "$SCRIPT_DIR/../../modules/services/service_manager.sh"

# Main execution
main() {
    log_info "Starting daily service check" "DAILY_SERVICE"
    
    # Run comprehensive service management
    if run_service_management; then
        log_success "Daily service check completed successfully" "DAILY_SERVICE"
        exit 0
    else
        log_error "Daily service check completed with issues" "DAILY_SERVICE"
        exit 1
    fi
}

# Execute main function
main "$@"