# Configuration Reference

This document provides comprehensive documentation for configuring the Linux Daily Administration Automation system.

## Table of Contents

- [Configuration Overview](#configuration-overview)
- [Configuration File Structure](#configuration-file-structure)
- [Core Configuration](#core-configuration)
- [Module Configuration](#module-configuration)
- [Environment Variables](#environment-variables)
- [Advanced Configuration](#advanced-configuration)
- [Validation and Testing](#validation-and-testing)

## Configuration Overview

The automation system uses a hierarchical JSON-based configuration system that allows for:

- **Environment-specific settings**: Different configurations for development, staging, and production
- **Module-specific configuration**: Granular control over individual modules
- **Override mechanisms**: Environment variables can override file-based settings
- **Validation**: Built-in configuration validation and error checking

### Configuration File Locations

The system looks for configuration files in this order:

1. `./config/config.json` (local configuration)
2. `/etc/bash-admin/config.json` (system-wide configuration)
3. `./config/config.json.example` (default template)

### Configuration Hierarchy

```
Configuration Priority (highest to lowest):
1. Environment Variables (BASH_ADMIN_*)
2. Local config file (./config/config.json)
3. System config file (/etc/bash-admin/config.json)
4. Default values in scripts
```

## Configuration File Structure

### Basic Structure

```json
{
  "system": {
    "hostname": "auto-detect",
    "timezone": "UTC",
    "environment": "production"
  },
  "logging": {
    "level": "INFO",
    "retention_days": 30,
    "max_size_mb": 100,
    "destinations": ["file", "syslog"]
  },
  "notifications": {
    "enabled": true,
    "smtp": {
      "server": "localhost",
      "port": 25
    },
    "recipients": {
      "admin": "admin@example.com"
    }
  },
  "modules": {
    "user_management": {},
    "backup_monitor": {},
    "security_audit": {},
    "log_management": {}
  }
}
```

### Complete Configuration Template

```json
{
  "system": {
    "hostname": "auto-detect",
    "timezone": "UTC",
    "environment": "production",
    "data_directory": "/var/log/bash-admin",
    "temp_directory": "/tmp/bash-admin",
    "lock_directory": "/var/run/bash-admin"
  },
  "logging": {
    "level": "INFO",
    "retention_days": 30,
    "max_size_mb": 100,
    "compress_after_days": 7,
    "destinations": ["file", "syslog"],
    "file_path": "/var/log/bash-admin/system.log",
    "syslog_facility": "local0",
    "include_timestamps": true,
    "include_hostname": true,
    "color_output": true
  },
  "notifications": {
    "enabled": true,
    "default_priority": "normal",
    "rate_limiting": {
      "enabled": true,
      "max_per_hour": 10
    },
    "smtp": {
      "server": "smtp.example.com",
      "port": 587,
      "security": "tls",
      "auth": {
        "enabled": false,
        "username": "",
        "password": ""
      },
      "timeout": 30,
      "from_address": "bash-admin@example.com",
      "from_name": "Linux Automation System"
    },
    "recipients": {
      "admin": "admin@example.com",
      "security": "security@example.com",
      "backup": "backup@example.com",
      "operations": "ops@example.com"
    },
    "templates": {
      "daily_summary": {
        "subject": "Daily Administration Summary - {{hostname}}",
        "priority": "normal"
      },
      "security_alert": {
        "subject": "🔴 Security Alert - {{hostname}}",
        "priority": "high"
      },
      "backup_failure": {
        "subject": "⚠️ Backup Failure - {{hostname}}",
        "priority": "high"
      }
    }
  },
  "modules": {
    "user_management": {
      "enabled": true,
      "check_frequency": "daily",
      "failed_login_threshold": 10,
      "inactive_user_days": 90,
      "password_policy": {
        "min_length": 8,
        "require_complexity": true,
        "max_age_days": 90
      },
      "excluded_users": ["root", "daemon", "bin", "sys"],
      "report_empty_passwords": true,
      "report_duplicate_uids": true
    },
    "backup_monitor": {
      "enabled": true,
      "check_frequency": "daily",
      "backup_paths": [
        "/backup/daily",
        "/backup/weekly",
        "/mnt/backup"
      ],
      "retention_days": 30,
      "verification_enabled": true,
      "integrity_checks": {
        "checksum_validation": true,
        "restore_testing": false,
        "size_validation": true
      },
      "storage_thresholds": {
        "warning_percent": 80,
        "critical_percent": 90
      },
      "notification_on_failure": true,
      "backup_jobs": {
        "system_config": {
          "path": "/etc",
          "schedule": "daily",
          "retention": "30d"
        },
        "user_data": {
          "path": "/home",
          "schedule": "daily",
          "retention": "30d"
        }
      }
    },
    "security_audit": {
      "enabled": true,
      "check_frequency": "daily",
      "compliance_frameworks": ["cis", "nist"],
      "vulnerability_scanning": {
        "enabled": true,
        "update_sources": true,
        "severity_threshold": "medium"
      },
      "file_permissions": {
        "check_world_writable": true,
        "check_suid_sgid": true,
        "critical_files": [
          "/etc/passwd",
          "/etc/shadow",
          "/etc/sudoers"
        ]
      },
      "network_security": {
        "check_open_ports": true,
        "allowed_services": ["ssh", "http", "https"],
        "firewall_validation": true
      },
      "process_monitoring": {
        "check_suspicious_processes": true,
        "root_process_threshold": 100,
        "unknown_process_alert": true
      },
      "security_services": {
        "required": ["ssh", "ufw"],
        "recommended": ["fail2ban", "clamav-daemon"]
      },
      "thresholds": {
        "failed_login_limit": 10,
        "security_score_minimum": 70
      }
    },
    "log_management": {
      "enabled": true,
      "analysis_frequency": "daily",
      "rotation_enabled": true,
      "retention_days": 30,
      "compression": {
        "enabled": true,
        "after_days": 7,
        "algorithm": "gzip"
      },
      "analysis": {
        "error_patterns": [
          "ERROR",
          "CRITICAL",
          "FATAL",
          "panic",
          "segfault"
        ],
        "warning_patterns": [
          "WARNING",
          "WARN",
          "deprecated"
        ],
        "security_patterns": [
          "Failed password",
          "Invalid user",
          "authentication failure"
        ]
      },
      "log_sources": {
        "system": [
          "/var/log/syslog",
          "/var/log/messages",
          "/var/log/auth.log",
          "/var/log/secure"
        ],
        "applications": [
          "/var/log/apache2/*.log",
          "/var/log/nginx/*.log",
          "/var/log/mysql/*.log"
        ]
      },
      "thresholds": {
        "error_count_daily": 50,
        "warning_count_daily": 100,
        "file_size_warning_mb": 100,
        "file_size_critical_mb": 500
      }
    }
  },
  "scheduling": {
    "daily_suite": {
      "enabled": true,
      "time": "06:00",
      "timeout_minutes": 30
    },
    "security_audit": {
      "enabled": true,
      "frequency": "twice_daily",
      "times": ["06:00", "18:00"]
    },
    "log_maintenance": {
      "enabled": true,
      "time": "00:00",
      "frequency": "daily"
    }
  },
  "performance": {
    "max_concurrent_jobs": 4,
    "job_timeout_minutes": 30,
    "memory_limit_mb": 512,
    "temp_file_cleanup": true
  },
  "security": {
    "privilege_escalation": "sudo",
    "file_permissions": {
      "config_files": "600",
      "log_files": "640",
      "script_files": "755"
    },
    "secure_temp_files": true,
    "audit_commands": true
  }
}
```

## Core Configuration

### System Configuration

```json
{
  "system": {
    "hostname": "auto-detect",     // Auto-detect or override hostname
    "timezone": "UTC",             // System timezone for reports
    "environment": "production",   // Environment identifier
    "data_directory": "/var/log/bash-admin",
    "temp_directory": "/tmp/bash-admin",
    "lock_directory": "/var/run/bash-admin"
  }
}
```

**Options**:
- `hostname`: System hostname (default: auto-detected)
- `timezone`: Timezone for timestamps (default: "UTC")
- `environment`: Environment identifier ("development", "staging", "production")
- `data_directory`: Base directory for logs and reports
- `temp_directory`: Directory for temporary files
- `lock_directory`: Directory for lock files

### Logging Configuration

```json
{
  "logging": {
    "level": "INFO",                    // Log level
    "retention_days": 30,               // Log retention period
    "max_size_mb": 100,                 // Maximum log file size
    "compress_after_days": 7,           // Compress logs after N days
    "destinations": ["file", "syslog"], // Log destinations
    "file_path": "/var/log/bash-admin/system.log",
    "syslog_facility": "local0",        // Syslog facility
    "include_timestamps": true,         // Include timestamps
    "include_hostname": true,           // Include hostname
    "color_output": true                // Colored console output
  }
}
```

**Log Levels**: `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL`

**Destinations**:
- `file`: Write to log file
- `syslog`: Send to system logger
- `console`: Output to console (automatic for interactive sessions)

### Notification Configuration

```json
{
  "notifications": {
    "enabled": true,
    "default_priority": "normal",
    "rate_limiting": {
      "enabled": true,
      "max_per_hour": 10
    },
    "smtp": {
      "server": "smtp.example.com",
      "port": 587,
      "security": "tls",              // none, tls, ssl
      "auth": {
        "enabled": false,
        "username": "",
        "password": ""
      },
      "timeout": 30,
      "from_address": "bash-admin@example.com",
      "from_name": "Linux Automation System"
    },
    "recipients": {
      "admin": "admin@example.com",
      "security": "security@example.com",
      "backup": "backup@example.com"
    }
  }
}
```

**SMTP Security Options**:
- `none`: No encryption
- `tls`: STARTTLS encryption
- `ssl`: SSL/TLS encryption

**Priority Levels**: `low`, `normal`, `high`, `critical`

## Module Configuration

### User Management Module

```json
{
  "modules": {
    "user_management": {
      "enabled": true,
      "check_frequency": "daily",
      "failed_login_threshold": 10,
      "inactive_user_days": 90,
      "password_policy": {
        "min_length": 8,
        "require_complexity": true,
        "max_age_days": 90
      },
      "excluded_users": ["root", "daemon", "bin", "sys"],
      "report_empty_passwords": true,
      "report_duplicate_uids": true,
      "cleanup_inactive_users": false
    }
  }
}
```

### Backup Monitor Module

```json
{
  "modules": {
    "backup_monitor": {
      "enabled": true,
      "backup_paths": ["/backup/daily", "/mnt/backup"],
      "retention_days": 30,
      "verification_enabled": true,
      "integrity_checks": {
        "checksum_validation": true,
        "restore_testing": false,
        "size_validation": true
      },
      "storage_thresholds": {
        "warning_percent": 80,
        "critical_percent": 90
      },
      "backup_jobs": {
        "system_config": {
          "path": "/etc",
          "schedule": "daily",
          "retention": "30d"
        }
      }
    }
  }
}
```

### Security Audit Module

```json
{
  "modules": {
    "security_audit": {
      "enabled": true,
      "compliance_frameworks": ["cis", "nist"],
      "vulnerability_scanning": {
        "enabled": true,
        "severity_threshold": "medium"
      },
      "file_permissions": {
        "check_world_writable": true,
        "check_suid_sgid": true
      },
      "network_security": {
        "check_open_ports": true,
        "firewall_validation": true
      },
      "thresholds": {
        "security_score_minimum": 70
      }
    }
  }
}
```

### Log Management Module

```json
{
  "modules": {
    "log_management": {
      "enabled": true,
      "retention_days": 30,
      "compression": {
        "enabled": true,
        "after_days": 7
      },
      "analysis": {
        "error_patterns": ["ERROR", "CRITICAL", "FATAL"],
        "security_patterns": ["Failed password", "Invalid user"]
      },
      "thresholds": {
        "error_count_daily": 50,
        "file_size_warning_mb": 100
      }
    }
  }
}
```

## Environment Variables

Environment variables can override configuration file settings:

### Core Environment Variables

```bash
# System configuration
export BASH_ADMIN_HOSTNAME="custom-hostname"
export BASH_ADMIN_ENVIRONMENT="development"
export BASH_ADMIN_DATA_DIR="/custom/data/path"

# Logging configuration
export BASH_ADMIN_LOG_LEVEL="DEBUG"
export BASH_ADMIN_LOG_FILE="/custom/log/path.log"
export BASH_ADMIN_LOG_RETENTION_DAYS="60"

# Notification configuration
export BASH_ADMIN_NOTIFICATIONS_ENABLED="true"
export BASH_ADMIN_SMTP_SERVER="mail.example.com"
export BASH_ADMIN_SMTP_PORT="587"
export BASH_ADMIN_SMTP_USERNAME="user@example.com"
export BASH_ADMIN_SMTP_PASSWORD="secure_password"
export BASH_ADMIN_ADMIN_EMAIL="admin@example.com"

# Module configuration
export BASH_ADMIN_USER_MGMT_ENABLED="true"
export BASH_ADMIN_BACKUP_MONITOR_ENABLED="true"
export BASH_ADMIN_SECURITY_AUDIT_ENABLED="true"
export BASH_ADMIN_LOG_MGMT_ENABLED="true"
```

### Module-Specific Environment Variables

```bash
# User management
export BASH_ADMIN_FAILED_LOGIN_THRESHOLD="20"
export BASH_ADMIN_INACTIVE_USER_DAYS="120"

# Backup monitoring
export BASH_ADMIN_BACKUP_PATHS="/backup:/mnt/backup"
export BASH_ADMIN_BACKUP_RETENTION_DAYS="45"

# Security audit
export BASH_ADMIN_SECURITY_SCORE_MIN="80"
export BASH_ADMIN_VULN_SCAN_ENABLED="true"

# Log management
export BASH_ADMIN_LOG_RETENTION_DAYS="45"
export BASH_ADMIN_LOG_COMPRESS_DAYS="14"
```

## Advanced Configuration

### Multi-Environment Setup

#### Development Environment
```json
{
  "system": {
    "environment": "development",
    "data_directory": "/tmp/bash-admin-dev"
  },
  "logging": {
    "level": "DEBUG",
    "destinations": ["file", "console"]
  },
  "notifications": {
    "enabled": false
  },
  "modules": {
    "security_audit": {
      "vulnerability_scanning": {
        "enabled": false
      }
    }
  }
}
```

#### Production Environment
```json
{
  "system": {
    "environment": "production",
    "data_directory": "/var/log/bash-admin"
  },
  "logging": {
    "level": "INFO",
    "destinations": ["file", "syslog"]
  },
  "notifications": {
    "enabled": true,
    "rate_limiting": {
      "enabled": true,
      "max_per_hour": 5
    }
  },
  "performance": {
    "max_concurrent_jobs": 2,
    "job_timeout_minutes": 60
  }
}
```

### Custom Notification Templates

```json
{
  "notifications": {
    "templates": {
      "custom_alert": {
        "subject": "🚨 {{alert_type}} - {{hostname}}",
        "body_template": "templates/custom_alert.html",
        "priority": "high",
        "recipients": ["security", "operations"]
      },
      "weekly_summary": {
        "subject": "📊 Weekly Summary - {{hostname}}",
        "body_template": "templates/weekly_summary.html",
        "priority": "normal",
        "recipients": ["admin"]
      }
    }
  }
}
```

### Performance Tuning

```json
{
  "performance": {
    "max_concurrent_jobs": 4,        // Maximum parallel tasks
    "job_timeout_minutes": 30,       // Task timeout
    "memory_limit_mb": 512,          // Memory limit per task
    "temp_file_cleanup": true,       // Auto-cleanup temp files
    "cache_enabled": true,           // Enable result caching
    "cache_ttl_minutes": 60,         // Cache time-to-live
    "parallel_processing": {
      "enabled": true,
      "max_workers": 4
    }
  }
}
```

### Security Hardening

```json
{
  "security": {
    "privilege_escalation": "sudo",   // none, sudo, su
    "file_permissions": {
      "config_files": "600",
      "log_files": "640",
      "script_files": "755"
    },
    "secure_temp_files": true,        // Use secure temp files
    "audit_commands": true,           // Log all commands
    "encrypt_sensitive_data": true,   // Encrypt passwords in config
    "allowed_users": ["root", "admin"],
    "allowed_groups": ["wheel", "admin"]
  }
}
```

## Validation and Testing

### Configuration Validation

```bash
# Validate configuration syntax
./scripts/administration/validate_config.sh

# Test specific module configuration
./scripts/administration/validate_config.sh --module user_management

# Validate and show effective configuration
./scripts/administration/validate_config.sh --show-effective
```

### Testing Configuration Changes

```bash
# Test configuration without making changes
./scripts/administration/daily_admin_suite.sh --dry-run --verbose

# Test specific module with new configuration
./scripts/administration/daily_user_tasks.sh --test-config

# Validate email configuration
./scripts/administration/test_notifications.sh
```

### Configuration Debugging

```bash
# Show effective configuration
./scripts/administration/show_config.sh

# Show configuration source (file vs environment)
./scripts/administration/show_config.sh --show-sources

# Debug configuration loading
BASH_ADMIN_LOG_LEVEL=DEBUG ./scripts/administration/daily_admin_suite.sh --verbose
```

### Common Configuration Issues

#### Invalid JSON Syntax
```bash
# Validate JSON syntax
jq . config/config.json

# Common syntax errors:
# - Missing commas
# - Trailing commas
# - Unquoted keys
# - Missing quotes around strings
```

#### Missing Required Settings
```bash
# Check for required configuration keys
./scripts/administration/validate_config.sh --check-required

# Required keys:
# - notifications.recipients.admin
# - logging.level
# - system.data_directory
```

#### Permission Issues
```bash
# Check file permissions
ls -la config/config.json

# Fix permissions
chmod 600 config/config.json
chown root:root config/config.json
```

### Configuration Best Practices

1. **Use version control** for configuration files
2. **Validate syntax** before deploying changes
3. **Test in development** environment first
4. **Use environment variables** for sensitive data
5. **Document custom settings** and their purposes
6. **Regular backups** of configuration files
7. **Monitor configuration** for unauthorized changes

This configuration system provides the flexibility needed for diverse environments while maintaining security and operational simplicity.