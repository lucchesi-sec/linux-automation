#!/bin/bash
# User Analysis Module
# Responsible ONLY for analyzing user data
# Follows Analyzer Contract - pure functions, no system access

# ================================
# Analyzer Functions
# ================================

# Analyze user account status
analyze_user_status() {
    local user_json="$1"
    
    if [[ -z "$user_json" ]]; then
        echo "Error: User data required" >&2
        return 1
    fi
    
    # Parse JSON data
    local password_status uid shell groups
    password_status=$(echo "$user_json" | jq -r '.password_status' 2>/dev/null)
    uid=$(echo "$user_json" | jq -r '.uid' 2>/dev/null)
    shell=$(echo "$user_json" | jq -r '.shell' 2>/dev/null)
    groups=$(echo "$user_json" | jq -r '.groups' 2>/dev/null)
    
    local status="ACTIVE"
    local risk_level="LOW"
    local security_flags=()
    
    # Analyze password status
    case "$password_status" in
        "L"|"LK")
            status="LOCKED"
            ;;
        "NP")
            status="NO_PASSWORD"
            risk_level="HIGH"
            security_flags+=("NO_PASSWORD")
            ;;
        "")
            security_flags+=("EMPTY_PASSWORD")
            risk_level="CRITICAL"
            ;;
    esac
    
    # Analyze UID
    if [[ "$uid" -eq 0 ]] && [[ "$(echo "$user_json" | jq -r '.username')" != "root" ]]; then
        security_flags+=("UID_ZERO_NON_ROOT")
        risk_level="CRITICAL"
    fi
    
    # Analyze shell
    case "$shell" in
        "/bin/false"|"/sbin/nologin"|"/usr/sbin/nologin")
            [[ "$status" == "ACTIVE" ]] && status="DISABLED"
            ;;
        "/bin/bash"|"/bin/sh"|"/usr/bin/bash"|"/usr/bin/sh")
            # Normal shells
            ;;
        *)
            security_flags+=("CUSTOM_SHELL")
            ;;
    esac
    
    # Analyze groups for privilege escalation
    if echo "$groups" | grep -qE "(sudo|wheel|admin|root)"; then
        security_flags+=("PRIVILEGED")
        [[ "$risk_level" == "LOW" ]] && risk_level="MEDIUM"
    fi
    
    # Output analysis result as JSON
    cat <<EOF
{
    "status": "$status",
    "risk_level": "$risk_level",
    "security_flags": $(printf '%s\n' "${security_flags[@]}" | jq -R . | jq -s .)
}
EOF
}

# Calculate password age and expiry
calculate_password_age() {
    local shadow_data="$1"
    
    if [[ -z "$shadow_data" ]]; then
        echo "Error: Shadow data required" >&2
        return 1
    fi
    
    # Parse shadow fields
    local last_change min_age max_age warn_period expire_date
    last_change=$(echo "$shadow_data" | cut -d: -f3)
    min_age=$(echo "$shadow_data" | cut -d: -f4)
    max_age=$(echo "$shadow_data" | cut -d: -f5)
    warn_period=$(echo "$shadow_data" | cut -d: -f6)
    expire_date=$(echo "$shadow_data" | cut -d: -f8)
    
    local current_days=$(($(date +%s) / 86400))
    local age_days=0
    local days_until_expiry=-1
    local is_expired=false
    
    # Calculate age
    if [[ -n "$last_change" && "$last_change" != "" ]]; then
        age_days=$((current_days - last_change))
    fi
    
    # Calculate expiry
    if [[ -n "$max_age" && "$max_age" != "" && "$max_age" -gt 0 ]]; then
        days_until_expiry=$((max_age - age_days))
        [[ $days_until_expiry -lt 0 ]] && is_expired=true
    fi
    
    # Check account expiry
    if [[ -n "$expire_date" && "$expire_date" != "" ]]; then
        if [[ $expire_date -lt $current_days ]]; then
            is_expired=true
        fi
    fi
    
    # Output analysis as JSON
    cat <<EOF
{
    "age_days": $age_days,
    "min_age": ${min_age:-0},
    "max_age": ${max_age:--1},
    "warn_period": ${warn_period:-7},
    "days_until_expiry": $days_until_expiry,
    "is_expired": $is_expired,
    "requires_change": $([[ $days_until_expiry -le ${warn_period:-7} ]] && echo true || echo false)
}
EOF
}

# Evaluate user security score
evaluate_user_security_score() {
    local user_analysis="$1"
    local password_analysis="$2"
    
    local score=100
    local deductions=()
    
    # Parse analyses
    local risk_level security_flags is_expired
    risk_level=$(echo "$user_analysis" | jq -r '.risk_level' 2>/dev/null)
    security_flags=$(echo "$user_analysis" | jq -r '.security_flags[]' 2>/dev/null)
    is_expired=$(echo "$password_analysis" | jq -r '.is_expired' 2>/dev/null)
    
    # Apply deductions based on risk level
    case "$risk_level" in
        "CRITICAL")
            score=$((score - 50))
            deductions+=("Critical risk: -50")
            ;;
        "HIGH")
            score=$((score - 30))
            deductions+=("High risk: -30")
            ;;
        "MEDIUM")
            score=$((score - 15))
            deductions+=("Medium risk: -15")
            ;;
    esac
    
    # Apply deductions for security flags
    while IFS= read -r flag; do
        case "$flag" in
            "NO_PASSWORD")
                score=$((score - 25))
                deductions+=("No password: -25")
                ;;
            "EMPTY_PASSWORD")
                score=$((score - 40))
                deductions+=("Empty password: -40")
                ;;
            "UID_ZERO_NON_ROOT")
                score=$((score - 50))
                deductions+=("UID 0 non-root: -50")
                ;;
            "PRIVILEGED")
                score=$((score - 5))
                deductions+=("Privileged access: -5")
                ;;
        esac
    done <<< "$security_flags"
    
    # Apply deductions for password expiry
    if [[ "$is_expired" == "true" ]]; then
        score=$((score - 20))
        deductions+=("Password expired: -20")
    fi
    
    # Ensure score doesn't go below 0
    [[ $score -lt 0 ]] && score=0
    
    # Output score analysis
    cat <<EOF
{
    "score": $score,
    "grade": "$(calculate_grade $score)",
    "deductions": $(printf '%s\n' "${deductions[@]}" | jq -R . | jq -s .)
}
EOF
}

# Calculate security grade from score
calculate_grade() {
    local score="$1"
    
    if [[ $score -ge 90 ]]; then
        echo "A"
    elif [[ $score -ge 80 ]]; then
        echo "B"
    elif [[ $score -ge 70 ]]; then
        echo "C"
    elif [[ $score -ge 60 ]]; then
        echo "D"
    else
        echo "F"
    fi
}

# Assess user compliance with policy
assess_policy_compliance() {
    local user_json="$1"
    local policy_json="${2:-{}}"
    
    local violations=()
    local compliant=true
    
    # Parse policy requirements
    local require_password min_password_age max_password_age allowed_shells
    require_password=$(echo "$policy_json" | jq -r '.require_password // true' 2>/dev/null)
    min_password_age=$(echo "$policy_json" | jq -r '.min_password_age // 1' 2>/dev/null)
    max_password_age=$(echo "$policy_json" | jq -r '.max_password_age // 90' 2>/dev/null)
    allowed_shells=$(echo "$policy_json" | jq -r '.allowed_shells[]? // "/bin/bash"' 2>/dev/null)
    
    # Check password requirement
    local password_status
    password_status=$(echo "$user_json" | jq -r '.password_status' 2>/dev/null)
    
    if [[ "$require_password" == "true" ]] && [[ "$password_status" == "NP" ]]; then
        violations+=("Missing required password")
        compliant=false
    fi
    
    # Check shell compliance
    local user_shell
    user_shell=$(echo "$user_json" | jq -r '.shell' 2>/dev/null)
    
    if [[ -n "$allowed_shells" ]] && ! echo "$allowed_shells" | grep -q "$user_shell"; then
        violations+=("Non-compliant shell: $user_shell")
        compliant=false
    fi
    
    # Output compliance result
    cat <<EOF
{
    "compliant": $compliant,
    "violations": $(printf '%s\n' "${violations[@]}" | jq -R . | jq -s .)
}
EOF
}

# Analyze user activity patterns
analyze_user_activity() {
    local last_login="$1"
    local home_size="$2"
    
    local activity_level="UNKNOWN"
    local days_inactive=0
    
    # Parse last login to determine activity
    if [[ "$last_login" != "Unknown" ]] && [[ -n "$last_login" ]]; then
        # Simple activity classification based on last login
        if echo "$last_login" | grep -q "$(date +%b)"; then
            activity_level="ACTIVE"
        else
            activity_level="INACTIVE"
            # Could calculate exact days if needed
        fi
    fi
    
    # Classify based on home directory size
    local usage_level="LOW"
    if [[ -n "$home_size" ]]; then
        # Convert size to MB for comparison
        local size_mb
        if echo "$home_size" | grep -q "G"; then
            size_mb=$(($(echo "$home_size" | sed 's/G//') * 1024))
        elif echo "$home_size" | grep -q "M"; then
            size_mb=$(echo "$home_size" | sed 's/M//')
        else
            size_mb=0
        fi
        
        if [[ $size_mb -gt 1024 ]]; then
            usage_level="HIGH"
        elif [[ $size_mb -gt 100 ]]; then
            usage_level="MEDIUM"
        fi
    fi
    
    # Output activity analysis
    cat <<EOF
{
    "activity_level": "$activity_level",
    "usage_level": "$usage_level",
    "last_seen": "$last_login",
    "home_size": "$home_size"
}
EOF
}