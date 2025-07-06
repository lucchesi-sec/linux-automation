# Installation Guide

**Navigation**: [Home](../README.md) | [Configuration](configuration.md) | [Examples](examples.md)

This guide provides detailed instructions for installing the Linux Daily Administration Automation toolkit.

## Prerequisites

-   Linux system (Ubuntu 18.04+, CentOS 7+, or similar)
-   Bash 4.0 or higher
-   Root or sudo privileges for system administration tasks
-   Basic system utilities: `grep`, `awk`, `sed`, `find`, `systemctl`

### Optional Dependencies

-   `mail` or `sendmail` for email notifications
-   `logrotate` for enhanced log management
-   `fail2ban` for security monitoring
-   `ufw` or `iptables` for firewall management

## Detailed Installation

1.  **Clone and Setup**:
    ```bash
    git clone https://github.com/lucchesi-sec/linux-automation.git
    cd linux-automation
    ```

2.  **Set Permissions**:
    ```bash
    find . -name "*.sh" -exec chmod +x {} \;
    ```

3.  **Create Log Directories**:
    ```bash
    sudo mkdir -p /var/log/bash-admin/{daily-reports,security-reports,backup-reports,user-reports,log-reports}
    ```

4.  **Configure System**:
    ```bash
    # Copy configuration template
    sudo cp config/config.json.example config/config.json

    # Edit configuration for your environment
    sudo nano config/config.json
    ```

## Verifying the Installation

After completing the installation and configuration, you can verify that everything is working correctly by running the system health check.

```bash
sudo ./modules/system/health_check.sh
```

If the script runs without errors, the installation is successful. You can also run the full daily administration suite to ensure all modules are functioning as expected.

```bash
sudo ./scripts/administration/daily_admin_suite.sh
