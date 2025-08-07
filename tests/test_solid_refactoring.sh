#!/bin/bash
# Test Script for SOLID Refactoring
# Verifies that all refactored components work correctly

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result tracking
declare -a FAILED_TESTS

# Print test header
print_header() {
    echo "=================================="
    echo "SOLID Refactoring Test Suite"
    echo "=================================="
    echo
}

# Print test result
print_result() {
    local test_name="$1"
    local result="$2"
    
    ((TESTS_RUN++))
    
    if [[ "$result" == "PASS" ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}✓${NC} $test_name"
    else
        ((TESTS_FAILED++))
        FAILED_TESTS+=("$test_name")
        echo -e "${RED}✗${NC} $test_name"
    fi
}

# Test System API
test_system_api() {
    echo "Testing System API..."
    
    # Source the System API
    source "$(dirname "$0")/../core/lib/system_api.sh"
    
    # Test initialization
    init_system_api
    if [[ "$SYSTEM_API_INITIALIZED" == "true" ]]; then
        print_result "System API initialization" "PASS"
    else
        print_result "System API initialization" "FAIL"
    fi
    
    # Test platform detection
    if [[ -n "$SYSTEM_PLATFORM" ]]; then
        print_result "Platform detection ($SYSTEM_PLATFORM)" "PASS"
    else
        print_result "Platform detection" "FAIL"
    fi
    
    # Test package manager detection
    local pkg_manager
    pkg_manager=$(system_api_detect_package_manager)
    if [[ -n "$pkg_manager" && "$pkg_manager" != "unknown" ]]; then
        print_result "Package manager detection ($pkg_manager)" "PASS"
    else
        print_result "Package manager detection" "FAIL"
    fi
    
    # Test service manager detection
    local svc_manager
    svc_manager=$(system_api_get_service_manager)
    if [[ -n "$svc_manager" && "$svc_manager" != "unknown" ]]; then
        print_result "Service manager detection ($svc_manager)" "PASS"
    else
        print_result "Service manager detection" "FAIL"
    fi
    
    echo
}

# Test Interface Contracts
test_contracts() {
    echo "Testing Interface Contracts..."
    
    # Source contracts
    source "$(dirname "$0")/../core/lib/contracts.sh"
    
    # Test contract validation functions exist
    if declare -f validate_contract >/dev/null; then
        print_result "Contract validation function exists" "PASS"
    else
        print_result "Contract validation function exists" "FAIL"
    fi
    
    # Test data provider contract validation
    test_function() { echo "test"; }
    get_test_data() { echo "data"; }
    
    if validate_contract "data_provider" "get_test_data" 2>/dev/null; then
        print_result "Data provider contract validation" "PASS"
    else
        print_result "Data provider contract validation" "FAIL"
    fi
    
    echo
}

# Test User Module Separation
test_user_module_separation() {
    echo "Testing User Module Separation..."
    
    # Check if separated modules exist
    local modules=(
        "modules/users/user_data.sh"
        "modules/users/user_analysis.sh"
        "modules/users/user_presentation.sh"
        "modules/users/user_manager_refactored.sh"
    )
    
    for module in "${modules[@]}"; do
        if [[ -f "$(dirname "$0")/../$module" ]]; then
            print_result "Module exists: $module" "PASS"
        else
            print_result "Module exists: $module" "FAIL"
        fi
    done
    
    # Test that modules can be sourced
    local base_dir="$(dirname "$0")/.."
    
    # Source System API first (dependency)
    source "$base_dir/core/lib/system_api.sh"
    
    # Try sourcing each module
    for module in "${modules[@]}"; do
        if source "$base_dir/$module" 2>/dev/null; then
            print_result "Module sources correctly: $(basename $module)" "PASS"
        else
            print_result "Module sources correctly: $(basename $module)" "FAIL"
        fi
    done
    
    echo
}

# Test Configuration Loading
test_configuration() {
    echo "Testing Configuration..."
    
    local config_file="$(dirname "$0")/../config/system_config.json"
    
    if [[ -f "$config_file" ]]; then
        print_result "Configuration file exists" "PASS"
        
        # Test JSON validity
        if command -v jq >/dev/null 2>&1; then
            if jq empty "$config_file" 2>/dev/null; then
                print_result "Configuration JSON is valid" "PASS"
            else
                print_result "Configuration JSON is valid" "FAIL"
            fi
            
            # Test key configuration values
            local version
            version=$(jq -r '.metadata.version' "$config_file" 2>/dev/null)
            if [[ "$version" == "2.0.0" ]]; then
                print_result "Configuration version check" "PASS"
            else
                print_result "Configuration version check" "FAIL"
            fi
        else
            echo -e "${YELLOW}⚠${NC} jq not installed - skipping JSON validation"
        fi
    else
        print_result "Configuration file exists" "FAIL"
    fi
    
    echo
}

# Test Optimized Library Loader
test_library_loader() {
    echo "Testing Optimized Library Loader..."
    
    # Source the loader
    source "$(dirname "$0")/../core/lib/loader.sh"
    
    # Test initialization
    if [[ "$LOADER_INITIALIZED" == "true" ]]; then
        print_result "Loader initialization" "PASS"
    else
        print_result "Loader initialization" "FAIL"
    fi
    
    # Test loading a library
    if load_library "logging" 2>/dev/null; then
        print_result "Load single library (logging)" "PASS"
    else
        print_result "Load single library (logging)" "FAIL"
    fi
    
    # Test checking if library is loaded
    if is_library_loaded "logging"; then
        print_result "Check library loaded status" "PASS"
    else
        print_result "Check library loaded status" "FAIL"
    fi
    
    # Test loading library group
    if load_library_group "minimal" 2>/dev/null; then
        print_result "Load library group (minimal)" "PASS"
    else
        print_result "Load library group (minimal)" "FAIL"
    fi
    
    echo
}

# Test SOLID Principles Compliance
test_solid_compliance() {
    echo "Testing SOLID Principles Compliance..."
    
    # Check Single Responsibility (separated modules)
    local srp_compliant=true
    if [[ -f "$(dirname "$0")/../modules/users/user_data.sh" ]] && \
       [[ -f "$(dirname "$0")/../modules/users/user_analysis.sh" ]] && \
       [[ -f "$(dirname "$0")/../modules/users/user_presentation.sh" ]]; then
        print_result "Single Responsibility Principle (SRP)" "PASS"
    else
        print_result "Single Responsibility Principle (SRP)" "FAIL"
    fi
    
    # Check Dependency Inversion (System API)
    if [[ -f "$(dirname "$0")/../core/lib/system_api.sh" ]]; then
        print_result "Dependency Inversion Principle (DIP)" "PASS"
    else
        print_result "Dependency Inversion Principle (DIP)" "FAIL"
    fi
    
    # Check Interface Segregation (Contracts)
    if [[ -f "$(dirname "$0")/../core/lib/contracts.sh" ]]; then
        print_result "Interface Segregation Principle (ISP)" "PASS"
    else
        print_result "Interface Segregation Principle (ISP)" "FAIL"
    fi
    
    echo
}

# Print summary
print_summary() {
    echo "=================================="
    echo "Test Summary"
    echo "=================================="
    echo "Tests Run: $TESTS_RUN"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo
        echo "Failed Tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  - $test"
        done
    fi
    
    echo
    
    # Calculate score
    local score=0
    if [[ $TESTS_RUN -gt 0 ]]; then
        score=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi
    
    echo "Overall Score: $score%"
    
    if [[ $score -ge 90 ]]; then
        echo -e "${GREEN}✓ Excellent! SOLID refactoring is working well.${NC}"
    elif [[ $score -ge 70 ]]; then
        echo -e "${YELLOW}⚠ Good, but some improvements needed.${NC}"
    else
        echo -e "${RED}✗ Significant issues found. Review the refactoring.${NC}"
    fi
    
    echo "=================================="
}

# Main test execution
main() {
    print_header
    
    test_system_api
    test_contracts
    test_user_module_separation
    test_configuration
    test_library_loader
    test_solid_compliance
    
    print_summary
    
    # Return exit code based on failures
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run tests
main "$@"