#!/bin/bash

# Simple utilities for inspecting local user accounts

generate_user_report() {
    local output_file="$1"
    local now
    now=$(date)

    local total=0
    local locked=0
    local passwordless=0
    local privileged=0

    {
        echo "User Account Report"
        echo "Generated: ${now}"
        echo
        printf "%-16s %-6s %-8s %-12s %-20s %-30s\n" "User" "UID" "Status" "Password" "Last Login" "Groups"
        printf "%s\n" "----------------------------------------------------------------------------------------------"
    } > "${output_file}"

    while IFS=: read -r username _ uid gid gecos home shell; do
        [[ -z "${username}" ]] && continue
        [[ ${uid} -lt 1000 ]] && continue

        ((total++))

        local status="ACTIVE"
        local pass_state="set"

        local passwd_info
        passwd_info=$(passwd -S "${username}" 2>/dev/null || true)
        if [[ -n "${passwd_info}" ]]; then
            local passwd_status
            passwd_status=$(echo "${passwd_info}" | awk '{print $2}')
            case "${passwd_status}" in
                L|LK)
                    status="LOCKED"
                    ((locked++))
                    ;;
                NP)
                    pass_state="none"
                    ((passwordless++))
                    ;;
                *)
                    ;;
            esac
        fi

        local groups="(unknown)"
        if groups "${username}" >/dev/null 2>&1; then
            local groups_output
            groups_output=$(groups "${username}" 2>/dev/null | cut -d: -f2- | xargs || true)
            if [[ -n "${groups_output}" ]]; then
                groups="${groups_output}"
            fi
            if [[ "${groups}" =~ (sudo|wheel|admin|root) ]]; then
                ((privileged++))
            fi
        fi

        local last_login="n/a"
        if command -v lastlog >/dev/null 2>&1; then
            last_login=$(lastlog -u "${username}" 2>/dev/null | tail -n1 | awk '{$1=""; print substr($0,2)}' || true)
            [[ -z "${last_login}" ]] && last_login="never"
        fi

        printf "%-16s %-6s %-8s %-12s %-20s %-30s\n" \
            "${username}" "${uid}" "${status}" "${pass_state}" "${last_login}" "${groups}" >> "${output_file}"
    done < /etc/passwd

    {
        echo
        echo "Summary"
        echo "-------"
        echo "Total regular users : ${total}"
        echo "Locked accounts     : ${locked}"
        echo "Passwordless users  : ${passwordless}"
        echo "Privileged members  : ${privileged}"
    } >> "${output_file}"
}
