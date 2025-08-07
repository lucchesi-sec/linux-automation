#!/bin/bash
# System API Abstraction Layer
# Provides abstracted interfaces for system operations to enforce Dependency Inversion Principle
# All system access should go through these interfaces instead of direct system calls

# Initialize system API
init_system_api() {
    readonly SYSTEM_API_VERSION="1.0.0"
    readonly SYSTEM_API_INITIALIZED=true
    
    # Platform detection
    readonly SYSTEM_PLATFORM="$(uname -s)"
    readonly SYSTEM_ARCH="$(uname -m)"
    readonly SYSTEM_KERNEL="$(uname -r)"
    
    # OS detection
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        readonly SYSTEM_OS_NAME="${NAME:-unknown}"
        readonly SYSTEM_OS_VERSION="${VERSION_ID:-unknown}"
        readonly SYSTEM_OS_ID="${ID:-unknown}"
    else
        readonly SYSTEM_OS_NAME="unknown"
        readonly SYSTEM_OS_VERSION="unknown"
        readonly SYSTEM_OS_ID="unknown"
    fi
}

# ================================
# User Management Interface
# ================================

# Get user information abstraction
system_api_get_user() {
    local username="$1"
    local field="${2:-all}"
    
    case "$SYSTEM_PLATFORM" in
        Linux)
            if [[ "$field" == "all" ]]; then
                getent passwd "$username" 2>/dev/null
            else
                getent passwd "$username" 2>/dev/null | cut -d: -f"$field"
            fi
            ;;
        Darwin)
            if [[ "$field" == "all" ]]; then
                dscl . -read "/Users/$username" 2>/dev/null
            else
                # Map field numbers to dscl attributes
                case "$field" in
                    1) dscl . -read "/Users/$username" UserShell 2>/dev/null | awk '{print $2}' ;;
                    3) dscl . -read "/Users/$username" UniqueID 2>/dev/null | awk '{print $2}' ;;
                    4) dscl . -read "/Users/$username" PrimaryGroupID 2>/dev/null | awk '{print $2}' ;;
                    6) dscl . -read "/Users/$username" NFSHomeDirectory 2>/dev/null | awk '{print $2}' ;;
                    7) dscl . -read "/Users/$username" UserShell 2>/dev/null | awk '{print $2}' ;;
                    *) return 1 ;;
                esac
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# List all users abstraction
system_api_list_users() {
    local min_uid="${1:-1000}"
    local max_uid="${2:-60000}"
    
    case "$SYSTEM_PLATFORM" in
        Linux)
            getent passwd | awk -F: -v min="$min_uid" -v max="$max_uid" '$3 >= min && $3 <= max {print $1}'
            ;;
        Darwin)
            dscl . -list /Users UniqueID | awk -v min="$min_uid" -v max="$max_uid" '$2 >= min && $2 <= max {print $1}'
            ;;
        *)
            return 1
            ;;
    esac
}

# Get user groups abstraction
system_api_get_user_groups() {
    local username="$1"
    
    case "$SYSTEM_PLATFORM" in
        Linux|Darwin)
            groups "$username" 2>/dev/null | cut -d: -f2 | tr -d ' '
            ;;
        *)
            return 1
            ;;
    esac
}

# Check user password status abstraction
system_api_get_password_status() {
    local username="$1"
    
    case "$SYSTEM_PLATFORM" in
        Linux)
            passwd -S "$username" 2>/dev/null | awk '{print $2}'
            ;;
        Darwin)
            # macOS doesn't have passwd -S, check using dscl
            local auth_auth
            auth_auth=$(dscl . -read "/Users/$username" AuthenticationAuthority 2>/dev/null)
            if echo "$auth_auth" | grep -q "DisabledUser"; then
                echo "L"  # Locked
            else
                echo "P"  # Password set
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# Get shadow password information abstraction
system_api_get_shadow_info() {
    local username="$1"
    local field="${2:-all}"
    
    case "$SYSTEM_PLATFORM" in
        Linux)
            if [[ "$field" == "all" ]]; then
                getent shadow "$username" 2>/dev/null || echo "$username:*:::::::"
            else
                getent shadow "$username" 2>/dev/null | cut -d: -f"$field"
            fi
            ;;
        Darwin)
            # macOS doesn't have /etc/shadow, return mock data
            echo "$username:*:::::::"
            ;;
        *)
            return 1
            ;;
    esac
}

# ================================
# Package Management Interface
# ================================

# Detect package manager abstraction
system_api_detect_package_manager() {
    case "$SYSTEM_PLATFORM" in
        Linux)
            if command -v apt-get >/dev/null 2>&1; then
                echo "apt"
            elif command -v dnf >/dev/null 2>&1; then
                echo "dnf"
            elif command -v yum >/dev/null 2>&1; then
                echo "yum"
            elif command -v zypper >/dev/null 2>&1; then
                echo "zypper"
            elif command -v pacman >/dev/null 2>&1; then
                echo "pacman"
            elif command -v apk >/dev/null 2>&1; then
                echo "apk"
            else
                echo "unknown"
            fi
            ;;
        Darwin)
            if command -v brew >/dev/null 2>&1; then
                echo "brew"
            elif command -v port >/dev/null 2>&1; then
                echo "macports"
            else
                echo "unknown"
            fi
            ;;
        FreeBSD)
            echo "pkg"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Update package cache abstraction
system_api_update_package_cache() {
    local package_manager="${1:-$(system_api_detect_package_manager)}"
    
    case "$package_manager" in
        apt)
            apt-get update >/dev/null 2>&1
            ;;
        dnf|yum)
            $package_manager check-update >/dev/null 2>&1 || [[ $? -eq 100 ]]
            ;;
        zypper)
            zypper refresh >/dev/null 2>&1
            ;;
        pacman)
            pacman -Sy >/dev/null 2>&1
            ;;
        apk)
            apk update >/dev/null 2>&1
            ;;
        brew)
            brew update >/dev/null 2>&1
            ;;
        macports)
            port selfupdate >/dev/null 2>&1
            ;;
        pkg)
            pkg update >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# List upgradeable packages abstraction
system_api_list_upgradeable_packages() {
    local package_manager="${1:-$(system_api_detect_package_manager)}"
    
    case "$package_manager" in
        apt)
            apt list --upgradable 2>/dev/null | grep -v "^Listing"
            ;;
        dnf)
            dnf list updates 2>/dev/null
            ;;
        yum)
            yum list updates 2>/dev/null
            ;;
        zypper)
            zypper list-updates 2>/dev/null
            ;;
        pacman)
            pacman -Qu 2>/dev/null
            ;;
        apk)
            apk list --upgradable 2>/dev/null
            ;;
        brew)
            brew outdated 2>/dev/null
            ;;
        macports)
            port outdated 2>/dev/null
            ;;
        pkg)
            pkg version -l '<' 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Install package abstraction
system_api_install_package() {
    local package="$1"
    local package_manager="${2:-$(system_api_detect_package_manager)}"
    local options="${3:-}"
    
    case "$package_manager" in
        apt)
            apt-get install $options -y "$package"
            ;;
        dnf|yum)
            $package_manager install $options -y "$package"
            ;;
        zypper)
            zypper install $options -y "$package"
            ;;
        pacman)
            pacman -S $options --noconfirm "$package"
            ;;
        apk)
            apk add $options "$package"
            ;;
        brew)
            brew install $options "$package"
            ;;
        macports)
            port install $options "$package"
            ;;
        pkg)
            pkg install $options -y "$package"
            ;;
        *)
            return 1
            ;;
    esac
}

# ================================
# Service Management Interface
# ================================

# Get service manager abstraction
system_api_get_service_manager() {
    if command -v systemctl >/dev/null 2>&1; then
        echo "systemd"
    elif command -v service >/dev/null 2>&1; then
        echo "sysv"
    elif command -v rc-service >/dev/null 2>&1; then
        echo "openrc"
    elif [[ "$SYSTEM_PLATFORM" == "Darwin" ]]; then
        echo "launchd"
    elif [[ "$SYSTEM_PLATFORM" == "FreeBSD" ]]; then
        echo "rc"
    else
        echo "unknown"
    fi
}

# List services abstraction
system_api_list_services() {
    local service_manager="${1:-$(system_api_get_service_manager)}"
    
    case "$service_manager" in
        systemd)
            systemctl list-units --type=service --all --no-pager 2>/dev/null
            ;;
        sysv)
            service --status-all 2>/dev/null
            ;;
        openrc)
            rc-status --all 2>/dev/null
            ;;
        launchd)
            launchctl list 2>/dev/null
            ;;
        rc)
            service -l 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Get service status abstraction
system_api_get_service_status() {
    local service="$1"
    local service_manager="${2:-$(system_api_get_service_manager)}"
    
    case "$service_manager" in
        systemd)
            systemctl is-active "$service" 2>/dev/null
            ;;
        sysv)
            service "$service" status >/dev/null 2>&1 && echo "active" || echo "inactive"
            ;;
        openrc)
            rc-service "$service" status >/dev/null 2>&1 && echo "active" || echo "inactive"
            ;;
        launchd)
            launchctl list | grep -q "$service" && echo "active" || echo "inactive"
            ;;
        rc)
            service "$service" status >/dev/null 2>&1 && echo "active" || echo "inactive"
            ;;
        *)
            return 1
            ;;
    esac
}

# Start service abstraction
system_api_start_service() {
    local service="$1"
    local service_manager="${2:-$(system_api_get_service_manager)}"
    
    case "$service_manager" in
        systemd)
            systemctl start "$service"
            ;;
        sysv)
            service "$service" start
            ;;
        openrc)
            rc-service "$service" start
            ;;
        launchd)
            launchctl load -w "/System/Library/LaunchDaemons/${service}.plist" 2>/dev/null || \
            launchctl load -w "/Library/LaunchDaemons/${service}.plist" 2>/dev/null
            ;;
        rc)
            service "$service" start
            ;;
        *)
            return 1
            ;;
    esac
}

# Stop service abstraction
system_api_stop_service() {
    local service="$1"
    local service_manager="${2:-$(system_api_get_service_manager)}"
    
    case "$service_manager" in
        systemd)
            systemctl stop "$service"
            ;;
        sysv)
            service "$service" stop
            ;;
        openrc)
            rc-service "$service" stop
            ;;
        launchd)
            launchctl unload -w "/System/Library/LaunchDaemons/${service}.plist" 2>/dev/null || \
            launchctl unload -w "/Library/LaunchDaemons/${service}.plist" 2>/dev/null
            ;;
        rc)
            service "$service" stop
            ;;
        *)
            return 1
            ;;
    esac
}

# ================================
# Process Management Interface
# ================================

# List processes abstraction
system_api_list_processes() {
    local options="${1:-aux}"
    
    case "$SYSTEM_PLATFORM" in
        Linux|FreeBSD)
            ps $options
            ;;
        Darwin)
            # macOS ps has different options
            ps -A -o pid,ppid,user,comm,args
            ;;
        *)
            return 1
            ;;
    esac
}

# Get process info abstraction
system_api_get_process_info() {
    local pid="$1"
    local field="${2:-all}"
    
    case "$SYSTEM_PLATFORM" in
        Linux)
            if [[ "$field" == "all" ]]; then
                ps -p "$pid" -o pid,ppid,user,comm,args,pcpu,pmem,etime,state
            else
                ps -p "$pid" -o "$field=" 2>/dev/null
            fi
            ;;
        Darwin)
            if [[ "$field" == "all" ]]; then
                ps -p "$pid" -o pid,ppid,user,comm,args,%cpu,%mem,etime,state
            else
                ps -p "$pid" -o "$field=" 2>/dev/null
            fi
            ;;
        FreeBSD)
            if [[ "$field" == "all" ]]; then
                ps -p "$pid" -o pid,ppid,user,comm,args,pcpu,pmem,etime,state
            else
                ps -p "$pid" -o "$field=" 2>/dev/null
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# Kill process abstraction
system_api_kill_process() {
    local pid="$1"
    local signal="${2:-TERM}"
    
    kill -"$signal" "$pid" 2>/dev/null
}

# ================================
# File System Interface
# ================================

# Get file system info abstraction
system_api_get_filesystem_info() {
    local path="${1:-/}"
    
    case "$SYSTEM_PLATFORM" in
        Linux|FreeBSD)
            df -h "$path" 2>/dev/null | tail -n1
            ;;
        Darwin)
            df -h "$path" 2>/dev/null | tail -n1
            ;;
        *)
            return 1
            ;;
    esac
}

# Get directory size abstraction
system_api_get_directory_size() {
    local path="$1"
    local human_readable="${2:-true}"
    
    if [[ "$human_readable" == "true" ]]; then
        du -sh "$path" 2>/dev/null | cut -f1
    else
        du -s "$path" 2>/dev/null | cut -f1
    fi
}

# Find files abstraction
system_api_find_files() {
    local path="$1"
    local pattern="$2"
    local type="${3:-f}"  # f for files, d for directories
    
    find "$path" -type "$type" -name "$pattern" 2>/dev/null
}

# ================================
# Network Interface
# ================================

# Get network interfaces abstraction
system_api_get_network_interfaces() {
    case "$SYSTEM_PLATFORM" in
        Linux)
            ip link show 2>/dev/null || ifconfig -a 2>/dev/null
            ;;
        Darwin|FreeBSD)
            ifconfig -a 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Get listening ports abstraction
system_api_get_listening_ports() {
    case "$SYSTEM_PLATFORM" in
        Linux)
            ss -tuln 2>/dev/null || netstat -tuln 2>/dev/null
            ;;
        Darwin)
            lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null
            ;;
        FreeBSD)
            sockstat -l 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# ================================
# System Information Interface
# ================================

# Get system uptime abstraction
system_api_get_uptime() {
    case "$SYSTEM_PLATFORM" in
        Linux|Darwin|FreeBSD)
            uptime
            ;;
        *)
            return 1
            ;;
    esac
}

# Get memory info abstraction
system_api_get_memory_info() {
    case "$SYSTEM_PLATFORM" in
        Linux)
            free -h 2>/dev/null || cat /proc/meminfo 2>/dev/null
            ;;
        Darwin)
            vm_stat 2>/dev/null
            ;;
        FreeBSD)
            freecolor -m 2>/dev/null || sysctl hw.physmem hw.usermem 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Get CPU info abstraction
system_api_get_cpu_info() {
    case "$SYSTEM_PLATFORM" in
        Linux)
            lscpu 2>/dev/null || cat /proc/cpuinfo 2>/dev/null
            ;;
        Darwin)
            sysctl -n machdep.cpu.brand_string 2>/dev/null
            ;;
        FreeBSD)
            sysctl hw.model hw.ncpu 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Initialize the API on source
init_system_api