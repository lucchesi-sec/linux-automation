#!/bin/bash
# Optimized Library Loader
# Provides selective library loading to improve performance and reduce dependencies

# Track loaded libraries to prevent duplicate loading
declare -gA LOADED_LIBRARIES

# Core library base path
readonly CORE_LIB_PATH="$(dirname "${BASH_SOURCE[0]}")"

# Library dependency map
declare -gA LIBRARY_DEPENDENCIES=(
    ["config"]=""
    ["logging"]=""
    ["display"]="logging"
    ["error_handler"]="logging display"
    ["dry_run"]="logging display"
    ["security"]="logging"
    ["privileges"]="logging"
    ["notifications"]="logging config"
    ["system_api"]=""
    ["contracts"]=""
)

# Load a specific library
load_library() {
    local library="$1"
    local force="${2:-false}"
    
    # Check if already loaded
    if [[ "${LOADED_LIBRARIES[$library]}" == "true" ]] && [[ "$force" != "true" ]]; then
        return 0
    fi
    
    # Validate library exists
    local library_file="${CORE_LIB_PATH}/${library}.sh"
    if [[ ! -f "$library_file" ]]; then
        echo "Error: Library '$library' not found at $library_file" >&2
        return 1
    fi
    
    # Load dependencies first
    local deps="${LIBRARY_DEPENDENCIES[$library]}"
    if [[ -n "$deps" ]]; then
        for dep in $deps; do
            if [[ "${LOADED_LIBRARIES[$dep]}" != "true" ]]; then
                load_library "$dep" || return 1
            fi
        done
    fi
    
    # Source the library
    source "$library_file"
    LOADED_LIBRARIES[$library]="true"
    
    return 0
}

# Load multiple libraries
load_libraries() {
    local libraries=("$@")
    
    for lib in "${libraries[@]}"; do
        load_library "$lib" || return 1
    done
    
    return 0
}

# Load library group
load_library_group() {
    local group="$1"
    
    case "$group" in
        "minimal")
            # Minimal set for basic functionality
            load_libraries "config" "logging"
            ;;
        "standard")
            # Standard set for most operations
            load_libraries "config" "logging" "display" "error_handler"
            ;;
        "full")
            # Full set for comprehensive functionality
            load_libraries "config" "logging" "display" "error_handler" \
                          "dry_run" "security" "privileges" "notifications"
            ;;
        "system")
            # System interaction libraries
            load_libraries "system_api" "contracts"
            ;;
        "security")
            # Security-focused libraries
            load_libraries "security" "privileges" "logging"
            ;;
        *)
            echo "Error: Unknown library group '$group'" >&2
            return 1
            ;;
    esac
}

# Unload a library (for testing/cleanup)
unload_library() {
    local library="$1"
    
    if [[ "${LOADED_LIBRARIES[$library]}" == "true" ]]; then
        # Unset any functions defined by the library
        # This is library-specific and would need to be maintained
        case "$library" in
            "logging")
                unset -f log_info log_warning log_error log_success log_debug
                ;;
            "display")
                unset -f display_header display_footer display_progress
                ;;
            # Add more as needed
        esac
        
        LOADED_LIBRARIES[$library]="false"
    fi
}

# Get list of loaded libraries
get_loaded_libraries() {
    local loaded=()
    
    for lib in "${!LOADED_LIBRARIES[@]}"; do
        if [[ "${LOADED_LIBRARIES[$lib]}" == "true" ]]; then
            loaded+=("$lib")
        fi
    done
    
    echo "${loaded[@]}"
}

# Check if library is loaded
is_library_loaded() {
    local library="$1"
    [[ "${LOADED_LIBRARIES[$library]}" == "true" ]]
}

# Lazy load a library only when needed
lazy_load() {
    local library="$1"
    shift
    local function="$1"
    shift
    
    # Create a wrapper function that loads the library on first call
    eval "
    $function() {
        if ! is_library_loaded '$library'; then
            load_library '$library' || return 1
        fi
        # Redefine to call the real function
        unset -f $function
        $function \"\$@\"
    }
    "
}

# Profile library loading times
profile_library_loading() {
    local library="$1"
    local start_time
    local end_time
    
    start_time=$(date +%s%N)
    load_library "$library"
    local result=$?
    end_time=$(date +%s%N)
    
    local duration=$(((end_time - start_time) / 1000000))
    echo "Library '$library' loaded in ${duration}ms"
    
    return $result
}

# Initialize loader
init_loader() {
    # Set up any initialization needed
    export LOADER_INITIALIZED=true
}

# Auto-initialize if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_loader
fi