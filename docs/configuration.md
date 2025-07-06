# Configuration Reference

**Navigation**: [Home](../README.md) | [Installation](installation.md) | [Examples](examples.md)

This guide provides a complete reference for all configuration options in the `config.json` file.

**Important**: After modifying the configuration, you may need to restart any running services or daemons for the changes to take effect.

## Basic Configuration

Edit `config/config.json`:

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
