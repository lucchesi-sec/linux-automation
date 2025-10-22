#!/bin/bash
# Targeted unit tests for critical core behaviors

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
declare -a FAILED_TESTS=()

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

print_header() {
    echo "=================================="
    echo "Core Behavior Test Suite"
    echo "=================================="
    echo
}

print_result() {
    local name="$1"
    local status="$2"

    ((TESTS_RUN++))

    if [[ "${status}" == "PASS" ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}✓${NC} ${name}"
    else
        ((TESTS_FAILED++))
        FAILED_TESTS+=("${name}")
        echo -e "${RED}✗${NC} ${name}"
    fi
}

test_logging_fallback() {
    local tmpdir
    tmpdir=$(mktemp -d)
    chmod 000 "${tmpdir}"
    local target_dir="${tmpdir}/unwritable/logs"

    local output=""
    local status=0

    output=$(BASH_ADMIN_LOG_DIR="${target_dir}" bash -lc '
        set -e
        cd "'"${PROJECT_ROOT}"'"
        sudo() { return 1; }
        source core/lib/paths.sh
        source core/lib/logging.sh
        echo "$LOG_FILE"
    ') || status=$?

    chmod 755 "${tmpdir}"
    rm -rf "${tmpdir}"

    if [[ ${status} -ne 0 ]]; then
        echo "init_logging failed with status ${status}"
        return 1
    fi

    local fallback_dir="${HOME}/.bash-admin/logs"
    local resolved_file="${output}"

    if [[ "$(dirname "${resolved_file}")" != "${fallback_dir}" ]]; then
        echo "Expected fallback dir '${fallback_dir}', got '$(dirname "${resolved_file}")'"
        return 1
    fi

    if [[ ! -f "${resolved_file}" ]]; then
        echo "Log file '${resolved_file}' was not created"
        return 1
    fi

    rm -f "${resolved_file}"

    return 0
}

test_generate_user_report() {
    local tmpdir
    tmpdir=$(mktemp -d)
    local report="${tmpdir}/report.txt"

    bash -lc '
        set -e
        cd "'"${PROJECT_ROOT}"'"
        source core/lib/init.sh
        source modules/users/manage_users.sh
        bash_admin_init
        generate_user_report "'"${report}"'"
    '

    if [[ ! -s "${report}" ]]; then
        echo "Report file is empty"
        rm -rf "${tmpdir}"
        return 1
    fi

    if ! grep -q "User Account Report" "${report}"; then
        echo "Report header missing"
        rm -rf "${tmpdir}"
        return 1
    fi

    rm -rf "${tmpdir}"
    return 0
}

test_daily_admin_script() {
    local tmpdir
    tmpdir=$(mktemp -d)
    BASH_ADMIN_DATA_DIR="${tmpdir}" bash -lc '
        set -e
        cd "'"${PROJECT_ROOT}"'"
        ./scripts/daily_admin.sh >/dev/null
    '

    if [[ ! -d "${tmpdir}/reports" ]]; then
        echo "Expected reports directory not created"
        rm -rf "${tmpdir}"
        return 1
    fi

    if ! ls "${tmpdir}"/reports/daily_admin_*.txt >/dev/null 2>&1; then
        echo "No daily admin summary produced"
        rm -rf "${tmpdir}"
        return 1
    fi

    rm -rf "${tmpdir}"
    return 0
}

run_tests() {
    print_header

    local status
    if test_logging_fallback; then
        status="PASS"
    else
        status="FAIL"
    fi
    print_result "Logging falls back to user directory when unwritable" "${status}"

    if test_generate_user_report; then
        status="PASS"
    else
        status="FAIL"
    fi
    print_result "User report generation produces output" "${status}"

    if test_daily_admin_script; then
        status="PASS"
    else
        status="FAIL"
    fi
    print_result "Daily admin script runs end-to-end" "${status}"

    echo
    echo "=================================="
    echo "Test Summary"
    echo "=================================="
    echo "Tests Run: ${TESTS_RUN}"
    echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"

    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        echo
        echo "Failed Tests:"
        for name in "${FAILED_TESTS[@]}"; do
            echo "  - ${name}"
        done
    fi

    echo

    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        exit 1
    fi
}

run_tests
