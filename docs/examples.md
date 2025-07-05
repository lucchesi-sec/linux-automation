# Usage Examples

This document provides practical examples of how to use the Linux Daily Administration Automation system in real-world scenarios.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Daily Operations](#daily-operations)
- [Security Scenarios](#security-scenarios)
- [Backup Management](#backup-management)
- [Log Management](#log-management)
- [Custom Automation](#custom-automation)
- [Integration Examples](#integration-examples)

## Basic Usage

### Running Individual Scripts

#### User Management Tasks
```bash
# Check user account security
sudo ./scripts/administration/daily_user_tasks.sh

# Run with verbose output for debugging
sudo ./scripts/administration/daily_user_tasks.sh --verbose

# Dry run to see what would be done
sudo ./scripts/administration/daily_user_tasks.sh --dry-run

# Generate report but don't send emails
sudo ./scripts/administration/daily_user_tasks.sh --no-email
```

#### Security Auditing
```bash
# Full security audit
sudo ./scripts/administration/daily_security_audit.sh

# Quick security check (skip vulnerability scan)
sudo ./scripts/administration/daily_security_audit.sh --quick

# Quiet mode for cron jobs
sudo ./scripts/administration/daily_security_audit.sh --quiet
```

#### Backup Verification
```bash
# Check all backup jobs
sudo ./scripts/administration/daily_backup_check.sh

# Check specific backup location
sudo ./scripts/administration/daily_backup_check.sh --path /backup/daily

# Force verification even if recent check exists
sudo ./scripts/administration/daily_backup_check.sh --force
```

#### Log Maintenance
```bash
# Full log maintenance
sudo ./scripts/administration/daily_log_maintenance.sh

# Only analyze logs, don't rotate
sudo ./scripts/administration/daily_log_maintenance.sh --analysis-only

# Custom retention period
sudo ./scripts/administration/daily_log_maintenance.sh --retention 60 --compress 14
```

### Running the Complete Suite

#### Basic Suite Execution
```bash
# Run all daily administration tasks
sudo ./scripts/administration/daily_admin_suite.sh

# View execution plan without running
sudo ./scripts/administration/daily_admin_suite.sh --dry-run

# Run with detailed logging
sudo ./scripts/administration/daily_admin_suite.sh --verbose
```

#### Selective Task Execution
```bash
# Run only backup checks
sudo ./scripts/administration/daily_admin_suite.sh --only backup_check

# Run only user and security tasks
sudo ./scripts/administration/daily_admin_suite.sh --only user_tasks --only security_check

# Skip log management
sudo ./scripts/administration/daily_admin_suite.sh --skip log_management

# Skip multiple tasks
sudo ./scripts/administration/daily_admin_suite.sh --skip user_tasks --skip backup_check
```

## Daily Operations

### Morning Administrative Routine

#### Automated Morning Report
```bash
#!/bin/bash
# morning_report.sh - Generate comprehensive morning administrative report

# Run complete daily suite
sudo /opt/linux-automation/scripts/administration/daily_admin_suite.sh --quiet

# Generate executive summary
cat > /tmp/morning_summary.txt << EOF
Linux Administration Summary - $(date)
=====================================

System Status: $(uptime -p)
Load Average: $(uptime | awk -F'load average:' '{print $2}')
Disk Usage: $(df -h / | awk 'NR==2{print $5}')
Memory Usage: $(free -h | awk 'NR==2{printf "%.1f%%", $3/$2*100}')

Recent Reports Available:
- Security Audit: /var/log/bash-admin/security-reports/daily_security_summary_$(date +%Y%m%d).html
- Backup Status: /var/log/bash-admin/backup-reports/daily_backup_summary_$(date +%Y%m%d).html
- User Activity: /var/log/bash-admin/user-reports/daily_user_summary_$(date +%Y%m%d).html
- Log Analysis: /var/log/bash-admin/log-reports/daily_log_summary_$(date +%Y%m%d).html

Master Report: /var/log/bash-admin/daily-reports/daily_admin_master_$(date +%Y%m%d).html
EOF

# Email summary to administrators
mail -s "Morning System Summary - $(hostname)" admin@example.com < /tmp/morning_summary.txt
```

#### Weekly Deep Inspection
```bash
#!/bin/bash
# weekly_deep_check.sh - Comprehensive weekly system inspection

# Extended security audit
sudo /opt/linux-automation/scripts/administration/daily_security_audit.sh --verbose

# Extended log analysis (7 days)
sudo /opt/linux-automation/scripts/administration/daily_log_maintenance.sh --verbose

# Generate weekly trend report
find /var/log/bash-admin -name "daily_admin_master_*.html" -mtime -7 | \
    xargs grep -l "Issues Detected\|Failed\|Critical" | \
    wc -l > /tmp/weekly_issues_count.txt

echo "Weekly trend analysis complete. Issues found: $(cat /tmp/weekly_issues_count.txt)"
```

### End-of-Day Cleanup

#### Evening Maintenance
```bash
#!/bin/bash
# evening_maintenance.sh - End of day system maintenance

# Log rotation and cleanup
sudo /opt/linux-automation/scripts/administration/daily_log_maintenance.sh --quiet

# Final security check
sudo /opt/linux-automation/scripts/administration/daily_security_audit.sh --quick --quiet

# Generate end-of-day summary
{
    echo "End of Day System Summary - $(date)"
    echo "===================================="
    echo
    echo "Log Files Processed:"
    ls -la /var/log/bash-admin/*-reports/ | grep "$(date +%Y%m%d)" | wc -l
    echo
    echo "Disk Space Status:"
    df -h / /var/log
    echo
    echo "System Load:"
    uptime
} | mail -s "End of Day Summary - $(hostname)" admin@example.com
```

## Security Scenarios

### Incident Response

#### Security Alert Investigation
```bash
#!/bin/bash
# security_incident_response.sh - Respond to security alerts

# Immediate security assessment
sudo /opt/linux-automation/scripts/administration/daily_security_audit.sh --verbose

# Analyze recent authentication logs
sudo grep "$(date '+%b %d')" /var/log/auth.log | \
    grep -E "(Failed password|Invalid user|authentication failure)" | \
    tail -20

# Check for unusual process activity
ps auxf | grep -v "\[" | sort -k3 -nr | head -10

# Generate emergency security report
{
    echo "SECURITY INCIDENT RESPONSE REPORT"
    echo "Generated: $(date)"
    echo "Host: $(hostname)"
    echo "=================================="
    echo
    echo "Recent Failed Logins:"
    grep "$(date '+%b %d')" /var/log/auth.log | grep "Failed password" | tail -10
    echo
    echo "Current Network Connections:"
    netstat -tuln | grep LISTEN
    echo
    echo "Root Processes:"
    ps aux | awk '$1=="root"' | head -10
} > /tmp/security_incident_$(date +%Y%m%d_%H%M%S).txt

# Send immediate alert
mail -s "URGENT: Security Incident Response - $(hostname)" security@example.com < /tmp/security_incident_$(date +%Y%m%d_%H%M%S).txt
```

#### Compliance Audit Preparation
```bash
#!/bin/bash
# compliance_audit_prep.sh - Prepare for compliance audit

# Generate comprehensive security documentation
sudo /opt/linux-automation/scripts/administration/daily_security_audit.sh --verbose

# Create compliance checklist
{
    echo "COMPLIANCE AUDIT CHECKLIST"
    echo "=========================="
    echo "Date: $(date)"
    echo "System: $(hostname)"
    echo
    echo "Security Controls:"
    echo "- Firewall Status: $(systemctl is-active ufw || echo 'Not configured')"
    echo "- SSH Configuration: $(grep PermitRootLogin /etc/ssh/sshd_config || echo 'Default')"
    echo "- Fail2ban Status: $(systemctl is-active fail2ban || echo 'Not installed')"
    echo "- SELinux/AppArmor: $(getenforce 2>/dev/null || aa-status --enabled 2>/dev/null || echo 'Not configured')"
    echo
    echo "User Access Controls:"
    echo "- Users with shell access: $(awk -F: '$7!~/nologin|false/ && $1!="root" {print $1}' /etc/passwd | wc -l)"
    echo "- Sudo access users: $(grep sudo /etc/group | cut -d: -f4 | tr ',' '\n' | wc -l)"
    echo
    echo "System Monitoring:"
    echo "- Log retention: $(find /var/log -name '*.log' -mtime +30 | wc -l) logs older than 30 days"
    echo "- Failed login attempts today: $(grep "$(date '+%b %d')" /var/log/auth.log | grep -c "Failed password")"
} > /tmp/compliance_audit_$(date +%Y%m%d).txt

echo "Compliance audit preparation complete. Report saved to /tmp/compliance_audit_$(date +%Y%m%d).txt"
```

### Vulnerability Management

#### Security Update Assessment
```bash
#!/bin/bash
# security_update_check.sh - Check for security updates

# Update package lists
sudo apt-get update >/dev/null 2>&1

# Check for security updates
if command -v apt-get >/dev/null; then
    security_updates=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
    all_updates=$(apt list --upgradable 2>/dev/null | wc -l)
elif command -v yum >/dev/null; then
    security_updates=$(yum --security check-update 2>/dev/null | grep -c "needed for security")
    all_updates=$(yum check-update 2>/dev/null | grep -c "updates")
fi

# Generate update report
{
    echo "SECURITY UPDATE ASSESSMENT"
    echo "========================="
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo
    echo "Available Updates:"
    echo "- Security updates: $security_updates"
    echo "- Total updates: $all_updates"
    echo
    if [[ $security_updates -gt 0 ]]; then
        echo "CRITICAL: Security updates available!"
        echo
        if command -v apt-get >/dev/null; then
            apt list --upgradable 2>/dev/null | grep -i security
        fi
    else
        echo "System is up to date with security patches."
    fi
} > /tmp/security_updates_$(date +%Y%m%d).txt

# Send alert if security updates available
if [[ $security_updates -gt 0 ]]; then
    mail -s "SECURITY UPDATES AVAILABLE - $(hostname)" security@example.com < /tmp/security_updates_$(date +%Y%m%d).txt
fi
```

## Backup Management

### Backup Verification Workflows

#### Daily Backup Health Check
```bash
#!/bin/bash
# backup_health_check.sh - Comprehensive backup verification

# Check backup system status
sudo /opt/linux-automation/scripts/administration/daily_backup_check.sh --verbose

# Verify backup integrity for critical directories
backup_paths=("/etc" "/home" "/var/log" "/opt")

for path in "${backup_paths[@]}"; do
    echo "Checking backups for: $path"
    
    # Find most recent backup
    latest_backup=$(find /backup -name "*$(basename "$path")*" -mtime -1 | head -1)
    
    if [[ -n "$latest_backup" ]]; then
        echo "  Latest backup: $latest_backup"
        echo "  Size: $(du -sh "$latest_backup" | cut -f1)"
        echo "  Date: $(stat -c %y "$latest_backup")"
    else
        echo "  WARNING: No recent backup found for $path"
    fi
    echo
done

# Test restore capability
test_restore_dir="/tmp/restore_test_$(date +%s)"
mkdir -p "$test_restore_dir"

echo "Testing restore capability..."
if tar -tf /backup/daily/etc_backup_$(date +%Y%m%d).tar.gz >/dev/null 2>&1; then
    echo "  Backup archive is readable"
    tar -xf /backup/daily/etc_backup_$(date +%Y%m%d).tar.gz -C "$test_restore_dir" --wildcards "*/passwd" 2>/dev/null
    if [[ -f "$test_restore_dir"*/passwd ]]; then
        echo "  Test restore successful"
    else
        echo "  WARNING: Test restore failed"
    fi
else
    echo "  ERROR: Cannot read backup archive"
fi

# Cleanup
rm -rf "$test_restore_dir"
```

#### Weekly Backup Rotation
```bash
#!/bin/bash
# weekly_backup_rotation.sh - Manage backup retention and rotation

backup_base="/backup"
daily_dir="$backup_base/daily"
weekly_dir="$backup_base/weekly"
monthly_dir="$backup_base/monthly"

# Create weekly archive from daily backups
if [[ $(date +%u) -eq 7 ]]; then  # Sunday
    echo "Creating weekly backup archive..."
    
    # Copy most recent daily backup to weekly
    latest_daily=$(find "$daily_dir" -name "*.tar.gz" -mtime -1 | head -1)
    if [[ -n "$latest_daily" ]]; then
        weekly_name="weekly_backup_$(date +%Y%W).tar.gz"
        cp "$latest_daily" "$weekly_dir/$weekly_name"
        echo "Created weekly backup: $weekly_name"
    fi
fi

# Create monthly archive (first Sunday of month)
if [[ $(date +%d) -le 7 && $(date +%u) -eq 7 ]]; then
    echo "Creating monthly backup archive..."
    
    latest_weekly=$(find "$weekly_dir" -name "*.tar.gz" -mtime -7 | head -1)
    if [[ -n "$latest_weekly" ]]; then
        monthly_name="monthly_backup_$(date +%Y%m).tar.gz"
        cp "$latest_weekly" "$monthly_dir/$monthly_name"
        echo "Created monthly backup: $monthly_name"
    fi
fi

# Clean up old backups
echo "Cleaning up old backups..."

# Remove daily backups older than 7 days
find "$daily_dir" -name "*.tar.gz" -mtime +7 -delete

# Remove weekly backups older than 8 weeks
find "$weekly_dir" -name "*.tar.gz" -mtime +56 -delete

# Remove monthly backups older than 12 months
find "$monthly_dir" -name "*.tar.gz" -mtime +365 -delete

echo "Backup rotation complete."
```

## Log Management

### Advanced Log Analysis

#### Security Log Analysis
```bash
#!/bin/bash
# security_log_analysis.sh - Analyze logs for security events

# Analyze authentication logs
echo "SECURITY LOG ANALYSIS - $(date)"
echo "=============================="

# Failed login attempts
echo "Failed Login Attempts (Last 24h):"
grep "$(date '+%b %d')" /var/log/auth.log | \
    grep "Failed password" | \
    awk '{print $1" "$2" "$3" - "$9" from "$11}' | \
    sort | uniq -c | sort -nr

echo

# Successful root logins
echo "Root Login Activity (Last 24h):"
grep "$(date '+%b %d')" /var/log/auth.log | \
    grep "Accepted.*root" | \
    awk '{print $1" "$2" "$3" - from "$11}'

echo

# Sudo usage
echo "Sudo Usage (Last 24h):"
grep "$(date '+%b %d')" /var/log/auth.log | \
    grep "sudo:" | \
    awk '{print $1" "$2" "$3" - "$5" "$6" "$7}' | \
    sort | uniq -c

echo

# Unusual user activity
echo "New User Sessions (Last 24h):"
grep "$(date '+%b %d')" /var/log/auth.log | \
    grep "session opened" | \
    awk '{print $1" "$2" "$3" - "$11" ("$5")"}' | \
    sort | uniq

# Generate alert if suspicious activity
failed_attempts=$(grep "$(date '+%b %d')" /var/log/auth.log | grep -c "Failed password")
if [[ $failed_attempts -gt 20 ]]; then
    echo
    echo "ALERT: High number of failed login attempts: $failed_attempts"
    echo "Consider implementing additional security measures."
fi
```

#### Performance Log Analysis
```bash
#!/bin/bash
# performance_log_analysis.sh - Analyze system performance from logs

echo "SYSTEM PERFORMANCE ANALYSIS - $(date)"
echo "===================================="

# System load analysis
echo "System Load Patterns (Last 24h):"
grep "$(date '+%b %d')" /var/log/syslog | \
    grep "load average" | \
    awk '{print $3" - Load: "$NF}' | \
    tail -10

echo

# Memory usage warnings
echo "Memory Warnings (Last 24h):"
grep "$(date '+%b %d')" /var/log/syslog | \
    grep -i "memory\|oom\|killed" | \
    awk '{print $3" - "$0}' | \
    tail -5

echo

# Disk space warnings
echo "Disk Space Warnings (Last 24h):"
grep "$(date '+%b %d')" /var/log/syslog | \
    grep -i "space\|full\|disk" | \
    awk '{print $3" - "$0}' | \
    tail -5

echo

# Service restart events
echo "Service Restart Events (Last 24h):"
grep "$(date '+%b %d')" /var/log/syslog | \
    grep -E "(started|stopped|restarted)" | \
    grep systemd | \
    awk '{print $3" - "$0}' | \
    tail -10

# Current system status
echo
echo "Current System Status:"
echo "- Uptime: $(uptime -p)"
echo "- Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "- Memory: $(free -h | awk 'NR==2{printf "Used: %s/%s (%.1f%%)", $3,$2,$3*100/$2}')"
echo "- Disk: $(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')"
```

## Custom Automation

### Creating Custom Modules

#### Custom Database Monitoring Module
```bash
#!/bin/bash
# modules/custom/database_monitor.sh - Custom database monitoring

# Source core libraries
source "$(dirname "$0")/../../core/lib/init.sh"

# Monitor database health
monitor_database_health() {
    local report_file="${1:-/tmp/db_health_$(date +%Y%m%d).txt}"
    local issues_found=0
    
    log_info "Starting database health monitoring"
    
    # Check MySQL/MariaDB if running
    if systemctl is-active mysql >/dev/null 2>&1 || systemctl is-active mariadb >/dev/null 2>&1; then
        log_info "Checking MySQL/MariaDB health"
        
        # Check connection
        if mysql -e "SELECT 1;" >/dev/null 2>&1; then
            log_success "MySQL connection successful"
            
            # Check for slow queries
            slow_queries=$(mysql -e "SHOW GLOBAL STATUS LIKE 'Slow_queries';" | awk 'NR==2{print $2}')
            if [[ $slow_queries -gt 100 ]]; then
                log_warn "High number of slow queries: $slow_queries"
                ((issues_found++))
            fi
            
            # Check for locked tables
            locked_tables=$(mysql -e "SHOW OPEN TABLES WHERE In_use > 0;" | wc -l)
            if [[ $locked_tables -gt 0 ]]; then
                log_warn "Found $locked_tables locked tables"
                ((issues_found++))
            fi
        else
            log_error "Cannot connect to MySQL database"
            ((issues_found++))
        fi
    fi
    
    # Check PostgreSQL if running
    if systemctl is-active postgresql >/dev/null 2>&1; then
        log_info "Checking PostgreSQL health"
        
        if sudo -u postgres psql -c "SELECT 1;" >/dev/null 2>&1; then
            log_success "PostgreSQL connection successful"
            
            # Check for database size
            db_sizes=$(sudo -u postgres psql -c "SELECT pg_size_pretty(pg_database_size(datname)) FROM pg_database WHERE datname NOT IN ('template0', 'template1');" | grep -v "pg_size_pretty" | grep -v "^\-\-")
            log_info "Database sizes: $db_sizes"
        else
            log_error "Cannot connect to PostgreSQL database"
            ((issues_found++))
        fi
    fi
    
    # Generate report
    {
        echo "Database Health Report - $(date)"
        echo "================================"
        echo "Issues found: $issues_found"
        echo
        if [[ $issues_found -eq 0 ]]; then
            echo "All databases are healthy"
        else
            echo "Database issues require attention"
        fi
    } > "$report_file"
    
    log_info "Database health report generated: $report_file"
    return $issues_found
}

# Export function for use by other scripts
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f monitor_database_health
fi
```

#### Custom Application Monitoring Script
```bash
#!/bin/bash
# scripts/custom/app_monitor.sh - Monitor custom applications

# Source core libraries and custom modules
source "$(dirname "$0")/../../core/lib/init.sh"
source "$(dirname "$0")/../../modules/custom/database_monitor.sh"

main() {
    log_info "Starting application monitoring"
    
    local exit_code=0
    local task_results=()
    
    # Monitor web application
    if curl -s http://localhost/health >/dev/null; then
        task_results+=("✓ Web application health check passed")
    else
        task_results+=("✗ Web application health check failed")
        exit_code=1
    fi
    
    # Monitor database
    local db_issues
    db_issues=$(monitor_database_health)
    if [[ $? -eq 0 ]]; then
        task_results+=("✓ Database health check passed")
    else
        task_results+=("✗ Database health check found $db_issues issues")
        exit_code=1
    fi
    
    # Monitor custom service
    if systemctl is-active my-custom-service >/dev/null 2>&1; then
        task_results+=("✓ Custom service is running")
    else
        task_results+=("✗ Custom service is not running")
        exit_code=1
    fi
    
    # Generate summary
    {
        echo "Application Monitoring Summary - $(date)"
        echo "======================================="
        printf "%s\n" "${task_results[@]}"
    } > "/tmp/app_monitor_$(date +%Y%m%d).txt"
    
    # Send notification if issues found
    if [[ $exit_code -ne 0 ]]; then
        send_notification "admin@example.com" "Application Issues Detected" \
            "Application monitoring found issues. Check /tmp/app_monitor_$(date +%Y%m%d).txt for details."
    fi
    
    return $exit_code
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## Integration Examples

### Integration with External Systems

#### Slack Integration
```bash
#!/bin/bash
# Send notifications to Slack

send_slack_notification() {
    local webhook_url="$1"
    local message="$2"
    local channel="${3:-#alerts}"
    local username="${4:-Linux-Automation}"
    
    curl -X POST -H 'Content-type: application/json' \
        --data "{
            \"channel\":\"$channel\",
            \"username\":\"$username\",
            \"text\":\"$message\",
            \"icon_emoji\":\":robot_face:\"
        }" \
        "$webhook_url"
}

# Usage in scripts
send_slack_notification "$SLACK_WEBHOOK" "Daily admin suite completed on $(hostname)" "#infrastructure"
```

#### Prometheus Metrics Export
```bash
#!/bin/bash
# Export metrics for Prometheus

export_prometheus_metrics() {
    local metrics_file="/var/lib/node_exporter/textfile_collector/bash_admin.prom"
    
    # Export basic metrics
    {
        echo "# HELP bash_admin_last_run_timestamp Unix timestamp of last successful run"
        echo "# TYPE bash_admin_last_run_timestamp gauge"
        echo "bash_admin_last_run_timestamp $(date +%s)"
        
        echo "# HELP bash_admin_issues_found Number of issues found in last run"
        echo "# TYPE bash_admin_issues_found gauge"
        echo "bash_admin_issues_found $1"
        
        echo "# HELP bash_admin_scripts_executed Number of scripts executed"
        echo "# TYPE bash_admin_scripts_executed counter"
        echo "bash_admin_scripts_executed $2"
    } > "$metrics_file"
}

# Usage in main suite
export_prometheus_metrics "$total_issues" "$scripts_run"
```

#### SIEM Integration
```bash
#!/bin/bash
# Send structured logs to SIEM system

send_to_siem() {
    local event_type="$1"
    local severity="$2"
    local message="$3"
    local siem_endpoint="https://siem.example.com/api/events"
    
    local json_payload=$(jq -n \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg hostname "$(hostname)" \
        --arg event_type "$event_type" \
        --arg severity "$severity" \
        --arg message "$message" \
        '{
            timestamp: $timestamp,
            hostname: $hostname,
            source: "linux-automation",
            event_type: $event_type,
            severity: $severity,
            message: $message
        }')
    
    curl -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $SIEM_API_TOKEN" \
        -d "$json_payload" \
        "$siem_endpoint"
}

# Usage for security events
send_to_siem "security_audit" "warning" "Found $issues security issues on $(hostname)"
```

These examples demonstrate the flexibility and power of the Linux automation system for various real-world scenarios. The modular design allows for easy customization and integration with existing infrastructure and workflows.