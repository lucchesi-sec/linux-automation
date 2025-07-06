# Module Documentation

**Navigation**: [Home](../README.md) | [Installation](installation.md) | [Configuration](configuration.md)

This guide provides a complete reference for all modules in the Linux Daily Administration Automation toolkit.

## Core Modules

The core modules provide essential, shared functionality that is used by other scripts in the toolkit.

-   **[init.sh](../core/lib/init.sh)**: Initialization and common functions.
-   **[logging.sh](../core/lib/logging.sh)**: Logging utilities.
-   **[config.sh](../core/lib/config.sh)**: Configuration management.
-   **[notifications.sh](../core/lib/notifications.sh)**: Email and alert functions.
-   **[privileges.sh](../core/lib/privileges.sh)**: Functions for checking and managing root/sudo privileges.

## Reusable Modules

These modules contain the primary business logic for various administrative tasks.

-   **[user_management.sh](../modules/users/user_management.sh)**: User management functions.
-   **[backup_monitor.sh](../modules/system/backup_monitor.sh)**: Backup monitoring functions.
-   **[security_audit.sh](../modules/system/security_audit.sh)**: Security audit functions.
-   **[log_management.sh](../modules/system/log_management.sh)**: Log management functions.
