# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the Linux Daily Administration Automation system.

## Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Common Issues](#common-issues)
- [Module-Specific Issues](#module-specific-issues)
- [Performance Issues](#performance-issues)
- [Debugging Tools](#debugging-tools)
- [FAQ](#faq)
- [Getting Help](#getting-help)

## Quick Diagnostics

### System Health Check

Run this quick diagnostic to identify common issues:

```bash
#!/bin/bash
# quick_diagnostics.sh - Quick system health check

echo "Linux Automation System Diagnostics"
echo "===================================="
echo "Date: $(date)"
echo "Host: $(hostname)"
echo

# Check if scripts are executable
echo "1. Script Permissions:"
if [[ -x "./scripts/administration/daily_admin_suite.sh" ]]; then
    echo "   ✓ Scripts are executable"
else
    echo "   ✗ Scripts are not executable"
    echo "   Fix: chmod +x scripts/**/*.sh"
fi

# Check required directories
echo "2. Required Directories:"
required_dirs=("/var/log/bash-admin" "/var/log/bash-admin/daily-reports")
for dir in "${required_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        echo "   ✓ $dir exists"
    else
        echo "   ✗ $dir missing"
        echo "   Fix: sudo mkdir -p $dir"
    fi
done

# Check configuration
echo "3. Configuration:"
if [[ -f "config/config.json" ]]; then
    if jq . config/config.json >/dev/null 2>&1; then
        echo "   ✓ Configuration file is valid JSON"
    else
        echo "   ✗ Configuration file has invalid JSON syntax"
        echo "   Fix: Validate with 'jq . config/config.json'"
    fi
else
    echo "   ⚠ Configuration file not found (will use defaults)"
    echo "   Suggestion: cp config/config.json.example config/config.json"
fi

# Check core dependencies
echo "4. Dependencies:"
deps=("bash" "grep" "awk" "sed" "find" "systemctl")
for dep in "${deps[@]}"; do
    if command -v "$dep" >/dev/null; then
        echo "   ✓ $dep available"
    else
        echo "   ✗ $dep missing"
    fi
done

# Check privileges
echo "5. Privileges:"
if [[ $EUID -eq 0 ]]; then
    echo "   ✓ Running as root"
elif sudo -n true 2>/dev/null; then
    echo "   ✓ Sudo access available"
else
    echo "   ✗ No root or sudo access"
    echo "   Fix: Run with sudo or as root"
fi

# Check disk space
echo "6. Disk Space:"
log_usage=$(df /var/log | awk 'NR==2 {print int($5)}')
if [[ $log_usage -lt 90 ]]; then
    echo "   ✓ Log partition usage: ${log_usage}%"
else
    echo "   ⚠ High log partition usage: ${log_usage}%"
fi

echo
echo "Diagnostics complete. Check items marked with ✗ or ⚠"
```

### Log Analysis

Check recent logs for errors:

```bash
# Check system logs for automation errors
sudo grep -i "bash-admin\|automation" /var/log/syslog | tail -20

# Check automation system logs
if [[ -f "/var/log/bash-admin/system.log" ]]; then
    tail -50 /var/log/bash-admin/system.log
fi

# Check for permission denied errors
sudo grep -i "permission denied" /var/log/syslog | grep -i bash | tail -10
```

## Common Issues

### 1. Permission Denied Errors

#### Symptoms
- Scripts fail with "Permission denied" errors
- Cannot write to log directories
- Cannot access configuration files

#### Diagnosis
```bash
# Check script permissions
ls -la scripts/administration/daily_admin_suite.sh

# Check log directory permissions
ls -ld /var/log/bash-admin/

# Check who owns the files
find . -name "*.sh" -exec ls -la {} \; | head -5
```

#### Solutions

**Fix script permissions:**
```bash
# Make all scripts executable
find . -name "*.sh" -exec chmod +x {} \;

# Set proper ownership (if running as root)
sudo chown -R root:root scripts/ modules/
```

**Fix directory permissions:**
```bash
# Create missing directories
sudo mkdir -p /var/log/bash-admin/{daily-reports,security-reports,backup-reports,user-reports,log-reports}

# Set proper ownership
sudo chown -R $(whoami):$(whoami) /var/log/bash-admin/

# Or for system-wide installation
sudo chown -R root:adm /var/log/bash-admin/
sudo chmod -R 755 /var/log/bash-admin/
```

**Fix configuration file permissions:**
```bash
# Secure configuration file
chmod 600 config/config.json
sudo chown root:root config/config.json
```

### 2. Scripts Not Found or Module Loading Errors

#### Symptoms
- "No such file or directory" errors
- "command not found" errors
- Module functions not available

#### Diagnosis
```bash
# Check if files exist
ls -la scripts/administration/
ls -la modules/system/
ls -la core/lib/

# Check current working directory
pwd

# Test module loading
source core/lib/init.sh
echo $?
```

#### Solutions

**Fix path issues:**
```bash
# Ensure you're in the correct directory
cd /path/to/linux-automation

# Use absolute paths in cron jobs
0 6 * * * /opt/linux-automation/scripts/administration/daily_admin_suite.sh
```

**Fix missing files:**
```bash
# Re-clone repository if files are missing
git status
git checkout .

# Or re-download and extract
```

### 3. Email Notifications Not Working

#### Symptoms
- Scripts run successfully but no emails received
- SMTP connection errors in logs
- "mail command not found" errors

#### Diagnosis
```bash
# Check if mail command exists
which mail

# Test local mail delivery
echo "test" | mail -s "test" $(whoami)

# Check mail logs
sudo tail -f /var/log/mail.log

# Test SMTP connectivity
telnet smtp.example.com 587
```

#### Solutions

**Install mail utilities:**
```bash
# Ubuntu/Debian
sudo apt-get install mailutils

# CentOS/RHEL
sudo yum install mailx
# or
sudo dnf install mailx
```

**Configure local mail service:**
```bash
# Install and configure Postfix
sudo apt-get install postfix

# Basic Postfix configuration
sudo dpkg-reconfigure postfix
```

**Fix SMTP configuration:**
```json
{
  "notifications": {
    "smtp": {
      "server": "smtp.gmail.com",
      "port": 587,
      "security": "tls",
      "auth": {
        "enabled": true,
        "username": "your-email@gmail.com",
        "password": "your-app-password"
      }
    }
  }
}
```

**Test email configuration:**
```bash
# Test with core library
source core/lib/init.sh
send_email "your-email@example.com" "Test" "This is a test"
```

### 4. Configuration Issues

#### Symptoms
- Scripts use default values instead of configured values
- JSON parsing errors
- Configuration not found errors

#### Diagnosis
```bash
# Validate JSON syntax
jq . config/config.json

# Check configuration loading
source core/lib/init.sh
get_config "notifications.recipients.admin"

# Show effective configuration
./scripts/administration/show_config.sh
```

#### Solutions

**Fix JSON syntax errors:**
```bash
# Common JSON issues and fixes:

# Missing comma
{
  "key1": "value1"    # Missing comma here
  "key2": "value2"
}

# Trailing comma (not allowed in JSON)
{
  "key1": "value1",
  "key2": "value2",   # Remove this comma
}

# Unquoted keys
{
  key1: "value1"      # Should be "key1"
}

# Use jq to validate and format
jq . config/config.json > config/config.json.tmp
mv config/config.json.tmp config/config.json
```

**Create missing configuration:**
```bash
# Copy example configuration
cp config/config.json.example config/config.json

# Edit with your settings
nano config/config.json
```

### 5. High System Load or Performance Issues

#### Symptoms
- Scripts run slowly or timeout
- High CPU or memory usage
- System becomes unresponsive during execution

#### Diagnosis
```bash
# Check system load during execution
top -p $(pgrep -f bash-admin)

# Check memory usage
ps aux | grep bash-admin

# Check for concurrent processes
pgrep -f "daily_admin\|bash-admin" | wc -l
```

#### Solutions

**Reduce concurrent jobs:**
```json
{
  "performance": {
    "max_concurrent_jobs": 2,
    "job_timeout_minutes": 60
  }
}
```

**Optimize execution:**
```bash
# Run with lower priority
nice -n 10 ./scripts/administration/daily_admin_suite.sh

# Run only specific modules
./scripts/administration/daily_admin_suite.sh --only backup_check

# Use quiet mode to reduce output
./scripts/administration/daily_admin_suite.sh --quiet
```

## Module-Specific Issues

### User Management Module

#### Common Issues
- Cannot read /etc/shadow
- User enumeration takes too long
- False positives in security checks

#### Solutions
```bash
# Ensure proper privileges for shadow file access
sudo -u root ./scripts/administration/daily_user_tasks.sh

# Exclude system users from checks
{
  "modules": {
    "user_management": {
      "excluded_users": ["root", "daemon", "bin", "sys", "nobody"]
    }
  }
}

# Reduce failed login threshold
{
  "modules": {
    "user_management": {
      "failed_login_threshold": 20
    }
  }
}
```

### Backup Monitor Module

#### Common Issues
- Backup directories not accessible
- Large backup files cause timeouts
- Storage calculations incorrect

#### Solutions
```bash
# Ensure backup directories exist and are accessible
sudo ls -la /backup/

# Configure appropriate backup paths
{
  "modules": {
    "backup_monitor": {
      "backup_paths": ["/backup", "/mnt/backup"],
      "verification_enabled": false  // Disable for large backups
    }
  }
}

# Increase timeout for large backup verification
{
  "performance": {
    "job_timeout_minutes": 120
  }
}
```

### Security Audit Module

#### Common Issues
- Vulnerability scanning takes too long
- False security alerts
- Cannot access security configuration files

#### Solutions
```bash
# Use quick mode for routine checks
./scripts/administration/daily_security_audit.sh --quick

# Disable vulnerability scanning in configuration
{
  "modules": {
    "security_audit": {
      "vulnerability_scanning": {
        "enabled": false
      }
    }
  }
}

# Adjust security score threshold
{
  "modules": {
    "security_audit": {
      "thresholds": {
        "security_score_minimum": 60
      }
    }
  }
}
```

### Log Management Module

#### Common Issues
- Log rotation fails
- Cannot compress large log files
- Log analysis is slow

#### Solutions
```bash
# Ensure logrotate is installed and configured
sudo apt-get install logrotate

# Use system logrotate instead of manual rotation
{
  "modules": {
    "log_management": {
      "rotation_enabled": false  // Let system handle rotation
    }
  }
}

# Reduce analysis scope
{
  "modules": {
    "log_management": {
      "analysis": {
        "days_back": 1  // Analyze only recent logs
      }
    }
  }
}
```

## Performance Issues

### Slow Execution

#### Diagnosis
```bash
# Time individual components
time ./scripts/administration/daily_user_tasks.sh
time ./scripts/administration/daily_security_audit.sh

# Monitor resource usage
htop

# Check I/O wait
iostat -x 1
```

#### Solutions
```bash
# Run with lower I/O priority
ionice -c 3 ./scripts/administration/daily_admin_suite.sh

# Schedule during low-usage hours
0 3 * * * /opt/linux-automation/scripts/administration/daily_admin_suite.sh

# Use SSD storage for temporary files
{
  "system": {
    "temp_directory": "/tmp/bash-admin"  // Use tmpfs if available
  }
}
```

### Memory Issues

#### Diagnosis
```bash
# Check memory usage during execution
watch -n 1 'ps aux | grep bash-admin | head -10'

# Check for memory leaks
valgrind --tool=memcheck ./scripts/administration/daily_user_tasks.sh
```

#### Solutions
```bash
# Reduce memory usage
{
  "performance": {
    "memory_limit_mb": 256,
    "temp_file_cleanup": true
  }
}

# Process files in chunks
{
  "modules": {
    "log_management": {
      "analysis": {
        "chunk_size_mb": 10
      }
    }
  }
}
```

## Debugging Tools

### Enable Debug Mode

```bash
# Enable debug logging
export BASH_ADMIN_LOG_LEVEL=DEBUG

# Run with verbose output
./scripts/administration/daily_admin_suite.sh --verbose

# Enable bash debugging
bash -x ./scripts/administration/daily_admin_suite.sh
```

### Configuration Debugging

```bash
# Show effective configuration
source core/lib/init.sh
get_config "notifications.smtp.server" "default-value"

# Show all configuration sources
./scripts/administration/show_config.sh --show-sources

# Validate configuration
./scripts/administration/validate_config.sh --verbose
```

### Network Debugging

```bash
# Test SMTP connectivity
telnet smtp.example.com 587

# Test with openssl for TLS
openssl s_client -connect smtp.gmail.com:587 -starttls smtp

# Monitor network traffic
sudo tcpdump -i any port 587
```

### Process Debugging

```bash
# Monitor process execution
strace -f ./scripts/administration/daily_user_tasks.sh

# Check file access
lsof +p $(pgrep -f bash-admin)

# Monitor system calls
sudo sysdig proc.name contains bash-admin
```

## FAQ

### Q: Why are scripts not running automatically?

**A:** Check cron configuration and permissions:
```bash
# Check if cron is running
systemctl status cron

# Check crontab entries
sudo crontab -l

# Check cron logs
grep CRON /var/log/syslog | tail -10

# Ensure scripts use absolute paths
0 6 * * * /opt/linux-automation/scripts/administration/daily_admin_suite.sh
```

### Q: How do I reduce the frequency of email notifications?

**A:** Configure rate limiting in notifications:
```json
{
  "notifications": {
    "rate_limiting": {
      "enabled": true,
      "max_per_hour": 5
    }
  }
}
```

### Q: Can I run scripts without root privileges?

**A:** Some functions require root access, but you can:
```bash
# Run with limited functionality
./scripts/administration/daily_admin_suite.sh --user-mode

# Use sudo for specific operations
{
  "security": {
    "privilege_escalation": "sudo"
  }
}
```

### Q: How do I backup the automation system configuration?

**A:** Regular backup of configuration and logs:
```bash
# Create backup script
#!/bin/bash
backup_dir="/backup/bash-admin/$(date +%Y%m%d)"
mkdir -p "$backup_dir"

# Backup configuration
cp -r config/ "$backup_dir/"

# Backup recent reports
find /var/log/bash-admin -name "*.html" -mtime -7 -exec cp {} "$backup_dir/" \;

# Backup scripts (if customized)
tar -czf "$backup_dir/scripts.tar.gz" scripts/ modules/
```

### Q: How do I migrate to a new server?

**A:** Migration checklist:
```bash
# 1. Backup current installation
tar -czf bash-admin-backup.tar.gz /opt/linux-automation /var/log/bash-admin

# 2. Install on new server
# Follow installation guide

# 3. Restore configuration
cp old-server/config/config.json new-server/config/

# 4. Update server-specific settings
# Edit config.json for new hostname, paths, etc.

# 5. Test functionality
./scripts/administration/daily_admin_suite.sh --dry-run
```

### Q: How do I customize report templates?

**A:** Create custom HTML templates:
```bash
# Create template directory
mkdir -p templates/

# Copy default template and modify
cp scripts/administration/daily_admin_suite.sh templates/custom_report.html

# Update configuration to use custom template
{
  "notifications": {
    "templates": {
      "daily_summary": {
        "body_template": "templates/custom_report.html"
      }
    }
  }
}
```

## Getting Help

### Before Seeking Help

1. **Run diagnostics**: Use the quick diagnostics script above
2. **Check logs**: Review system and application logs
3. **Verify configuration**: Ensure JSON syntax is valid
4. **Test permissions**: Confirm proper file and directory permissions
5. **Review documentation**: Check relevant sections in docs/

### Gathering Information

When reporting issues, include:

```bash
# System information
uname -a
cat /etc/os-release

# Script version/commit
git log -1 --oneline

# Configuration (without sensitive data)
jq 'del(.notifications.smtp.auth)' config/config.json

# Error messages (with context)
./scripts/administration/daily_admin_suite.sh --verbose 2>&1 | tail -50

# System resources
free -h
df -h
uptime
```

### Support Channels

1. **GitHub Issues**: For bugs and feature requests
2. **Documentation**: Check docs/ directory for detailed guides
3. **Community Forums**: Join discussions about best practices
4. **Email Support**: For enterprise installations

### Contributing Fixes

If you solve an issue:

1. Document the problem and solution
2. Submit a pull request with the fix
3. Update relevant documentation
4. Add tests if applicable

This troubleshooting guide should help resolve most common issues. For persistent problems, don't hesitate to seek help through the appropriate channels.