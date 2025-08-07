#!/bin/bash
# User Manager - Refactored Version
# Coordinates between data, analysis, and presentation layers
# Follows Service Contract and SOLID principles

# Source core libraries
source "$(dirname "$0")/../../core/lib/init.sh"
source "$(dirname "$0")/../../core/lib/contracts.sh"
source "$(dirname "$0")/../../core/lib/system_api.sh"

# Source separated modules
source "$(dirname "$0")/user_data.sh"
source "$(dirname "$0")/user_analysis.sh"
source "$(dirname "$0")/user_presentation.sh"

# ================================
# Service Coordinator Functions
# ================================

# Main user account status service
user_account_status_service() {
    local operation="${1:-report}"
    local output_format="${2:-text}"
    local report_file="${3:-/tmp/user_accounts_$(date +%Y%m%d).txt}"
    
    # Initialize transaction for rollback capability
    local transaction_id="$(date +%s)_$$"
    local rollback_stack=()
    
    log_info "Starting user account status service - Operation: $operation"
    
    case "$operation" in
        report)
            generate_user_report "$output_format" "$report_file"
            ;;
        audit)
            perform_user_audit "$output_format" "$report_file"
            ;;
        check)
            check_user_compliance "$output_format" "$report_file"
            ;;
        *)
            log_error "Unknown operation: $operation"
            return 1
            ;;
    esac
    
    local result=$?
    
    if [[ $result -eq 0 ]]; then
        log_success "User account status service completed successfully"
    else
        log_error "User account status service failed"
        # Perform rollback if needed
        perform_rollback "${rollback_stack[@]}"
    fi
    
    return $result
}

# Generate comprehensive user report
generate_user_report() {
    local format="${1:-text}"
    local output_file="${2:-}"
    
    # Statistics counters
    local total_users=0
    local active_users=0
    local locked_users=0
    local expired_users=0
    local privileged_users=0
    
    # Start report
    if [[ -n "$output_file" ]]; then
        exec 3>&1
        exec 1>"$output_file"
    fi
    
    display_report_header "User Account Status Report" "$format"
    
    # Get excluded users list
    local excluded_users
    excluded_users=$(fetch_excluded_users)
    
    # Process each user
    local all_users
    all_users=$(list_regular_users)
    
    while IFS= read -r username; do
        # Skip excluded users
        if echo "$excluded_users" | grep -q "^$username$"; then
            continue
        fi
        
        ((total_users++))
        
        # Data gathering phase
        local user_data
        user_data=$(get_all_user_data_json "$username")
        
        if [[ -z "$user_data" ]]; then
            log_warning "Failed to get data for user: $username"
            continue
        fi
        
        # Analysis phase
        local user_analysis password_analysis
        user_analysis=$(analyze_user_status "$user_data")
        
        local shadow_data
        shadow_data=$(echo "$user_data" | jq -r '.shadow_raw')
        password_analysis=$(calculate_password_age "$shadow_data")
        
        # Update counters based on analysis
        local status
        status=$(echo "$user_analysis" | jq -r '.status')
        
        case "$status" in
            ACTIVE) ((active_users++)) ;;
            LOCKED) ((locked_users++)) ;;
            EXPIRED) ((expired_users++)) ;;
        esac
        
        local flags
        flags=$(echo "$user_analysis" | jq -r '.security_flags[]?' 2>/dev/null)
        if echo "$flags" | grep -q "PRIVILEGED"; then
            ((privileged_users++))
        fi
        
        # Presentation phase
        format_user_status "$user_data" "$user_analysis" "$format"
        
    done <<< "$all_users"
    
    # Present summary
    local summary_stats
    summary_stats=$(cat <<EOF
{
    "total": $total_users,
    "active": $active_users,
    "locked": $locked_users,
    "expired": $expired_users,
    "privileged": $privileged_users
}
EOF
    )
    
    echo
    present_summary_statistics "$summary_stats" "$format"
    
    display_report_footer "$format"
    
    # Restore output
    if [[ -n "$output_file" ]]; then
        exec 1>&3
        exec 3>&-
        log_success "Report saved to: $output_file"
    fi
    
    return 0
}

# Perform security audit of users
perform_user_audit() {
    local format="${1:-text}"
    local output_file="${2:-}"
    
    # Start audit
    if [[ -n "$output_file" ]]; then
        exec 3>&1
        exec 1>"$output_file"
    fi
    
    display_report_header "User Security Audit Report" "$format"
    
    local all_users
    all_users=$(list_regular_users)
    
    local critical_issues=()
    local high_risk_users=()
    
    while IFS= read -r username; do
        # Data gathering
        local user_data
        user_data=$(get_all_user_data_json "$username")
        
        if [[ -z "$user_data" ]]; then
            continue
        fi
        
        # Analysis
        local user_analysis password_analysis
        user_analysis=$(analyze_user_status "$user_data")
        
        local shadow_data
        shadow_data=$(echo "$user_data" | jq -r '.shadow_raw')
        password_analysis=$(calculate_password_age "$shadow_data")
        
        # Security scoring
        local security_score
        security_score=$(evaluate_user_security_score "$user_analysis" "$password_analysis")
        
        local score
        score=$(echo "$security_score" | jq -r '.score')
        
        # Track critical issues
        if [[ $score -lt 50 ]]; then
            critical_issues+=("$username (Score: $score)")
        elif [[ $score -lt 70 ]]; then
            high_risk_users+=("$username (Score: $score)")
        fi
        
        # Present findings
        echo "User: $username"
        format_security_score "$security_score" "$format"
        echo
        
    done <<< "$all_users"
    
    # Present audit summary
    echo
    echo "AUDIT SUMMARY:"
    echo "Critical Issues (Score < 50): ${#critical_issues[@]}"
    if [[ ${#critical_issues[@]} -gt 0 ]]; then
        printf '%s\n' "${critical_issues[@]}" | sed 's/^/  - /'
    fi
    
    echo "High Risk Users (Score < 70): ${#high_risk_users[@]}"
    if [[ ${#high_risk_users[@]} -gt 0 ]]; then
        printf '%s\n' "${high_risk_users[@]}" | sed 's/^/  - /'
    fi
    
    display_report_footer "$format"
    
    # Restore output
    if [[ -n "$output_file" ]]; then
        exec 1>&3
        exec 3>&-
        log_success "Audit report saved to: $output_file"
    fi
    
    return 0
}

# Check user compliance with policy
check_user_compliance() {
    local format="${1:-text}"
    local output_file="${2:-}"
    local policy_file="${3:-/etc/admin-tools/user_policy.json}"
    
    # Load policy
    local policy="{}"
    if [[ -f "$policy_file" ]]; then
        policy=$(cat "$policy_file")
    fi
    
    # Start compliance check
    if [[ -n "$output_file" ]]; then
        exec 3>&1
        exec 1>"$output_file"
    fi
    
    display_report_header "User Compliance Report" "$format"
    
    local all_users
    all_users=$(list_regular_users)
    
    local compliant_count=0
    local non_compliant_users=()
    
    while IFS= read -r username; do
        # Data gathering
        local user_data
        user_data=$(get_all_user_data_json "$username")
        
        if [[ -z "$user_data" ]]; then
            continue
        fi
        
        # Compliance assessment
        local compliance
        compliance=$(assess_policy_compliance "$user_data" "$policy")
        
        local is_compliant
        is_compliant=$(echo "$compliance" | jq -r '.compliant')
        
        if [[ "$is_compliant" == "true" ]]; then
            ((compliant_count++))
        else
            non_compliant_users+=("$username")
        fi
        
        # Present compliance status
        echo "User: $username"
        present_compliance_report "$compliance" "$format"
        echo
        
    done <<< "$all_users"
    
    # Present compliance summary
    local total_checked
    total_checked=$(echo "$all_users" | wc -l)
    
    echo
    echo "COMPLIANCE SUMMARY:"
    echo "  Total Users Checked: $total_checked"
    echo "  Compliant: $compliant_count"
    echo "  Non-Compliant: ${#non_compliant_users[@]}"
    
    if [[ ${#non_compliant_users[@]} -gt 0 ]]; then
        echo "  Non-Compliant Users:"
        printf '%s\n' "${non_compliant_users[@]}" | sed 's/^/    - /'
    fi
    
    display_report_footer "$format"
    
    # Restore output
    if [[ -n "$output_file" ]]; then
        exec 1>&3
        exec 3>&-
        log_success "Compliance report saved to: $output_file"
    fi
    
    return 0
}

# Perform rollback on failure
perform_rollback() {
    local rollback_stack=("$@")
    
    if [[ ${#rollback_stack[@]} -eq 0 ]]; then
        return 0
    fi
    
    log_warning "Performing rollback..."
    
    for ((i=${#rollback_stack[@]}-1; i>=0; i--)); do
        local rollback_action="${rollback_stack[i]}"
        log_info "Rollback: $rollback_action"
        eval "$rollback_action"
    done
    
    log_info "Rollback completed"
}

# ================================
# Contract Validation
# ================================

# Validate this module's contracts
validate_module_contracts() {
    log_info "Validating module contracts..."
    
    local violations=0
    
    # Validate data provider contracts
    for func in get_user_data list_system_users list_regular_users; do
        if ! validate_contract "data_provider" "$func"; then
            ((violations++))
        fi
    done
    
    # Validate analyzer contracts
    for func in analyze_user_status calculate_password_age evaluate_user_security_score; do
        if ! validate_contract "analyzer" "$func"; then
            ((violations++))
        fi
    done
    
    # Validate presenter contracts
    for func in format_user_status present_summary_statistics format_security_score; do
        if ! validate_contract "presenter" "$func"; then
            ((violations++))
        fi
    done
    
    # Validate service contracts
    for func in user_account_status_service; do
        if ! validate_contract "service" "$func"; then
            ((violations++))
        fi
    done
    
    if [[ $violations -eq 0 ]]; then
        log_success "All contracts validated successfully"
    else
        log_error "Contract violations found: $violations"
    fi
    
    return $violations
}

# ================================
# Module Entry Point
# ================================

# Main function
main() {
    local command="${1:-help}"
    shift
    
    case "$command" in
        report)
            user_account_status_service "report" "$@"
            ;;
        audit)
            user_account_status_service "audit" "$@"
            ;;
        compliance)
            user_account_status_service "check" "$@"
            ;;
        validate)
            validate_module_contracts
            ;;
        help)
            cat <<EOF
User Manager - Refactored Version

Usage: $0 <command> [options]

Commands:
    report [format] [file]     Generate user status report
    audit [format] [file]      Perform security audit
    compliance [format] [file] Check policy compliance
    validate                   Validate module contracts
    help                       Show this help

Formats: text, json, html, csv

This module follows SOLID principles with separated concerns:
- Data gathering (user_data.sh)
- Analysis (user_analysis.sh)
- Presentation (user_presentation.sh)
- Coordination (this file)
EOF
            ;;
        *)
            log_error "Unknown command: $command"
            return 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi