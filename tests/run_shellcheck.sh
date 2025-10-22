#!/bin/bash

set -euo pipefail

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "shellcheck not installed; skipping" >&2
    exit 0
fi

shellcheck \
    scripts/daily_admin.sh \
    core/lib/*.sh \
    modules/users/manage_users.sh \
    tests/test_core_behaviors.sh
