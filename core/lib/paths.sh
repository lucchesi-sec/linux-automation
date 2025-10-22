#!/bin/bash

# Path utility helpers for report and log locations

# Determine the base directory for writable data
resolve_data_root() {
    local default_root="/var/log/bash-admin"

    if [[ ${EUID} -eq 0 ]]; then
        echo "${default_root}"
    else
        echo "${BASH_ADMIN_DATA_DIR:-${HOME}/.bash-admin}"
    fi
}

# Resolve a sub-directory under the writable data root
resolve_data_dir() {
    local subpath="$1"
    local root
    root="$(resolve_data_root)"
    echo "${root}/${subpath}"
}

# Ensure a path exists and return it
ensure_dir() {
    local path="$1"
    mkdir -p "${path}"
    echo "${path}"
}
