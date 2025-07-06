#!/bin/bash
# Daily Process Check Script
# Executes comprehensive process management as part of daily administration

# Source the core library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../core/lib/init.sh"

# Initialize
init_bash_admin "$(basename "$0")"

# Source process management module
source "$SCRIPT_DIR/../../modules/processes/process_manager.sh"

# Main execution
main() {
    log_info "Starting daily process check" "DAILY_PROCESS"
    
    # Run comprehensive process management
    if run_process_management; then
        log_success "Daily process check completed successfully" "DAILY_PROCESS"
        exit 0
    else
        log_error "Daily process check completed with alerts/issues" "DAILY_PROCESS"
        exit 1
    fi
}

# Execute main function
main "$@"