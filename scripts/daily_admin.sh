#!/bin/bash

set -uo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_ROOT}/../core/lib/init.sh"
source "${SCRIPT_ROOT}/../modules/users/manage_users.sh"

bash_admin_init

REPORT_DIR="$(resolve_data_dir "reports")"
ensure_dir "${REPORT_DIR}"
DATE_STAMP="$(date +%Y%m%d)"
SUMMARY_FILE="${REPORT_DIR}/daily_admin_${DATE_STAMP}.txt"
USER_REPORT="${REPORT_DIR}/user_report_${DATE_STAMP}.txt"

generate_user_report "${USER_REPORT}"
CURRENT_TIME="$(date)"

{
    echo "Daily Administration Summary"
    echo "Generated: ${CURRENT_TIME}"
    echo

    echo "Disk Usage:"
    df -h / | tail -n +2
    echo

    echo "Memory Usage:"
    if command -v free >/dev/null 2>&1; then
        free -h
    else
        echo "free command not available"
    fi
    echo

    echo "Load Average:"
    uptime
    echo

    if command -v systemctl >/dev/null 2>&1; then
        echo "Failed Services:"
        systemctl --failed --no-legend || true
        echo
    fi

    if command -v apt-get >/dev/null 2>&1; then
        echo "Pending APT Updates:"
        if apt-get -s upgrade 2>/dev/null | grep -E "upgraded,|packages can be upgraded"; then
            true
        else
            echo "No pending upgrades"
        fi
        echo
    fi

    echo "User report saved to: ${USER_REPORT}"
} > "${SUMMARY_FILE}"

echo "Summary written to ${SUMMARY_FILE}"
