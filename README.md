# Linux Automation Lite

A minimal set of Bash helpers for day-to-day system administration. The project keeps the core pieces that matter to a solo maintainer:

- `scripts/daily_admin.sh` – snapshot disk usage, memory, failed services, pending APT upgrades, and produce a user account report.
- `modules/users/manage_users.sh` – generate a concise summary of regular user accounts, highlighting locked, passwordless, and privileged users.
- Lightweight core helpers for logging, configuration, privilege checks, and writable-path resolution.

## Requirements

- Bash 4+
- `jq` (only if you customise `config/config.json`)
- Utilities typically present on Linux hosts: `df`, `free`, `uptime`, `systemctl` (optional), `lastlog`, `passwd`, `groups`.

## Getting Started

```bash
 git clone https://github.com/lucchesi-sec/linux-automation.git
 cd linux-automation
 ./scripts/daily_admin.sh
```

The script writes daily summaries under:

- `$HOME/.bash-admin/reports` when running as an unprivileged user
- `/var/log/bash-admin/reports` when running as root

## Configuration

`config/config.json` holds a small set of optional overrides. At the moment the scripts only read it for future expansion, so you can leave it untouched or remove it entirely.

## Project Layout

```
core/        # tiny runtime helpers
modules/     # user-report generator
scripts/     # entry points
tests/       # smoke tests for logging and reporting
```

## Tests

```bash
./tests/test_core_behaviors.sh
```

The test suite runs two quick checks: logging fallback behaviour and user-report generation.

## Philosophy

This repository intentionally avoids heavyweight abstractions. The goal is to keep things comprehensible for a single maintainer—small scripts, clear output, no complicated dependency graph. Adapt the scripts to match your own daily routine.
