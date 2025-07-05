# Linux Daily Administration Automation

A comprehensive suite of Bash scripts for automating daily administrative tasks on Linux systems. This toolkit provides enterprise-grade automation for user management, backup verification, security auditing, log management, and system maintenance.

## 🚀 Features

- **User Management**: Automated user account verification, failed login monitoring, and password policy enforcement
- **Backup Monitoring**: Backup integrity verification, storage management, and automated restoration testing
- **Security Auditing**: Comprehensive security checks, compliance monitoring, and vulnerability scanning
- **Log Management**: Automated log rotation, analysis, and cleanup with intelligent alerting
- **System Monitoring**: Performance tracking, disk usage monitoring, and health checks
- **HTML Reporting**: Professional reports with email notifications and dashboards
- **Modular Architecture**: Reusable modules for easy extension and customization

## 📋 Prerequisites

- Linux system (Ubuntu 18.04+, CentOS 7+, or similar)
- Bash 4.0 or higher
- Root or sudo privileges for system administration tasks
- Basic system utilities: `grep`, `awk`, `sed`, `find`, `systemctl`

### Optional Dependencies

- `mail` or `sendmail` for email notifications
- `logrotate` for enhanced log management
- `fail2ban` for security monitoring
- `ufw` or `iptables` for firewall management

## 📦 Installation

### Quick Setup

```bash
# Clone the repository
git clone https://github.com/your-org/linux-automation.git
cd linux-automation

# Make scripts executable
chmod +x scripts/**/*.sh
chmod +x modules/**/*.sh

# Create required directories
sudo mkdir -p /var/log/bash-admin/{daily-reports,security-reports,backup-reports,user-reports}

# Initialize configuration
sudo cp config/config.json.example config/config.json
```

### Detailed Installation

1. **Clone and Setup**:
   ```bash
   git clone https://github.com/your-org/linux-automation.git
   cd linux-automation
   ```

2. **Set Permissions**:
   ```bash
   find . -name "*.sh" -exec chmod +x {} \;
   ```

3. **Create Log Directories**:
   ```bash
   sudo mkdir -p /var/log/bash-admin/{daily-reports,security-reports,backup-reports,user-reports,log-reports}
   ```

4. **Configure System**:
   ```bash
   # Copy configuration template
   sudo cp config/config.json.example config/config.json
   
   # Edit configuration for your environment
   sudo nano config/config.json
   ```

## 🗂️ Project Structure

```
linux-automation/
├── README.md                    # This file
├── LICENSE                      # License information
├── docs/                        # Documentation
│   ├── installation.md          # Detailed installation guide
│   ├── configuration.md         # Configuration reference
│   ├── modules.md              # Module documentation
│   ├── troubleshooting.md      # Troubleshooting guide
│   └── examples.md             # Usage examples
├── config/                      # Configuration files
│   ├── config.json.example     # Configuration template
│   └── notifications.conf      # Notification settings
├── core/                        # Core library functions
│   └── lib/
│       ├── init.sh             # Initialization and common functions
│       ├── logging.sh          # Logging utilities
│       ├── config.sh           # Configuration management
│       └── notifications.sh    # Email and alert functions
├── modules/                     # Reusable modules
│   ├── users/
│   │   └── user_management.sh  # User management functions
│   └── system/
│       ├── backup_monitor.sh   # Backup monitoring functions
│       ├── security_audit.sh   # Security audit functions
│       └── log_management.sh   # Log management functions
└── scripts/                     # Executable scripts
    ├── administration/          # Daily administration scripts
    │   ├── daily_admin_suite.sh # Master controller script
    │   ├── daily_user_tasks.sh  # User management automation
    │   ├── daily_backup_check.sh # Backup verification
    │   ├── daily_security_audit.sh # Security auditing
    │   └── daily_log_maintenance.sh # Log management
    └── maintenance/             # System maintenance scripts
        └── log_management.sh    # Advanced log management
```

## 🔧 Configuration

### Basic Configuration

Edit `/path/to/linux-automation/config/config.json`:

```json
{
  "notifications": {
    "enabled": true,
    "recipients": {
      "admin": "admin@example.com",
      "security": "security@example.com",
      "backup": "backup@example.com"
    },
    "smtp": {
      "server": "localhost",
      "port": 25
    }
  },
  "backup": {
    "paths": ["/home", "/etc", "/var/log"],
    "retention_days": 30,
    "verification_enabled": true
  },
  "security": {
    "failed_login_threshold": 10,
    "scan_frequency": "daily",
    "compliance_checks": true
  },
  "logging": {
    "level": "INFO",
    "retention_days": 30,
    "max_size_mb": 100
  }
}
```

## 🎯 Quick Start

### Run Individual Scripts

```bash
# User management tasks
sudo ./scripts/administration/daily_user_tasks.sh

# Backup verification
sudo ./scripts/administration/daily_backup_check.sh

# Security audit
sudo ./scripts/administration/daily_security_audit.sh

# Log maintenance
sudo ./scripts/administration/daily_log_maintenance.sh
```

### Run Complete Daily Suite

```bash
# Run all daily administrative tasks
sudo ./scripts/administration/daily_admin_suite.sh

# Run with verbose output
sudo ./scripts/administration/daily_admin_suite.sh --verbose

# Run only specific task
sudo ./scripts/administration/daily_admin_suite.sh --only backup_check

# Skip specific task
sudo ./scripts/administration/daily_admin_suite.sh --skip security_check
```

## 📊 Reports and Output

All scripts generate comprehensive HTML reports with:

- **Executive Summaries**: High-level status and metrics
- **Detailed Findings**: Specific issues and recommendations
- **Trend Analysis**: Historical data and patterns
- **Action Items**: Prioritized tasks and fixes
- **Email Notifications**: Automated alerts for critical issues

Reports are stored in `/var/log/bash-admin/` with dated filenames for easy tracking.

## 🔄 Automation and Scheduling

### Cron Setup

Add to root's crontab:

```bash
# Daily administration suite at 6:00 AM
0 6 * * * /path/to/linux-automation/scripts/administration/daily_admin_suite.sh --quiet

# Security audit twice daily
0 6,18 * * * /path/to/linux-automation/scripts/administration/daily_security_audit.sh --quiet

# Log maintenance at midnight
0 0 * * * /path/to/linux-automation/scripts/administration/daily_log_maintenance.sh --quiet
```

### Systemd Timer Setup

```bash
# Copy service files
sudo cp systemd/bash-admin-daily.service /etc/systemd/system/
sudo cp systemd/bash-admin-daily.timer /etc/systemd/system/

# Enable and start timer
sudo systemctl enable bash-admin-daily.timer
sudo systemctl start bash-admin-daily.timer
```

## 🔍 Monitoring and Alerting

### Email Notifications

Configure SMTP settings in `config/config.json` to receive:

- Daily summary reports
- Critical security alerts
- Backup failure notifications
- System health warnings

### Log Monitoring

Scripts automatically monitor and alert on:

- Failed login attempts exceeding thresholds
- System errors and critical events
- Disk space issues
- Service failures
- Security policy violations

## 🛠️ Customization

### Adding Custom Modules

1. Create module in `modules/category/your_module.sh`
2. Follow the existing module structure
3. Export functions for use by scripts
4. Add configuration options to `config.json`

### Extending Reports

1. Modify report generation functions in individual scripts
2. Add custom metrics collection
3. Enhance HTML templates
4. Include additional data sources

## 📚 Documentation

- [Installation Guide](docs/installation.md) - Detailed setup instructions
- [Configuration Reference](docs/configuration.md) - Complete configuration options
- [Module Documentation](docs/modules.md) - Function references and examples
- [Troubleshooting Guide](docs/troubleshooting.md) - Common issues and solutions
- [Usage Examples](docs/examples.md) - Real-world usage scenarios

## 🐛 Troubleshooting

### Common Issues

**Permission Denied Errors**:
```bash
chmod +x scripts/**/*.sh
sudo chown -R root:root /var/log/bash-admin/
```

**Email Notifications Not Working**:
- Verify SMTP configuration in `config/config.json`
- Check system mail service: `systemctl status postfix`
- Test mail delivery: `echo "test" | mail -s "test" admin@example.com`

**Scripts Not Finding Modules**:
- Ensure proper directory structure
- Check file permissions
- Verify `source` paths in scripts

### Debug Mode

Run scripts with verbose logging:
```bash
sudo ./scripts/administration/daily_admin_suite.sh --verbose
```

Check log files:
```bash
tail -f /var/log/bash-admin/system.log
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Make changes and test thoroughly
4. Add documentation for new features
5. Submit a pull request

### Development Guidelines

- Follow existing code style and patterns
- Add comprehensive error handling
- Include logging for all operations
- Write clear documentation
- Test on multiple Linux distributions

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Linux system administration community
- Bash scripting best practices
- Security automation frameworks
- Open source monitoring tools

## 📞 Support

- **Issues**: Report bugs and feature requests on GitHub Issues
- **Documentation**: Check the `docs/` directory for detailed guides
- **Community**: Join discussions in GitHub Discussions

---

**Note**: This automation suite is designed for system administrators familiar with Linux environments. Always test scripts in a development environment before deploying to production systems.