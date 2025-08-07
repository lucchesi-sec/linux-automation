#!/bin/bash
# Interface Contracts Definition
# Defines formal contracts for module interfaces to enforce consistent behavior

# Contract validation functions
validate_contract() {
    local contract_name="$1"
    shift
    local args=("$@")
    
    case "$contract_name" in
        "data_provider")
            validate_data_provider_contract "${args[@]}"
            ;;
        "analyzer")
            validate_analyzer_contract "${args[@]}"
            ;;
        "presenter")
            validate_presenter_contract "${args[@]}"
            ;;
        "service")
            validate_service_contract "${args[@]}"
            ;;
        *)
            return 1
            ;;
    esac
}

# ================================
# Data Provider Contract
# ================================
# Data providers must:
# - Return data in consistent format
# - Handle errors gracefully
# - Not perform analysis or presentation
# - Be idempotent

validate_data_provider_contract() {
    local function_name="$1"
    
    # Check if function exists
    if ! declare -f "$function_name" >/dev/null; then
        return 1
    fi
    
    # Verify function follows naming convention
    if [[ ! "$function_name" =~ ^get_|^fetch_|^read_|^list_ ]]; then
        echo "Warning: Data provider '$function_name' doesn't follow naming convention (get_*, fetch_*, read_*, list_*)" >&2
    fi
    
    return 0
}

# Data provider interface template
declare_data_provider() {
    local name="$1"
    local description="$2"
    local returns="$3"
    
    cat <<EOF
# Data Provider: ${name}
# Description: ${description}
# Returns: ${returns}
# Contract: Must be idempotent, handle errors, return consistent format
${name}() {
    local error_code=0
    
    # Input validation
    if [[ \$# -lt 1 ]]; then
        echo "Error: ${name} requires at least 1 argument" >&2
        return 1
    fi
    
    # Data gathering logic here
    # Must not perform analysis or presentation
    
    return \$error_code
}
EOF
}

# ================================
# Analyzer Contract
# ================================
# Analyzers must:
# - Accept data as input
# - Return analysis results
# - Be pure functions (no side effects)
# - Not access system directly

validate_analyzer_contract() {
    local function_name="$1"
    
    # Check if function exists
    if ! declare -f "$function_name" >/dev/null; then
        return 1
    fi
    
    # Verify function follows naming convention
    if [[ ! "$function_name" =~ ^analyze_|^calculate_|^evaluate_|^assess_ ]]; then
        echo "Warning: Analyzer '$function_name' doesn't follow naming convention (analyze_*, calculate_*, evaluate_*, assess_*)" >&2
    fi
    
    return 0
}

# Analyzer interface template
declare_analyzer() {
    local name="$1"
    local description="$2"
    local input_type="$3"
    local output_type="$4"
    
    cat <<EOF
# Analyzer: ${name}
# Description: ${description}
# Input: ${input_type}
# Output: ${output_type}
# Contract: Must be pure function, no system access, no side effects
${name}() {
    local input="\$1"
    local result=""
    
    # Input validation
    if [[ -z "\$input" ]]; then
        echo "Error: ${name} requires input data" >&2
        return 1
    fi
    
    # Analysis logic here
    # Must not access system directly
    # Must not have side effects
    
    echo "\$result"
    return 0
}
EOF
}

# ================================
# Presenter Contract
# ================================
# Presenters must:
# - Accept analyzed data as input
# - Format for display
# - Handle different output formats
# - Not perform data gathering or analysis

validate_presenter_contract() {
    local function_name="$1"
    
    # Check if function exists
    if ! declare -f "$function_name" >/dev/null; then
        return 1
    fi
    
    # Verify function follows naming convention
    if [[ ! "$function_name" =~ ^format_|^display_|^render_|^present_ ]]; then
        echo "Warning: Presenter '$function_name' doesn't follow naming convention (format_*, display_*, render_*, present_*)" >&2
    fi
    
    return 0
}

# Presenter interface template
declare_presenter() {
    local name="$1"
    local description="$2"
    local input_format="$3"
    local output_formats="$4"
    
    cat <<EOF
# Presenter: ${name}
# Description: ${description}
# Input Format: ${input_format}
# Output Formats: ${output_formats}
# Contract: Must handle formatting only, no data gathering or analysis
${name}() {
    local data="\$1"
    local format="\${2:-text}"
    
    # Input validation
    if [[ -z "\$data" ]]; then
        echo "Error: ${name} requires data to present" >&2
        return 1
    fi
    
    case "\$format" in
        text)
            # Text formatting logic
            ;;
        json)
            # JSON formatting logic
            ;;
        html)
            # HTML formatting logic
            ;;
        *)
            echo "Error: Unsupported format: \$format" >&2
            return 1
            ;;
    esac
    
    return 0
}
EOF
}

# ================================
# Service Contract
# ================================
# Services must:
# - Coordinate between data, analysis, and presentation
# - Handle transactions and rollback
# - Provide consistent error handling
# - Log operations appropriately

validate_service_contract() {
    local function_name="$1"
    
    # Check if function exists
    if ! declare -f "$function_name" >/dev/null; then
        return 1
    fi
    
    # Verify function follows naming convention
    if [[ ! "$function_name" =~ _service$|_manager$|_coordinator$ ]]; then
        echo "Warning: Service '$function_name' doesn't follow naming convention (*_service, *_manager, *_coordinator)" >&2
    fi
    
    return 0
}

# Service interface template
declare_service() {
    local name="$1"
    local description="$2"
    local dependencies="$3"
    
    cat <<EOF
# Service: ${name}
# Description: ${description}
# Dependencies: ${dependencies}
# Contract: Must coordinate operations, handle errors, support rollback
${name}() {
    local operation="\$1"
    shift
    local args=("\$@")
    
    # Initialize transaction
    local transaction_id="\$(date +%s)_\$\$"
    local rollback_stack=()
    
    # Operation dispatch
    case "\$operation" in
        create|read|update|delete)
            # Handle CRUD operations
            ;;
        *)
            echo "Error: Unknown operation: \$operation" >&2
            return 1
            ;;
    esac
    
    # Cleanup on success or rollback on failure
    
    return 0
}
EOF
}

# ================================
# Contract Registry
# ================================

# Register a contract implementation
register_contract() {
    local contract_type="$1"
    local implementation="$2"
    local module="$3"
    
    # Store in contract registry (could be a file or variable)
    echo "${contract_type}:${implementation}:${module}" >> "${CONTRACT_REGISTRY:-/tmp/contracts.registry}"
}

# Verify all contracts in a module
verify_module_contracts() {
    local module_file="$1"
    local violations=0
    
    # Extract function definitions
    local functions
    functions=$(grep -E "^[a-zA-Z_][a-zA-Z0-9_]*\(\)" "$module_file" | sed 's/().*//')
    
    while IFS= read -r func; do
        # Determine contract type based on naming
        local contract_type=""
        
        if [[ "$func" =~ ^get_|^fetch_|^read_|^list_ ]]; then
            contract_type="data_provider"
        elif [[ "$func" =~ ^analyze_|^calculate_|^evaluate_|^assess_ ]]; then
            contract_type="analyzer"
        elif [[ "$func" =~ ^format_|^display_|^render_|^present_ ]]; then
            contract_type="presenter"
        elif [[ "$func" =~ _service$|_manager$|_coordinator$ ]]; then
            contract_type="service"
        fi
        
        if [[ -n "$contract_type" ]]; then
            if ! validate_contract "$contract_type" "$func"; then
                echo "Contract violation: $func in $module_file"
                ((violations++))
            fi
        fi
    done <<< "$functions"
    
    return $violations
}

# ================================
# Contract Enforcement Helpers
# ================================

# Ensure function is pure (no side effects)
ensure_pure_function() {
    local function_body="$1"
    
    # Check for system calls that would violate purity
    local violations=()
    
    if echo "$function_body" | grep -qE "rm |mv |cp |mkdir |touch |chmod |chown "; then
        violations+=("File system modifications detected")
    fi
    
    if echo "$function_body" | grep -qE "apt|yum|dnf|pacman|systemctl|service "; then
        violations+=("System modifications detected")
    fi
    
    if echo "$function_body" | grep -qE " >/|>>/| tee "; then
        violations+=("File writes detected")
    fi
    
    if [[ ${#violations[@]} -gt 0 ]]; then
        printf '%s\n' "${violations[@]}" >&2
        return 1
    fi
    
    return 0
}

# Ensure function handles errors properly
ensure_error_handling() {
    local function_body="$1"
    
    # Check for proper error handling patterns
    if ! echo "$function_body" | grep -q "set -e\|return [0-9]\|\|\|&&"; then
        echo "Warning: Function may lack proper error handling" >&2
    fi
    
    return 0
}

# ================================
# Contract Documentation Generator
# ================================

generate_contract_documentation() {
    local module="$1"
    local output="${2:-${module%.sh}_contracts.md}"
    
    cat > "$output" <<EOF
# Contract Documentation for ${module}

## Overview
This document describes the interface contracts for ${module}.

## Contracts

EOF
    
    # Extract and document each contract
    local functions
    functions=$(grep -E "^[a-zA-Z_][a-zA-Z0-9_]*\(\)" "$module" | sed 's/().*//')
    
    while IFS= read -r func; do
        # Extract function documentation
        local doc
        doc=$(sed -n "/^# ${func}/,/^${func}()/p" "$module" | grep "^#" | sed 's/^# *//')
        
        if [[ -n "$doc" ]]; then
            cat >> "$output" <<EOF
### ${func}

${doc}

---

EOF
        fi
    done <<< "$functions"
    
    echo "Contract documentation generated: $output"
}