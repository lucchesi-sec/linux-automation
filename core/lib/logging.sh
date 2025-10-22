#!/bin/bash

# Lightweight logging utilities

declare -g LOG_LEVEL_DEBUG=0
declare -g LOG_LEVEL_INFO=1
declare -g LOG_LEVEL_WARN=2
declare -g LOG_LEVEL_ERROR=3

declare -g CURRENT_LOG_LEVEL=${BASH_ADMIN_LOG_LEVEL:-1}
declare -g LOG_FILE=""

init_logging() {
    local log_dir
    if declare -f resolve_data_dir >/dev/null 2>&1; then
        log_dir="${BASH_ADMIN_LOG_DIR:-$(resolve_data_dir "logs")}"
    else
        log_dir="${BASH_ADMIN_LOG_DIR:-${HOME}/.bash-admin/logs}"
    fi

    if ! mkdir -p "${log_dir}" 2>/dev/null; then
        if declare -f resolve_data_dir >/dev/null 2>&1; then
            log_dir="$(resolve_data_dir "logs")"
        else
            log_dir="${HOME}/.bash-admin/logs"
        fi
        mkdir -p "${log_dir}" 2>/dev/null || true
    fi

    if [[ -w "${log_dir}" ]]; then
        LOG_FILE="${log_dir}/bash-admin-$(date '+%Y-%m-%d').log"
        touch "${LOG_FILE}" 2>/dev/null || LOG_FILE=""
    else
        LOG_FILE=""
    fi
}

write_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    local entry="[${timestamp}] [${level}] ${message}"
    echo "${entry}"

    if [[ -n "${LOG_FILE}" ]]; then
        echo "${entry}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

log_debug() {
    [[ ${CURRENT_LOG_LEVEL} -le ${LOG_LEVEL_DEBUG} ]] && write_log "DEBUG" "$1"
}

log_info() {
    [[ ${CURRENT_LOG_LEVEL} -le ${LOG_LEVEL_INFO} ]] && write_log "INFO" "$1"
}

log_warn() {
    [[ ${CURRENT_LOG_LEVEL} -le ${LOG_LEVEL_WARN} ]] && write_log "WARN" "$1"
}

log_error() {
    [[ ${CURRENT_LOG_LEVEL} -le ${LOG_LEVEL_ERROR} ]] && write_log "ERROR" "$1"
}

log_fatal() {
    write_log "FATAL" "$1"
    exit 1
}

init_logging
