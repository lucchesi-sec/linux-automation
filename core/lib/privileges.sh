#!/bin/bash

check_root_privileges() {
    [[ ${EUID} -eq 0 ]]
}

require_root() {
    local message="${1:-This action requires root privileges}"
    if ! check_root_privileges; then
        echo "${message}" >&2
        exit 1
    fi
}
