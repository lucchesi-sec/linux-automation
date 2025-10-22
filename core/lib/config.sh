#!/bin/bash

# Minimal configuration loader

declare -gA BASH_ADMIN_CONFIG=()
declare -g BASH_ADMIN_CONFIG_FILE=""

init_config() {
    local candidate="${BASH_ADMIN_CONFIG_FILE:-${BASH_ADMIN_ROOT}/config/config.json}"

    if [[ -f "${candidate}" ]]; then
        if ! command -v jq >/dev/null 2>&1; then
            echo "jq not found; skipping configuration file" >&2
            return
        fi

        local entries
        entries=$(jq -r 'to_entries | .[] | "\(.key)=\(.value|tostring)"' "${candidate}") || return

        while IFS='=' read -r key value; do
            BASH_ADMIN_CONFIG["${key}"]="${value}"
        done <<< "${entries}"
    fi
}

get_config() {
    local key="$1"
    local default_value="${2:-}"

    if [[ -n "${BASH_ADMIN_CONFIG[${key}]:-}" ]]; then
        echo "${BASH_ADMIN_CONFIG[${key}]}"
    else
        echo "${default_value}"
    fi
}
