# Troubleshooting Guide

**Navigation**: [Home](../README.md) | [Installation](installation.md) | [Configuration](configuration.md)

This guide provides solutions to common issues and errors that you may encounter while using the Linux Daily Administration Automation toolkit.

## Common Issues

**Permission Denied Errors**:
If you see "Permission denied" errors, it usually means that the scripts do not have the correct execute permissions or that the log directories are not writable by the script's user.

```bash
# Make all scripts executable.
find . -name "*.sh" -exec chmod +x {} \;

# Ensure the log directory is owned by root.
sudo chown -R root:root /var/log/bash-admin/
```

**Email Notifications Not Working**:
-   Verify SMTP configuration in `config/config.json`.
-   Check the system mail service (e.g., Postfix, Sendmail): `systemctl status postfix`.
-   Test mail delivery from the command line: `echo "test" | mail -s "test" admin@example.com`.

**Scripts Not Finding Modules**:
-   Ensure the project's directory structure has not been altered.
-   Check that all script files have read and execute permissions.
-   Verify the `source` paths at the beginning of the scripts.

## Debug Mode

Run any script with the `--verbose` flag to enable detailed logging. This is the best way to diagnose issues.

```bash
sudo ./scripts/administration/daily_admin_suite.sh --verbose
```

You can also monitor the main log file in real-time to see the output of the scripts.

```bash
tail -f /var/log/bash-admin/system.log
