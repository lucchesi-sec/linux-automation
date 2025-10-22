#!/bin/bash

BASH_ADMIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASH_ADMIN_CORE="${BASH_ADMIN_ROOT}/core"
BASH_ADMIN_LIB="${BASH_ADMIN_CORE}/lib"

export BASH_ADMIN_ROOT
export BASH_ADMIN_CORE
export BASH_ADMIN_LIB

source "${BASH_ADMIN_LIB}/paths.sh"
source "${BASH_ADMIN_LIB}/logging.sh"
source "${BASH_ADMIN_LIB}/config.sh"
source "${BASH_ADMIN_LIB}/privileges.sh"

bash_admin_init() {
    init_logging
    init_config
}
