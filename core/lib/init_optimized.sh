#!/bin/bash
# Optimized Core Library Initialization
# Uses selective loading to reduce startup time and memory usage

# Get the directory where this script is located
CORE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the optimized loader
source "${CORE_LIB_DIR}/loader.sh"

# Parse initialization options
parse_init_options() {
    local options="$1"
    
    case "$options" in
        --minimal|minimal)
            echo "minimal"
            ;;
        --standard|standard)
            echo "standard"
            ;;
        --full|full)
            echo "full"
            ;;
        --system|system)
            echo "system"
            ;;
        --security|security)
            echo "security"
            ;;
        *)
            # Default to standard
            echo "standard"
            ;;
    esac
}

# Initialize with specific library set
init_with_libraries() {
    local libraries=("$@")
    
    if [[ ${#libraries[@]} -eq 0 ]]; then
        # Default to standard set
        load_library_group "standard"
    else
        # Load specific libraries
        load_libraries "${libraries[@]}"
    fi
}

# Main initialization function
init_core() {
    local init_mode="${1:-standard}"
    
    # Load appropriate library group
    if ! load_library_group "$init_mode"; then
        echo "Error: Failed to initialize core libraries in '$init_mode' mode" >&2
        return 1
    fi
    
    # Set global variables
    export ADMIN_TOOLS_VERSION="2.0.0"
    export ADMIN_TOOLS_INITIALIZED=true
    export ADMIN_TOOLS_INIT_MODE="$init_mode"
    
    # Load configuration if available
    if is_library_loaded "config"; then
        # Initialize configuration
        local config_file="${ADMIN_TOOLS_CONFIG:-/etc/admin-tools/config.json}"
        if [[ -f "$config_file" ]]; then
            export ADMIN_TOOLS_CONFIG_FILE="$config_file"
        fi
    fi
    
    # Set up logging if available
    if is_library_loaded "logging"; then
        # Initialize logging
        : # Logging initialization is handled by the logging library itself
    fi
    
    return 0
}

# Provide backward compatibility
if [[ -z "$SKIP_AUTO_INIT" ]]; then
    # Auto-initialize with standard libraries if sourced directly
    init_core "standard"
fi

# Export functions for use by other scripts
export -f load_library
export -f load_libraries
export -f load_library_group
export -f is_library_loaded
export -f lazy_load

# ================================
# Usage Examples
# ================================

# Example 1: Minimal initialization for simple scripts
# source init_optimized.sh
# init_core "minimal"

# Example 2: Load specific libraries only
# source init_optimized.sh
# SKIP_AUTO_INIT=true
# init_with_libraries "logging" "config"

# Example 3: Lazy loading for rarely used functions
# source init_optimized.sh
# lazy_load "notifications" "send_notification"
# # send_notification will load the notifications library on first call

# Example 4: System operations only
# source init_optimized.sh
# init_core "system"

# Example 5: Security-focused operations
# source init_optimized.sh
# init_core "security"