# Installation Guide

This guide provides step-by-step instructions for installing and setting up the Linux Daily Administration Automation system.

## Table of Contents

- [System Requirements](#system-requirements)
- [Pre-Installation Checklist](#pre-installation-checklist)
- [Installation Methods](#installation-methods)
- [Post-Installation Configuration](#post-installation-configuration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## System Requirements

### Minimum Requirements

- **Operating System**: Linux (Ubuntu 18.04+, CentOS 7+, RHEL 7+, Debian 9+)
- **Shell**: Bash 4.0 or higher
- **Privileges**: Root or sudo access
- **Disk Space**: 100 MB for installation, 1 GB for logs and reports
- **Memory**: 512 MB RAM minimum

### Supported Distributions

| Distribution | Versions | Status |
|--------------|----------|--------|
| Ubuntu | 18.04, 20.04, 22.04, 24.04 | ✅ Fully Supported |
| CentOS | 7, 8 | ✅ Fully Supported |
| RHEL | 7, 8, 9 | ✅ Fully Supported |
| Debian | 9, 10, 11, 12 | ✅ Fully Supported |
| Amazon Linux | 2 | ✅ Fully Supported |
| SUSE Linux | 15+ | ⚠️ Limited Testing |

### Required Packages

#### Core Dependencies (Usually Pre-installed)
```bash
# Check if these are available
bash --version    # Should be 4.0+
grep --version
awk --version
sed --version
find --version
systemctl --version
```

#### Optional Dependencies
```bash
# For enhanced functionality
jq              # JSON parsing (recommended)
mail            # Email notifications
logrotate       # Advanced log management
fail2ban        # Security monitoring
ufw             # Firewall management
bc              # Floating-point calculations
curl            # External API integration
```

## Pre-Installation Checklist

### 1. System Check
```bash
# Check OS version
cat /etc/os-release

# Check Bash version
bash --version

# Check available disk space
df -h

# Check memory
free -h

# Verify sudo/root access
sudo whoami
```

### 2. Network Requirements
```bash
# For email notifications (optional)
# Test SMTP connectivity
telnet your-smtp-server.com 587

# For package installation (if needed)
ping google.com
```

### 3. User Permissions
```bash
# Verify user can create directories in /var/log
sudo mkdir -p /var/log/test-bash-admin
sudo rmdir /var/log/test-bash-admin

# Check if user can modify cron (for automation)
crontab -l
```

## Installation Methods

### Method 1: Git Clone (Recommended)

#### Step 1: Clone Repository
```bash
# Clone to recommended location
sudo mkdir -p /opt
cd /opt
sudo git clone https://github.com/your-org/linux-automation.git
sudo chown -R $(whoami):$(whoami) /opt/linux-automation

# Alternative: Clone to user directory
cd ~
git clone https://github.com/your-org/linux-automation.git
cd linux-automation
```

#### Step 2: Set Permissions
```bash
cd /opt/linux-automation  # or ~/linux-automation

# Make all shell scripts executable
find . -name "*.sh" -type f -exec chmod +x {} \;

# Verify permissions
ls -la scripts/administration/
ls -la modules/system/
```

#### Step 3: Create Required Directories
```bash
# Create log directories
sudo mkdir -p /var/log/bash-admin/{daily-reports,security-reports,backup-reports,user-reports,log-reports}

# Create configuration directory
sudo mkdir -p /etc/bash-admin

# Set ownership
sudo chown -R $(whoami):$(whoami) /var/log/bash-admin
sudo chown -R $(whoami):$(whoami) /etc/bash-admin
```

### Method 2: Download Archive

#### Step 1: Download and Extract
```bash
# Download latest release
curl -L https://github.com/your-org/linux-automation/archive/main.zip -o linux-automation.zip

# Extract
unzip linux-automation.zip
mv linux-automation-main /opt/linux-automation
cd /opt/linux-automation

# Set ownership
sudo chown -R $(whoami):$(whoami) /opt/linux-automation
```

#### Step 2: Follow steps 2-3 from Git Clone method

### Method 3: Package Installation (Future)

*Coming soon: RPM and DEB packages for easier installation*

## Post-Installation Configuration

### 1. Basic Configuration

#### Create Configuration File
```bash
cd /opt/linux-automation

# Copy example configuration
cp config/config.json.example config/config.json

# Edit configuration
nano config/config.json
```

#### Minimal Configuration
```json
{
  "notifications": {
    "enabled": true,
    "recipients": {
      "admin": "your-admin@example.com"
    },
    "smtp": {
      "server": "localhost",
      "port": 25
    }
  },
  "logging": {
    "level": "INFO",
    "retention_days": 30
  }
}
```

### 2. Email Configuration

#### For Systems with Local Mail Service
```json
{
  "notifications": {
    "smtp": {
      "server": "localhost",
      "port": 25,
      "auth": false
    }
  }
}
```

#### For External SMTP Services
```json
{
  "notifications": {
    "smtp": {
      "server": "smtp.gmail.com",
      "port": 587,
      "auth": true,
      "username": "your-email@gmail.com",
      "password": "your-app-password",
      "tls": true
    }
  }
}
```

#### Test Email Configuration
```bash
# Source the core library and test
cd /opt/linux-automation
source core/lib/init.sh

# Test email function
send_email "your-email@example.com" "Test Email" "This is a test message from Linux automation system"
```

### 3. Service Configuration

#### Install as Systemd Service (Optional)
```bash
# Create systemd service file
sudo tee /etc/systemd/system/bash-admin-daily.service > /dev/null << EOF
[Unit]
Description=Linux Daily Administration Automation
After=network.target

[Service]
Type=oneshot
User=root
WorkingDirectory=/opt/linux-automation
ExecStart=/opt/linux-automation/scripts/administration/daily_admin_suite.sh --quiet
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create systemd timer
sudo tee /etc/systemd/system/bash-admin-daily.timer > /dev/null << EOF
[Unit]
Description=Run Linux Daily Administration Automation
Requires=bash-admin-daily.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable and start timer
sudo systemctl daemon-reload
sudo systemctl enable bash-admin-daily.timer
sudo systemctl start bash-admin-daily.timer
```

#### Alternative: Cron Setup
```bash
# Add to root's crontab
sudo crontab -e

# Add these lines:
# Daily administration suite at 6:00 AM
0 6 * * * /opt/linux-automation/scripts/administration/daily_admin_suite.sh --quiet

# Security audit twice daily
0 6,18 * * * /opt/linux-automation/scripts/administration/daily_security_audit.sh --quiet

# Log maintenance at midnight
0 0 * * * /opt/linux-automation/scripts/administration/daily_log_maintenance.sh --quiet
```

### 4. Advanced Configuration

#### Backup Configuration
```json
{
  "backup": {
    "paths": ["/home", "/etc", "/var/log", "/opt"],
    "retention_days": 30,
    "verification_enabled": true,
    "storage_paths": ["/backup", "/mnt/backup"]
  }
}
```

#### Security Configuration
```json
{
  "security": {
    "failed_login_threshold": 10,
    "scan_frequency": "daily",
    "compliance_checks": true,
    "vulnerability_scanning": true,
    "firewall_monitoring": true
  }
}
```

#### Logging Configuration
```json
{
  "logging": {
    "level": "INFO",
    "retention_days": 30,
    "max_size_mb": 100,
    "compress_after_days": 7,
    "syslog_enabled": true
  }
}
```

## Verification

### 1. Test Core Functionality
```bash
cd /opt/linux-automation

# Test core library loading
source core/lib/init.sh
echo "Core library loaded successfully"

# Test logging
log_info "Test message"
log_success "Test successful"
```

### 2. Test Individual Scripts
```bash
# Test user management (dry run)
sudo ./scripts/administration/daily_user_tasks.sh --dry-run

# Test backup check (if backups exist)
sudo ./scripts/administration/daily_backup_check.sh --dry-run

# Test security audit
sudo ./scripts/administration/daily_security_audit.sh --quick

# Test log maintenance
sudo ./scripts/administration/daily_log_maintenance.sh --analysis-only
```

### 3. Test Master Suite
```bash
# Test the complete suite (dry run)
sudo ./scripts/administration/daily_admin_suite.sh --dry-run

# Run a quick test
sudo ./scripts/administration/daily_admin_suite.sh --verbose
```

### 4. Check Generated Reports
```bash
# List generated reports
ls -la /var/log/bash-admin/*/

# View a recent report
find /var/log/bash-admin -name "*.html" -mtime -1 | head -1 | xargs cat
```

### 5. Verify Email Notifications
```bash
# Check system mail logs
sudo tail -f /var/log/mail.log

# Test direct email sending
echo "Test message" | mail -s "Test Subject" your-email@example.com
```

## Post-Installation Security

### 1. Secure File Permissions
```bash
cd /opt/linux-automation

# Set restrictive permissions on configuration
chmod 600 config/config.json
sudo chown root:root config/config.json

# Ensure scripts are owned by root
sudo chown -R root:root scripts/
sudo chown -R root:root modules/

# But keep them executable
chmod +x scripts/**/*.sh
chmod +x modules/**/*.sh
```

### 2. Secure Log Directory
```bash
# Set secure permissions on log directory
sudo chmod 750 /var/log/bash-admin
sudo chown root:adm /var/log/bash-admin

# Create logrotate configuration
sudo tee /etc/logrotate.d/bash-admin > /dev/null << EOF
/var/log/bash-admin/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 640 root adm
}
EOF
```

## Troubleshooting Installation

### Common Issues

#### Permission Denied Errors
```bash
# Check file permissions
ls -la scripts/administration/daily_admin_suite.sh

# Fix permissions
find . -name "*.sh" -exec chmod +x {} \;
```

#### Missing Dependencies
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install jq mail-utils logrotate

# CentOS/RHEL
sudo yum install jq mailx logrotate

# Or using dnf
sudo dnf install jq mailx logrotate
```

#### Directory Creation Issues
```bash
# Check if directories exist
ls -la /var/log/bash-admin/

# Recreate if needed
sudo mkdir -p /var/log/bash-admin/{daily-reports,security-reports,backup-reports,user-reports,log-reports}
sudo chown -R $(whoami):$(whoami) /var/log/bash-admin
```

#### Configuration Issues
```bash
# Validate JSON configuration
jq . config/config.json

# Check for common syntax errors
grep -n "," config/config.json | tail -5
```

#### Email Issues
```bash
# Check if mail service is running
systemctl status postfix

# Test local mail delivery
echo "test" | mail -s "test" root

# Check mail logs
sudo tail -f /var/log/mail.log
```

### Getting Help

If you encounter issues during installation:

1. Check the [Troubleshooting Guide](troubleshooting.md)
2. Review system logs: `sudo journalctl -u bash-admin-daily`
3. Enable debug mode: `./script.sh --verbose`
4. Open an issue on GitHub with:
   - OS version (`cat /etc/os-release`)
   - Installation method used
   - Complete error messages
   - Relevant log excerpts

## Next Steps

After successful installation:

1. Review the [Configuration Guide](configuration.md)
2. Check the [Usage Examples](examples.md)
3. Set up monitoring and alerting
4. Schedule regular automation tasks
5. Customize reports and notifications

## Uninstallation

If you need to remove the system:

```bash
# Stop and disable systemd services
sudo systemctl stop bash-admin-daily.timer
sudo systemctl disable bash-admin-daily.timer
sudo rm /etc/systemd/system/bash-admin-daily.*

# Remove cron jobs
sudo crontab -e  # Remove bash-admin entries

# Remove files
sudo rm -rf /opt/linux-automation
sudo rm -rf /var/log/bash-admin
sudo rm -rf /etc/bash-admin

# Remove logrotate configuration
sudo rm /etc/logrotate.d/bash-admin
```