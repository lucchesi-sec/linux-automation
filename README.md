<p align="center">
  <img src="icons8-linux-64.png" alt="Linux icon">
</p>

# Linux Daily Administration Automation

[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://github.com/lucchesi-sec/linux-automation/graphs/commit-activity)
[![GitHub last commit](https://img.shields.io/github/last-commit/lucchesi-sec/linux-automation.svg)](https://github.com/lucchesi-sec/linux-automation/commits/main)
[![GitHub issues](https://img.shields.io/github/issues/lucchesi-sec/linux-automation.svg)](https://github.com/lucchesi-sec/linux-automation/issues)
[![GitHub forks](https://img.shields.io/github/forks/lucchesi-sec/linux-automation.svg)](https://github.com/lucchesi-sec/linux-automation/network/members)
[![GitHub stars](https://img.shields.io/github/stars/lucchesi-sec/linux-automation.svg)](https://github.com/lucchesi-sec/linux-automation/stargazers)
[![Made with Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

A comprehensive suite of Bash scripts for automating daily administrative tasks on Linux systems. This toolkit provides enterprise-grade automation for user management, backup verification, security auditing, log management, and system maintenance.

## Table of Contents

- [Features](#-features)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Quick Start](#quick-start)
- [Usage](#-usage)
  - [Running the Full Suite](#running-the-full-suite)
  - [Running Individual Scripts](#running-individual-scripts)
- [Configuration](#-configuration)
- [Project Structure](#-project-structure)
- [Documentation](#-documentation)
- [Contributing](#-contributing)
- [License](#-license)

## ✨ Features

This toolkit provides a wide range of features to automate Linux system administration:

-   **User Management**: Scripts for adding, deleting, and managing user accounts.
-   **Backup Management**: Tools to initiate and verify system backups.
-   **Package Management**: Automated checks for package updates and system upgrades.
-   **Process & Service Monitoring**: Monitor critical system processes and services to ensure they are running correctly.
-   **System Health Checks**: Perform regular health checks on the system's resources (CPU, memory, disk space).
-   **Security Auditing**: Run daily security audits to identify potential vulnerabilities.
-   **Log Management**: Automated log rotation, compression, and cleanup.
-   **Daily Administration Suite**: A master script that runs all daily checks and tasks in a coordinated manner.

## 🚀 Getting Started

This guide will help you get started with the Linux Daily Administration Automation toolkit.

### Prerequisites

-   Linux system (Ubuntu 18.04+, CentOS 7+, or similar)
-   Bash 4.0 or higher
-   Root or sudo privileges for system administration tasks

### Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/lucchesi-sec/linux-automation.git
    cd linux-automation
    ```

2.  **Set Permissions**:
    Make all scripts executable.
    ```bash
    find . -name "*.sh" -exec chmod +x {} \;
    ```

3.  **Initialize Configuration**:
    Copy the example configuration file. You will need to edit this file to match your environment.
    ```bash
    sudo cp config/config.json.example config/config.json
    ```

### Quick Start

To run the complete daily administration suite:

```bash
sudo ./scripts/administration/daily_admin_suite.sh
```

## 💻 Usage

### Running the Full Suite

The most common use case is to run the entire suite of administrative scripts. This can be scheduled as a cron job to run daily.

```bash
sudo ./scripts/administration/daily_admin_suite.sh
```

### Running Individual Scripts

You can also run individual scripts for specific tasks. For example, to run only the security audit:

```bash
sudo ./scripts/administration/daily_security_audit.sh
```

Or to perform disk cleanup:

```bash
sudo ./scripts/maintenance/disk_cleanup.sh
```

## ⚙️ Configuration

All scripts are configured through the central `config/config.json` file. This file allows you to set parameters for logging, notifications, backup paths, and more.

For a detailed explanation of all configuration options, please see the [Configuration Reference](docs/configuration.md).

## 📁 Project Structure

The project is organized into the following directories:

```
.
├── config/         # Configuration files
├── core/           # Core libraries for shared functionality
├── docs/           # Detailed documentation
├── modules/        # Individual automation modules
└── scripts/        # Executable scripts for administration and maintenance
```

## 📚 Documentation

For more detailed information, please refer to the full documentation in the `docs` directory:

-   [Installation Guide](docs/installation.md)
-   [Configuration Reference](docs/configuration.md)
-   [Module Documentation](docs/modules.md)
-   [Usage Examples](docs/examples.md)
-   [Troubleshooting Guide](docs/troubleshooting.md)

## 🤝 Contributing

Contributions are welcome! At present, we are working on establishing formal contribution guidelines.

## 📄 License

This project is licensed under the MIT License.
