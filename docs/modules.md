# Module Documentation

This document provides comprehensive documentation for all modules in the Linux automation system. Each module is designed to be reusable and provides specific functionality for system administration tasks.

## Table of Contents

- [Core Libraries](#core-libraries)
- [User Management Module](#user-management-module)
- [System Modules](#system-modules)
  - [Backup Monitor](#backup-monitor)
  - [Security Audit](#security-audit)
  - [Log Management](#log-management)

## Core Libraries

### init.sh

The core initialization library that provides fundamental functions for all scripts.

**Location**: `core/lib/init.sh`

**Key Functions**:

```bash
# Logging functions
log_info(message, category)      # Log informational message
log_warn(message, category)      # Log warning message
log_error(message, category)     # Log error message
log_success(message, category)   # Log success message
log_debug(message, category)     # Log debug message

# Configuration functions
get_config(key, default)         # Get configuration value
set_config(key, value)           # Set configuration value
has_config(key)                  # Check if configuration key exists

# Privilege functions
require_root()                   # Require root privileges
check_privileges()               # Check current privileges

# Notification functions
send_notification(recipient, subject, message)  # Send notification
send_email(recipient, subject, body, attachment) # Send email
```

**Usage Example**:
```bash
#!/bin/bash
source "$(dirname "$0")/../../core/lib/init.sh"

log_info "Starting script execution"
require_root
local config_value=$(get_config "key.subkey" "default_value")
send_notification "admin@example.com" "Test" "Script completed"
```

## User Management Module

### user_management.sh

Provides comprehensive user account management and monitoring functions.

**Location**: `modules/users/user_management.sh`

#### Functions

##### check_user_accounts()
**Purpose**: Analyzes user accounts for security issues and compliance.

**Parameters**: 
- `$1` - Report file path (optional)

**Returns**: Number of issues found

**Example**:
```bash
source "modules/users/user_management.sh"
issues=$(check_user_accounts "/tmp/user_report.txt")
echo "Found $issues user account issues"
```

**Checks Performed**:
- Accounts without passwords
- Accounts with weak passwords
- Inactive accounts that should be disabled
- Accounts with unusual shell assignments
- Service accounts with login shells
- Users with duplicate UIDs/GIDs

##### monitor_failed_logins()
**Purpose**: Monitors and reports on failed login attempts.

**Parameters**: 
- `$1` - Report file path (optional)
- `$2` - Threshold for alerts (default: 10)

**Returns**: Number of failed login attempts

**Example**:
```bash
failed_logins=$(monitor_failed_logins "/tmp/failed_logins.txt" 5)
if [[ $failed_logins -gt 10 ]]; then
    log_warn "High number of failed logins: $failed_logins"
fi
```

##### check_password_policies()
**Purpose**: Validates password policy compliance.

**Parameters**: 
- `$1` - Report file path (optional)

**Returns**: Number of policy violations

**Example**:
```bash
violations=$(check_password_policies "/tmp/password_policy.txt")
echo "Password policy violations: $violations"
```

##### cleanup_inactive_users()
**Purpose**: Identifies and optionally removes inactive user accounts.

**Parameters**: 
- `$1` - Days of inactivity threshold (default: 90)
- `$2` - Dry run mode (true/false, default: true)

**Returns**: Number of inactive accounts found

**Example**:
```bash
# Dry run - just report
inactive=$(cleanup_inactive_users 60 true)

# Actually disable accounts
cleanup_inactive_users 90 false
```

## System Modules

### Backup Monitor

**Location**: `modules/system/backup_monitor.sh`

Provides functions for monitoring backup systems and verifying backup integrity.

#### Functions

##### verify_backup_integrity()
**Purpose**: Verifies the integrity of backup files and systems.

**Parameters**: 
- `$1` - Report file path (optional)

**Returns**: Number of backup issues found

**Example**:
```bash
source "modules/system/backup_monitor.sh"
issues=$(verify_backup_integrity "/tmp/backup_report.txt")
if [[ $issues -eq 0 ]]; then
    log_success "All backups verified successfully"
else
    log_error "Found $issues backup integrity issues"
fi
```

**Checks Performed**:
- Backup file existence and accessibility
- Backup file size consistency
- Backup age and freshness
- Checksum verification where available
- Storage space availability

##### monitor_backup_storage()
**Purpose**: Monitors backup storage usage and capacity.

**Parameters**: 
- `$1` - Report file path (optional)
- `$2` - Warning threshold percentage (default: 80)
- `$3` - Critical threshold percentage (default: 90)

**Returns**: Storage usage percentage

**Example**:
```bash
usage=$(monitor_backup_storage "/tmp/storage_report.txt" 75 85)
if [[ $usage -gt 85 ]]; then
    send_notification "admin@example.com" "Backup Storage Alert" "Usage at ${usage}%"
fi
```

##### test_backup_restore()
**Purpose**: Tests backup restoration procedures.

**Parameters**: 
- `$1` - Backup path to test
- `$2` - Test directory (optional)

**Returns**: 0 if restore test successful, 1 if failed

**Example**:
```bash
if test_backup_restore "/backup/daily/2024-01-01.tar.gz" "/tmp/restore_test"; then
    log_success "Backup restore test passed"
else
    log_error "Backup restore test failed"
fi
```

### Security Audit

**Location**: `modules/system/security_audit.sh`

Provides comprehensive security auditing functions for system compliance and vulnerability assessment.

#### Functions

##### check_file_permissions()
**Purpose**: Audits file and directory permissions for security compliance.

**Parameters**: 
- `$1` - Report file path (optional)

**Returns**: Number of permission issues found

**Example**:
```bash
source "modules/system/security_audit.sh"
issues=$(check_file_permissions "/tmp/permission_audit.txt")
echo "Permission issues found: $issues"
```

**Checks Performed**:
- World-writable files and directories
- SUID/SGID files
- Files with unusual ownership
- Critical system file permissions
- Configuration file security

##### check_running_processes()
**Purpose**: Analyzes running processes for security concerns.

**Parameters**: 
- `$1` - Report file path (optional)

**Returns**: Number of suspicious processes found

**Example**:
```bash
suspicious=$(check_running_processes "/tmp/process_audit.txt")
if [[ $suspicious -gt 0 ]]; then
    log_warn "Found $suspicious suspicious processes"
fi
```

**Checks Performed**:
- Processes running as root unnecessarily
- Unknown or suspicious process names
- Network connections from unexpected processes
- Resource usage anomalies

##### check_security_config()
**Purpose**: Validates security configuration settings.

**Parameters**: 
- `$1` - Report file path (optional)

**Returns**: Number of configuration issues found

**Example**:
```bash
config_issues=$(check_security_config "/tmp/security_config.txt")
echo "Security configuration issues: $config_issues"
```

**Checks Performed**:
- SSH configuration security
- Firewall status and rules
- System service configurations
- Network security settings
- Kernel security parameters

##### check_system_vulnerabilities()
**Purpose**: Scans for known vulnerabilities and security updates.

**Parameters**: 
- `$1` - Report file path (optional)

**Returns**: Number of vulnerabilities found

**Example**:
```bash
vulns=$(check_system_vulnerabilities "/tmp/vuln_scan.txt")
if [[ $vulns -gt 0 ]]; then
    send_notification "security@example.com" "Vulnerabilities Found" "Found $vulns security issues"
fi
```

### Log Management

**Location**: `modules/system/log_management.sh`

Provides functions for log analysis, rotation, and maintenance.

#### Functions

##### analyze_system_logs()
**Purpose**: Analyzes system logs for errors, warnings, and suspicious activity.

**Parameters**: 
- `$1` - Report file path (optional)
- `$2` - Days back to analyze (default: 1)

**Returns**: Number of log issues found

**Example**:
```bash
source "modules/system/log_management.sh"
issues=$(analyze_system_logs "/tmp/log_analysis.txt" 7)
echo "Log issues found in last 7 days: $issues"
```

**Analysis Performed**:
- Error and critical message detection
- Authentication failure patterns
- System service issues
- Disk space and memory warnings
- Network connectivity problems

##### rotate_logs()
**Purpose**: Rotates and compresses log files based on age and size.

**Parameters**: 
- `$1` - Retention days (default: 30)
- `$2` - Compression age days (default: 7)

**Returns**: 0 if successful, 1 if errors occurred

**Example**:
```bash
if rotate_logs 45 14; then
    log_success "Log rotation completed successfully"
else
    log_error "Log rotation encountered issues"
fi
```

##### monitor_log_growth()
**Purpose**: Monitors log file sizes and growth patterns.

**Parameters**: 
- `$1` - Report file path (optional)
- `$2` - Warning size in MB (default: 100)
- `$3` - Critical size in MB (default: 500)

**Returns**: Number of oversized log files

**Example**:
```bash
large_logs=$(monitor_log_growth "/tmp/log_growth.txt" 50 200)
if [[ $large_logs -gt 0 ]]; then
    log_warn "Found $large_logs large log files"
fi
```

##### generate_log_stats()
**Purpose**: Generates comprehensive log statistics and insights.

**Parameters**: 
- `$1` - Report file path (optional)
- `$2` - Days back to analyze (default: 7)

**Returns**: 0 if successful

**Example**:
```bash
generate_log_stats "/tmp/log_statistics.txt" 30
```

## Module Integration

### Using Modules in Scripts

All modules are designed to be sourced and used in automation scripts:

```bash
#!/bin/bash

# Source core libraries
source "$(dirname "$0")/../../core/lib/init.sh"

# Source required modules
source "$(dirname "$0")/../../modules/users/user_management.sh"
source "$(dirname "$0")/../../modules/system/security_audit.sh"

# Use module functions
user_issues=$(check_user_accounts)
security_issues=$(check_file_permissions)

# Generate combined report
if [[ $((user_issues + security_issues)) -gt 0 ]]; then
    send_notification "admin@example.com" "System Issues" "Found issues requiring attention"
fi
```

### Error Handling

All module functions include comprehensive error handling:

- Return appropriate exit codes
- Log errors using the centralized logging system
- Generate detailed error reports
- Gracefully handle missing files or permissions

### Configuration Integration

Modules automatically integrate with the configuration system:

```bash
# Get configuration values
retention_days=$(get_config "logging.retention_days" 30)
email_recipient=$(get_config "notifications.recipients.admin")

# Use configuration in module functions
rotate_logs "$retention_days"
send_notification "$email_recipient" "Log Rotation" "Completed successfully"
```

## Best Practices

### Module Development

1. **Function Naming**: Use descriptive names with verb_noun pattern
2. **Parameter Handling**: Always provide sensible defaults
3. **Return Values**: Return meaningful exit codes and counts
4. **Error Handling**: Include comprehensive error checking
5. **Logging**: Use centralized logging functions
6. **Documentation**: Include inline documentation for complex functions

### Usage Guidelines

1. **Source Order**: Always source core libraries before modules
2. **Configuration**: Use configuration system for customizable behavior
3. **Error Checking**: Always check return values from module functions
4. **Resource Cleanup**: Clean up temporary files and resources
5. **Privilege Checking**: Verify privileges before system operations

### Performance Considerations

1. **Lazy Loading**: Only source modules when needed
2. **Caching**: Cache expensive operations when possible
3. **Parallel Processing**: Use background processes for independent operations
4. **Resource Limits**: Respect system resource constraints
5. **Timeout Handling**: Include timeouts for long-running operations