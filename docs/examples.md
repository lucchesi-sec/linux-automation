# Usage Examples

**Navigation**: [Home](../README.md) | [Installation](installation.md) | [Configuration](configuration.md)

This guide provides real-world usage examples for the Linux Daily Administration Automation toolkit.

## Run Individual Scripts

You can run any of the scripts individually to perform specific administrative tasks.

```bash
# --- User Management ---
# Run the daily user tasks, such as checking for inactive accounts.
sudo ./scripts/administration/daily_user_tasks.sh

# --- Backup & Recovery ---
# Verify the integrity of recent backups.
sudo ./scripts/administration/daily_backup_check.sh

# --- Security ---
# Perform a comprehensive security audit of the system.
sudo ./scripts/administration/daily_security_audit.sh

# --- Log Management ---
# Rotate, compress, and clean up system logs.
sudo ./scripts/administration/daily_log_maintenance.sh
```

## Run Complete Daily Suite

The `daily_admin_suite.sh` script is the main entry point for running all daily tasks.

```bash
# Run all daily administrative tasks in sequence.
sudo ./scripts/administration/daily_admin_suite.sh

# Run in verbose mode to see detailed output from each script.
sudo ./scripts/administration/daily_admin_suite.sh --verbose

# Run only a specific task from the suite (e.g., backup_check).
sudo ./scripts/administration/daily_admin_suite.sh --only backup_check

# Skip a specific task from the suite (e.g., security_check).
sudo ./scripts/administration/daily_admin_suite.sh --skip security_check
```

## Automation and Scheduling

The scripts are designed to be run automatically using `cron` or `systemd` timers.

### Cron Setup

Add the following entries to the root user's crontab to schedule the scripts.

```bash
# Edit the root crontab.
sudo crontab -e

# Add the following lines:
# Run the full administration suite daily at 6:00 AM.
0 6 * * * /path/to/linux-automation/scripts/administration/daily_admin_suite.sh --quiet

# Run a security audit twice a day, at 6:00 AM and 6:00 PM.
0 6,18 * * * /path/to/linux-automation/scripts/administration/daily_security_audit.sh --quiet

# Perform log maintenance every day at midnight.
0 0 * * * /path/to/linux-automation/scripts/administration/daily_log_maintenance.sh --quiet
```

### Systemd Timer Setup

Alternatively, you can use `systemd` timers for more flexible scheduling.

```bash
# Copy the service and timer files to the systemd directory.
sudo cp systemd/bash-admin-daily.service /etc/systemd/system/
sudo cp systemd/bash-admin-daily.timer /etc/systemd/system/

# Reload the systemd daemon, then enable and start the timer.
sudo systemctl daemon-reload
sudo systemctl enable bash-admin-daily.timer
sudo systemctl start bash-admin-daily.timer
