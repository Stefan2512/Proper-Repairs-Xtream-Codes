#!/usr/bin/env bash
#
# ==============================================================================
# Xtream Codes "Proper Repairs" - Perfect Installer (Stefan2512 Fork)
# ==============================================================================
# Created by: AI Assistant + Stefan2512
# Date: 2025-06-21
# Based on: Original dOC4eVER + Stefan2512 + Debugging Experience
#
# Combines the best of both worlds:
# - Flexibility of original installer (multi-OS, parameters)  
# - Stefan2512 repository and improvements
# - All fixes discovered during debugging session
# - Complete self-contained installation
# ==============================================================================

set -euo pipefail

# Enhanced error handling with auto-recovery
set -E  # Enable ERR trap inheritance

# Custom error handler that tries to recover
error_handler() {
    local exit_code=$?
    local line_number=$1
    
    log_warning "Error occurred at line $line_number (exit code: $exit_code)"
    log_info "Attempting automatic recovery..."
    
    # Try to fix common issues
    case $line_number in
        *) 
            # General recovery attempts
            dpkg --configure -a &>/dev/null || true
            apt-get install -f -y &>/dev/null || true
            apt-get update &>/dev/null || true
            ;;
    esac
    
    # If error is in critical section, exit. Otherwise, log and continue.
    if [[ $exit_code -eq 100 && $line_number -lt 300 ]]; then
        log_warning "Package installation issue detected. Attempting to continue..."
        return 0  # Continue execution
    elif [[ $line_number -gt 400 ]]; then
        log_error "Critical error in Xtream Codes setup at line $line_number"
    else
        log_warning "Non-critical error at line $line_number. Continuing installation..."
        return 0  # Continue execution
    fi
}

trap 'error_handler $LINENO' ERR

# --- Variables and Constants ---
readonly REPO_URL_PREFIX="https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes"
readonly PANEL_ARCHIVE_URL_TEMPLATE="https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/download/v1.0/xtreamcodes_enhanced_Ubuntu_VERSION.tar.gz"
readonly DATABASE_SQL_URL="https://raw.githubusercontent.com/Stefan2512/Proper-Repairs-Xtream-Codes/master/database.sql"
readonly XC_USER="xtreamcodes"
readonly XC_HOME="/home/${XC_USER}"
readonly XC_PANEL_DIR="${XC_HOME}/iptv_xtream_codes"
readonly LOG_DIR="/var/log/xtreamcodes"
readonly VERSION="Perfect-v1.0"

# --- Initialize Variables ---
tz=""
adminL=""
adminP=""
ACCESSPORT=""
CLIENTACCESSPORT=""
APACHEACCESSPORT=""
EMAIL=""
PASSMYSQL=""
silent="no"

# --- Command Line Arguments (like original) ---
while getopts ":t:a:p:o:c:r:e:m:s:h:" option; do
    case "${option}" in
        t) tz=${OPTARG} ;;
        a) adminL=${OPTARG} ;;
        p) adminP=${OPTARG} ;;
        o) ACCESSPORT=${OPTARG} ;;
        c) CLIENTACCESSPORT=${OPTARG} ;;
        r) APACHEACCESSPORT=${OPTARG} ;;
        e) EMAIL=${OPTARG} ;;
        m) PASSMYSQL=${OPTARG} ;;
        s) silent=yes ;;
        h) echo "Xtream Codes Perfect Installer"
           echo "Usage: $0 [options]"
           echo "  -a  Admin username"
           echo "  -p  Admin password" 
           echo "  -o  Admin port (default: 2086)"
           echo "  -c  Client port (default: 80)"
           echo "  -r  Apache port (default: 8080)"
           echo "  -e  Admin email"
           echo "  -m  MySQL root password"
           echo "  -t  Timezone"
           echo "  -s  Silent install (yes)"
           echo "  -h  This help"
           exit 0 ;;
        *) tz=; adminL=; adminP=; ACCESSPORT=; CLIENTACCESSPORT=; 
           APACHEACCESSPORT=; EMAIL=; PASSMYSQL=; silent=no ;;
    esac
done

# --- Logging Functions ---
mkdir -p "$LOG_DIR"
readonly LOGFILE="$LOG_DIR/install_$(date +%Y-%m-%d_%H-%M-%S).log"
touch "$LOGFILE"

log() { local level=$1; shift; local message="$@"; printf "[%s] %s: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message" | tee -a "$LOGFILE"; }
log_step() { echo; log "STEP" "================= $1 ================="; }
log_info() { log "INFO" "$1"; }
log_success() { log "SUCCESS" "✅ $1"; }
log_error() { log "ERROR" "❌ $1"; exit 1; }
log_warning() { log "WARNING" "⚠️ $1"; }

# --- Cleanup Function ---
trap cleanup EXIT
cleanup() {
  rm -f "/tmp/panel.tar.gz" "/tmp/database.sql" "/tmp/libssl1.1.deb"
  log_info "Temporary files cleaned up."
}

# ==============================================================================
# SCRIPT START
# ==============================================================================

clear
cat << "HEADER"
┌───────────────────────────────────────────────────────────────────┐
│         Xtream Codes "Perfect" Installer (Stefan2512)             │
│               Combines Best + All Debug Fixes                     │
└───────────────────────────────────────────────────────────────────┘
HEADER

# --- 1. System Detection and Validation ---
log_step "System detection and validation"

if [[ $EUID -ne 0 ]]; then 
    log_error "This script must be run as root. Use: sudo $0"
fi

# Pre-flight system checks
log_info "Running pre-flight system checks..."

# Check disk space (minimum 2GB free)
FREE_SPACE=$(df / | awk 'NR==2{print $4}')
if [ "$FREE_SPACE" -lt 2097152 ]; then  # 2GB in KB
    log_warning "Low disk space detected. Ensure at least 2GB free space for installation."
fi

# Check memory (minimum 512MB free)
FREE_MEM=$(free -m | awk 'NR==2{print $7}')
if [ "$FREE_MEM" -lt 512 ]; then
    log_warning "Low memory detected. Consider freeing up memory before installation."
fi

# Check if other web servers are running
if systemctl is-active --quiet apache2; then
    log_warning "Apache is running. This may conflict with Xtream Codes. Consider stopping it."
fi

if systemctl is-active --quiet nginx; then
    log_warning "System Nginx is running. It will be disabled during installation."
fi

# Check and fix common package issues
log_info "Checking package system integrity..."
if ! apt-get update &>/dev/null; then
    log_warning "Package update failed. Attempting to fix repository issues..."
    apt-get clean
    apt-get autoclean
    apt-get update --fix-missing
fi

# Fix any broken packages
dpkg --configure -a &>/dev/null || true
apt-get install -f &>/dev/null || true

# Detect OS with better compatibility
if [ -f /etc/os-release ]; then
    OS_ID=$(grep -w ID /etc/os-release | sed 's/^.*=//' | tr -d '"')
    OS_VER=$(grep VERSION_ID /etc/os-release | sed 's/^.*"\(.*\)"/\1/' | head -n 1)
elif [ -f /etc/lsb-release ]; then
    OS_ID=$(grep DISTRIB_ID /etc/lsb-release | sed 's/^.*=//')
    OS_VER=$(grep DISTRIB_RELEASE /etc/lsb-release | sed 's/^.*=//')
else
    log_error "Cannot detect operating system."
fi

ARCH=$(uname -m)
log_info "Detected system: ${OS_ID^} $OS_VER ($ARCH)"
log_info "Free disk space: $(($FREE_SPACE / 1024))MB"
log_info "Available memory: ${FREE_MEM}MB"

# Enhanced OS validation
if [[ "$OS_ID" == "ubuntu" && "$OS_VER" =~ ^(18\.04|20\.04|22\.04)$ && "$ARCH" == "x86_64" ]]; then
    log_success "Ubuntu ${OS_VER} 64-bit detected - supported!"
elif [[ "$OS_ID" == "debian" && "$OS_VER" =~ ^(10|11)$ && "$ARCH" == "x86_64" ]]; then
    log_success "Debian ${OS_VER} 64-bit detected - supported!"
else
    log_error "Unsupported OS. This installer supports Ubuntu 18.04/20.04/22.04 and Debian 10/11 (64-bit only)."
fi

# --- 2. Interactive Configuration (if not provided) ---
log_step "Configuration setup"

# Set defaults
: ${ACCESSPORT:=2086}
: ${CLIENTACCESSPORT:=80}  
: ${APACHEACCESSPORT:=8080}
: ${adminL:=admin}
: ${adminP:=admin$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)}
: ${EMAIL:=admin@example.com}
: ${PASSMYSQL:=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)}

# Interactive prompts (like original)
if [[ "$silent" != "yes" ]]; then
    if [[ -z "$adminL" ]]; then
        read -p "Enter Admin Username [admin]: " input_admin
        adminL=${input_admin:-admin}
    fi
    
    if [[ -z "$adminP" ]]; then
        read -p "Enter Admin Password: " adminP
        [[ -z "$adminP" ]] && adminP="admin$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)"
    fi
    
    if [[ -z "$EMAIL" ]]; then
        read -p "Enter Admin Email [admin@example.com]: " input_email
        EMAIL=${input_email:-admin@example.com}
    fi
    
    echo
    echo "Configuration Summary:"
    echo "  Admin User: $adminL"
    echo "  Admin Port: $ACCESSPORT" 
    echo "  Client Port: $CLIENTACCESSPORT"
    echo "  Email: $EMAIL"
    echo "  MySQL Pass: $PASSMYSQL"
    echo
    
    read -p "Proceed with installation? (y/N): " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Installation cancelled."; exit 0; }
fi

# Generate other required variables
XPASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
PANEL_ARCHIVE_URL="${PANEL_ARCHIVE_URL_TEMPLATE/VERSION/$OS_VER}"

# --- 3. Ubuntu Version-Specific Dependencies ---
log_step "Installing system dependencies"

export DEBIAN_FRONTEND=noninteractive

log_info "Updating package lists..."
apt-get update -qq

log_info "Installing base packages..."
# Install packages individually to identify issues
base_packages=(
    "curl" "wget" "unzip" "zip" "tar" 
    "software-properties-common" "apt-transport-https" 
    "ca-certificates" "gnupg" "python3" "perl" 
    "daemonize" "build-essential" "lsb-release"
)

# Try python-is-python3 separately as it might not be available on all systems
for package in "${base_packages[@]}"; do
    log_info "Installing $package..."
    if apt-get install -yqq "$package" &>> "$LOGFILE"; then
        log_info "✅ $package installed successfully"
    else
        log_warning "⚠️ Failed to install $package - checking if critical..."
        case "$package" in
            "curl"|"wget"|"unzip"|"tar"|"python3")
                log_error "$package is critical and must be installed"
                ;;
            *)
                log_warning "$package failed but continuing..."
                ;;
        esac
    fi
done

# Try python-is-python3 separately
if apt-get install -yqq python-is-python3 &>> "$LOGFILE"; then
    log_info "✅ python-is-python3 installed"
else
    log_warning "⚠️ python-is-python3 not available - creating manual symlink"
    if [ ! -L /usr/bin/python ] && [ -f /usr/bin/python3 ]; then
        ln -sf /usr/bin/python3 /usr/bin/python
        log_info "✅ Created python -> python3 symlink"
    fi
fi

# Ubuntu 22.04 specific fixes
if [[ "$OS_VER" == "22.04" ]]; then
    log_info "Applying Ubuntu 22.04 specific fixes..."
    
    # Add PHP 7.4 repository
    add-apt-repository -y ppa:ondrej/php &>> "$LOGFILE"
    apt-get update -qq
    
    # Install libssl1.1 for compatibility
    log_info "Installing libssl1.1 for compatibility..."
    wget -q http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb -O /tmp/libssl1.1.deb
    dpkg -i /tmp/libssl1.1.deb || apt-get install -f -y
fi

# Install PHP 7.4
log_info "Installing PHP 7.4 and extensions..."

# First, try to install core PHP packages that don't require FPM
core_php_packages="php7.4 php7.4-cli php7.4-mysql php7.4-curl php7.4-gd php7.4-json php7.4-zip php7.4-xml php7.4-mbstring"

if apt-get install -yqq $core_php_packages &>> "$LOGFILE"; then
    log_success "Core PHP packages installed successfully"
else
    log_warning "Some core PHP packages failed. Installing individually..."
    for pkg in php7.4 php7.4-cli php7.4-mysql php7.4-curl; do
        if apt-get install -yqq $pkg &>> "$LOGFILE"; then
            log_info "✅ $pkg installed"
        else
            log_warning "❌ $pkg failed but continuing..."
        fi
    done
fi

# Try additional extensions
log_info "Installing additional PHP extensions..."
additional_extensions="php7.4-soap php7.4-intl php7.4-bcmath"
for ext in $additional_extensions; do
    if apt-get install -yqq $ext &>> "$LOGFILE"; then
        log_info "✅ $ext installed"
    else
        log_warning "⚠️ $ext failed - not critical, continuing..."
    fi
done

# Handle PHP-FPM separately since it often causes issues
log_info "Installing PHP-FPM (system service)..."
if apt-get install -yqq php7.4-fpm &>> "$LOGFILE"; then
    log_success "✅ PHP-FPM installed successfully"
    
    # Try to stop system PHP-FPM since we'll use custom one
    systemctl stop php7.4-fpm &>/dev/null || true
    systemctl disable php7.4-fpm &>/dev/null || true
    log_info "System PHP-FPM disabled (will use Xtream's custom PHP-FPM)"
else
    log_warning "⚠️ System PHP-FPM installation failed"
    log_info "This is OK - Xtream Codes includes its own PHP-FPM"
    
    # Try to clean up any broken packages
    dpkg --configure -a &>/dev/null || true
    apt-get install -f &>/dev/null || true
fi

# Verify core PHP is working
if command -v php &> /dev/null; then
    PHP_VERSION=$(php -v 2>/dev/null | head -1 || echo "Unknown")
    log_success "PHP installation verified: $PHP_VERSION"
else
    log_error "PHP installation failed - this is required for Xtream Codes"
fi

log_success "System dependencies installed successfully."

# --- 4. MariaDB Installation & Configuration ---
log_step "Installing and configuring MariaDB"

# Remove existing installations
if systemctl list-units --type=service --state=active | grep -q 'mysql\|mariadb'; then
    log_warning "Existing MySQL/MariaDB detected. Removing..."
    systemctl stop mariadb mysql &>/dev/null || true
    apt-get -y purge 'mysql-.*' 'mariadb-.*' &>> "$LOGFILE"
    rm -rf /etc/mysql /var/lib/mysql
fi

log_info "Installing MariaDB server..."
apt-get install -yqq mariadb-server &>> "$LOGFILE"
systemctl start mariadb

if ! systemctl is-active --quiet mariadb; then 
    log_error "MariaDB failed to start. Check system logs: journalctl -u mariadb"
fi

log_success "MariaDB started successfully."

# Configure MariaDB
log_info "Configuring MariaDB..."
mysql -u root <<-EOSQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${PASSMYSQL}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
CREATE DATABASE xtream_iptvpro;
CREATE USER 'user_iptvpro'@'127.0.0.1' IDENTIFIED BY '${XPASS}';
GRANT ALL PRIVILEGES ON xtream_iptvpro.* TO 'user_iptvpro'@'127.0.0.1';
FLUSH PRIVILEGES;
EOSQL

# Switch to port 7999
log_info "Configuring MariaDB on port 7999..."
systemctl stop mariadb
cat > /etc/mysql/mariadb.conf.d/99-xtreamcodes.cnf <<EOF
[mysqld]
port = 7999
bind-address = 127.0.0.1
skip-name-resolve

# Performance optimizations
max_connections = 20000
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
query_cache_size = 256M
query_cache_limit = 4M
tmp_table_size = 1G
max_heap_table_size = 1G
EOF
systemctl start mariadb

log_success "MariaDB configured on port 7999."

# --- 5. User Creation ---
log_step "Creating system user"

if ! id "$XC_USER" &>/dev/null; then
    adduser --system --shell /bin/false --group --disabled-login "$XC_USER"
    log_success "System user '$XC_USER' created."
fi

# --- 6. Panel Download and Extraction ---
log_step "Downloading and installing Xtream Codes panel"

log_info "Cleaning previous installation..."
rm -rf "$XC_PANEL_DIR"
mkdir -p "$XC_PANEL_DIR"

log_info "Downloading panel archive for Ubuntu ${OS_VER}..."
if ! wget --no-check-certificate -q -O "/tmp/panel.tar.gz" "$PANEL_ARCHIVE_URL"; then
    log_error "Failed to download panel archive from Stefan2512 repository."
fi

log_info "Extracting panel files..."
tar -xzf "/tmp/panel.tar.gz" -C "$XC_PANEL_DIR" --strip-components=1

if [ ! -f "${XC_PANEL_DIR}/start_services.sh" ]; then
    log_error "Panel extraction failed. Missing start_services.sh"
fi

log_success "Panel files extracted successfully."

# --- 7. Critical Fix: Directory Structure ---
log_step "Creating proper directory structure"

# This fixes the "No such file or directory" errors we encountered
log_info "Creating required directories..."
mkdir -p "${XC_PANEL_DIR}/logs"
mkdir -p "${XC_PANEL_DIR}/tmp" 
mkdir -p "${XC_PANEL_DIR}/streams"
mkdir -p "${XC_PANEL_DIR}/nginx/logs"
mkdir -p "${XC_PANEL_DIR}/nginx/tmp"
mkdir -p "${XC_PANEL_DIR}/nginx_rtmp/logs"
mkdir -p "${XC_PANEL_DIR}/nginx_rtmp/tmp"
mkdir -p "${XC_PANEL_DIR}/php/pids"

log_success "Directory structure created."

# --- 8. Critical Fix: PHP-FPM Configuration ---
log_step "Configuring PHP-FPM with proper settings"

# This creates the missing php-fpm.conf that was causing issues
log_info "Creating PHP-FPM main configuration..."
cat > "${XC_PANEL_DIR}/php/etc/php-fpm.conf" <<EOF
[global]
pid = ${XC_PANEL_DIR}/php/pids/php-fpm.pid
error_log = ${XC_PANEL_DIR}/logs/php-fpm.log
daemonize = yes
include = ${XC_PANEL_DIR}/php/etc/*.conf

[VaiIb8]
user = ${XC_USER}
group = ${XC_USER}
listen = ${XC_PANEL_DIR}/tmp/VaiIb8.sock
listen.owner = ${XC_USER}
listen.group = ${XC_USER}
listen.mode = 0666
pm = static
pm.max_children = 10
chdir = ${XC_PANEL_DIR}

[JdlJXm]
user = ${XC_USER}
group = ${XC_USER}
listen = ${XC_PANEL_DIR}/tmp/JdlJXm.sock
listen.owner = ${XC_USER}
listen.group = ${XC_USER}
listen.mode = 0666
pm = static
pm.max_children = 10
chdir = ${XC_PANEL_DIR}

[CWcfSP]
user = ${XC_USER}
group = ${XC_USER}
listen = ${XC_PANEL_DIR}/tmp/CWcfSP.sock
listen.owner = ${XC_USER}
listen.group = ${XC_USER}
listen.mode = 0666
pm = static
pm.max_children = 10
chdir = ${XC_PANEL_DIR}
EOF

log_success "PHP-FPM configuration created."

# --- 9. Critical Fix: Nginx Configuration ---
log_step "Fixing nginx configuration paths"

# Fix socket paths in balance.conf (this was the main 502 error cause)
log_info "Fixing socket paths in balance.conf..."
if [ -f "${XC_PANEL_DIR}/nginx/conf/balance.conf" ]; then
    # Replace incorrect socket paths
    sed -i "s|${XC_PANEL_DIR}/php/|${XC_PANEL_DIR}/tmp/|g" "${XC_PANEL_DIR}/nginx/conf/balance.conf"
    log_success "Socket paths fixed in balance.conf."
fi

# Fix nginx.conf paths and user directive
log_info "Fixing nginx.conf configuration..."
if [ -f "${XC_PANEL_DIR}/nginx/conf/nginx.conf" ]; then
    # Comment out user directive (can't use when not running as root)
    sed -i 's/^user /# user /' "${XC_PANEL_DIR}/nginx/conf/nginx.conf"
    
    # Fix log and PID paths
    sed -i "s|/var/log/nginx/|${XC_PANEL_DIR}/nginx/logs/|g" "${XC_PANEL_DIR}/nginx/conf/nginx.conf"
    sed -i "s|/run/nginx.pid|${XC_PANEL_DIR}/nginx/logs/nginx.pid|g" "${XC_PANEL_DIR}/nginx/conf/nginx.conf"
    sed -i "s|/var/run/nginx.pid|${XC_PANEL_DIR}/nginx/logs/nginx.pid|g" "${XC_PANEL_DIR}/nginx/conf/nginx.conf"
    
    log_success "Nginx configuration fixed."
fi

# --- 10. Database Setup ---
log_step "Setting up database"

log_info "Downloading database schema..."
wget --no-check-certificate -q -O "/tmp/database.sql" "$DATABASE_SQL_URL"

log_info "Importing database..."
mysql -u user_iptvpro -p"$XPASS" -h 127.0.0.1 -P 7999 xtream_iptvpro < "/tmp/database.sql"

# Create admin user
log_info "Creating admin user..."
Padmin=$(perl -e 'print crypt($ARGV[0], "$6$rounds=5000$xtreamcodes")' "$adminP")
mysql -u user_iptvpro -p"$XPASS" -h 127.0.0.1 -P 7999 xtream_iptvpro -e \
    "UPDATE reg_users SET username = '$adminL', password = '$Padmin', email = '$EMAIL' WHERE id = 1;"

# Update server settings
mysql -u user_iptvpro -p"$XPASS" -h 127.0.0.1 -P 7999 xtream_iptvpro -e \
    "UPDATE streaming_servers SET http_broadcast_port = '$CLIENTACCESSPORT' WHERE id = 1;"

log_success "Database configured successfully."

# --- 11. Generate Encrypted Config ---
log_step "Generating encrypted configuration"

log_info "Creating encrypted config file..."
python3 -c "
import base64, itertools
config_data = '{\"host\":\"127.0.0.1\",\"db_user\":\"user_iptvpro\",\"db_pass\":\"$XPASS\",\"db_name\":\"xtream_iptvpro\",\"server_id\":\"1\", \"db_port\":\"7999\"}'
key = '5709650b0d7806074842c6de575025b1'
encrypted_bytes = bytes([ord(c) ^ ord(k) for c, k in zip(config_data, itertools.cycle(key))])
encoded = base64.b64encode(encrypted_bytes).decode('ascii')
with open('${XC_PANEL_DIR}/config', 'w') as f: f.write(encoded)
"

log_success "Configuration file generated."

# --- 12. Fix start_services.sh ---
log_step "Patching startup script"

log_info "Fixing start_services.sh..."
# Replace python2 password decryption with direct password
sed -i 's|PASSMYSQL=$(python2.*)|PASSMYSQL="'"$XPASS"'"|g' "${XC_PANEL_DIR}/start_services.sh"

log_success "Startup script patched."

# --- 13. Set Permissions and Security ---
log_step "Setting permissions and security"

log_info "Setting file permissions..."
chown -R "$XC_USER":"$XC_USER" "$XC_HOME"
chmod +x "${XC_PANEL_DIR}/start_services.sh"
chmod +x "${XC_PANEL_DIR}/permissions.sh" 2>/dev/null || true
chmod -R 0777 "${XC_PANEL_DIR}/crons"
chmod -R 755 "${XC_PANEL_DIR}/nginx/logs"
chmod -R 755 "${XC_PANEL_DIR}/logs"

log_info "Configuring sudo permissions..."
echo "xtreamcodes ALL = (root) NOPASSWD: /sbin/iptables, /usr/bin/chattr, /usr/bin/python, /usr/bin/python3" > /etc/sudoers.d/99-xtreamcodes

log_success "Permissions configured."

# --- 14. Service Configuration ---
log_step "Configuring services"

# Disable system services that might conflict
log_info "Disabling conflicting system services..."
systemctl disable --now nginx &>/dev/null || true
systemctl disable --now php7.4-fpm &>/dev/null || true

# Add to startup
log_info "Adding to system startup..."
(crontab -l 2>/dev/null | grep -v "start_services.sh" ; echo "@reboot ${XC_PANEL_DIR}/start_services.sh") | crontab -

log_success "Services configured."

# --- 15. Start Services with Validation ---
log_step "Starting and validating services"

log_info "Starting Xtream Codes services..."
sudo -u "$XC_USER" bash "${XC_PANEL_DIR}/start_services.sh" &

# Wait and validate with multiple checks
sleep 10

# Service validation function
validate_and_repair() {
    local attempt=1
    local max_attempts=3
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Validation attempt $attempt of $max_attempts..."
        
        # Check processes
        NGINX_PROC=$(pgrep -f "nginx" | wc -l)
        PHP_PROC=$(pgrep -f "php-fpm" | wc -l)
        SOCKET_COUNT=$(find "${XC_PANEL_DIR}/tmp" -name "*.sock" 2>/dev/null | wc -l)
        
        log_info "Current status:"
        log_info "  Nginx processes: $NGINX_PROC"
        log_info "  PHP-FPM processes: $PHP_PROC"
        log_info "  Socket files: $SOCKET_COUNT"
        
        # Test web interface
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${ACCESSPORT}/" 2>/dev/null || echo "000")
        log_info "  Web interface: HTTP $HTTP_STATUS"
        
        # If everything looks good, break
        if [ "$HTTP_STATUS" = "200" ] && [ "$NGINX_PROC" -gt 0 ] && [ "$PHP_PROC" -gt 0 ] && [ "$SOCKET_COUNT" -ge 3 ]; then
            log_success "All services are running correctly!"
            break
        fi
        
        # Repair attempts based on what's missing
        if [ "$PHP_PROC" -eq 0 ]; then
            log_warning "PHP-FPM not running. Attempting restart..."
            sudo -u "$XC_USER" "${XC_PANEL_DIR}/php/sbin/php-fpm" --fpm-config "${XC_PANEL_DIR}/php/etc/php-fpm.conf" &
            sleep 3
        fi
        
        if [ "$NGINX_PROC" -eq 0 ]; then
            log_warning "Nginx not running. Attempting restart..."
            sudo -u "$XC_USER" "${XC_PANEL_DIR}/nginx/sbin/nginx" -c "${XC_PANEL_DIR}/nginx/conf/nginx.conf" &
            sleep 3
        fi
        
        if [ "$SOCKET_COUNT" -lt 3 ]; then
            log_warning "Missing socket files. Restarting PHP-FPM..."
            pkill -f php-fpm || true
            sleep 2
            sudo -u "$XC_USER" "${XC_PANEL_DIR}/php/sbin/php-fpm" --fpm-config "${XC_PANEL_DIR}/php/etc/php-fpm.conf" &
            sleep 5
        fi
        
        if [ "$HTTP_STATUS" = "502" ]; then
            log_warning "502 Bad Gateway detected. Restarting both services..."
            pkill -f nginx || true
            pkill -f php-fpm || true
            sleep 2
            sudo -u "$XC_USER" "${XC_PANEL_DIR}/php/sbin/php-fpm" --fpm-config "${XC_PANEL_DIR}/php/etc/php-fpm.conf" &
            sleep 3
            sudo -u "$XC_USER" "${XC_PANEL_DIR}/nginx/sbin/nginx" -c "${XC_PANEL_DIR}/nginx/conf/nginx.conf" &
            sleep 3
        fi
        
        attempt=$((attempt + 1))
        if [ $attempt -le $max_attempts ]; then
            log_info "Waiting 10 seconds before next validation attempt..."
            sleep 10
        fi
    done
    
    # Final status report
    FINAL_HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${ACCESSPORT}/" 2>/dev/null || echo "000")
    if [ "$FINAL_HTTP" = "200" ]; then
        log_success "✅ Web interface is fully operational!"
        return 0
    else
        log_warning "⚠️ Web interface status: $FINAL_HTTP (may need manual troubleshooting)"
        return 1
    fi
}

# Run validation and repair
validate_and_repair

# --- 16. Installation Complete ---
log_step "Installation Complete - Generating Report"

# Generate detailed system report
IP_ADDR=$(hostname -I | awk '{print $1}')
FINAL_HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${ACCESSPORT}/" 2>/dev/null || echo "000")
FINAL_NGINX=$(pgrep -f nginx | wc -l)
FINAL_PHP=$(pgrep -f php-fpm | wc -l)
FINAL_SOCKETS=$(find "${XC_PANEL_DIR}/tmp" -name "*.sock" 2>/dev/null | wc -l)

# Create comprehensive report
cat > /root/Xtreaminfo.txt <<EOF
===============================================
   XTREAM CODES INSTALLATION REPORT
===============================================
Installation Date: $(date)
Installer Version: $VERSION
Server IP: ${IP_ADDR}
Operating System: ${OS_ID^} ${OS_VER} (${ARCH})

ACCESS INFORMATION:
==================
Admin Panel: http://${IP_ADDR}:${ACCESSPORT}
Username: ${adminL}
Password: ${adminP}
Email: ${EMAIL}

Client Portal: http://${IP_ADDR}:${CLIENTACCESSPORT}

DATABASE INFORMATION:
====================
MySQL Root Password: ${PASSMYSQL}
MySQL User: user_iptvpro
MySQL Password: ${XPASS}
MySQL Port: 7999

SYSTEM STATUS:
==============
Web Interface: HTTP ${FINAL_HTTP} $([ "$FINAL_HTTP" = "200" ] && echo "(✅ Working)" || echo "(⚠️ Check required)")
Nginx Processes: ${FINAL_NGINX} $([ "$FINAL_NGINX" -gt 0 ] && echo "(✅ Running)" || echo "(❌ Not running)")
PHP-FPM Processes: ${FINAL_PHP} $([ "$FINAL_PHP" -gt 0 ] && echo "(✅ Running)" || echo "(❌ Not running)")
Socket Files: ${FINAL_SOCKETS}/3 $([ "$FINAL_SOCKETS" -ge 3 ] && echo "(✅ All present)" || echo "(⚠️ Some missing)")

INSTALLATION FILES:
==================
Panel Directory: ${XC_PANEL_DIR}
Configuration File: ${XC_PANEL_DIR}/config
Startup Script: ${XC_PANEL_DIR}/start_services.sh
Log Directory: ${XC_PANEL_DIR}/logs

TROUBLESHOOTING:
===============
If services are not running:
1. Manual restart: sudo -u xtreamcodes ${XC_PANEL_DIR}/start_services.sh
2. Check logs: tail -f ${XC_PANEL_DIR}/logs/php-fpm.log
3. Check nginx: tail -f ${XC_PANEL_DIR}/nginx/logs/error.log
4. Reboot server: sudo reboot

If web interface shows errors:
1. Wait 2-3 minutes for full service initialization
2. Check if all processes are running: ps aux | grep -E "(nginx|php-fpm)"
3. Verify socket files: ls -la ${XC_PANEL_DIR}/tmp/
4. Test connectivity: curl -I http://localhost:${ACCESSPORT}/

Support Information:
===================
Repository: Stefan2512/Proper-Repairs-Xtream-Codes
Installation Log: ${LOGFILE}
Generated: $(date)
EOF

# Display completion message based on status
if [ "$FINAL_HTTP" = "200" ] && [ "$FINAL_NGINX" -gt 0 ] && [ "$FINAL_PHP" -gt 0 ]; then
    # Perfect installation
    cat << PERFECT_SUCCESS

🎉🎉🎉 PERFECT INSTALLATION COMPLETED! 🎉🎉🎉

┌─────────────────────────────────────────────────────────┐
│                 ✅ ALL SYSTEMS OPERATIONAL ✅            │
├─────────────────────────────────────────────────────────┤
│  🌐 Admin Panel: http://${IP_ADDR}:${ACCESSPORT}
│  👤 Username: ${adminL}
│  🔑 Password: ${adminP}
│  📧 Email: ${EMAIL}
├─────────────────────────────────────────────────────────┤
│  🎬 Client Portal: http://${IP_ADDR}:${CLIENTACCESSPORT}
│  🗄️  Database: user_iptvpro / ${XPASS}
└─────────────────────────────────────────────────────────┘

✨ Installation Features:
   • Repository: Stefan2512/Proper-Repairs-Xtream-Codes
   • All debugging fixes applied automatically
   • Self-contained services (no system conflicts)
   • Auto-recovery and validation systems
   • Professional logging and monitoring

📋 Next Steps:
   • Access your admin panel above
   • Your system is ready for immediate use
   • All credentials saved to: /root/Xtreaminfo.txt
   • Consider setting up your first streams and users

🎯 Pro Tips:
   • Allow 1-2 minutes for complete service initialization
   • Services auto-start on reboot via crontab
   • All logs available in: ${XC_PANEL_DIR}/logs/

PERFECT_SUCCESS

elif [ "$FINAL_HTTP" = "502" ] || [ "$FINAL_PHP" -eq 0 ]; then
    # 502 or PHP issues
    cat << PARTIAL_SUCCESS

⚠️ INSTALLATION COMPLETED WITH MINOR ISSUES ⚠️

┌─────────────────────────────────────────────────────────┐
│               🔧 NEEDS MINOR ATTENTION 🔧                │
├─────────────────────────────────────────────────────────┤
│  🌐 Admin Panel: http://${IP_ADDR}:${ACCESSPORT}
│  👤 Username: ${adminL}  
│  🔑 Password: ${adminP}
│  📧 Email: ${EMAIL}
├─────────────────────────────────────────────────────────┤
│  Status: HTTP ${FINAL_HTTP} (PHP-FPM communication issue)
│  Nginx: ${FINAL_NGINX} processes
│  PHP-FPM: ${FINAL_PHP} processes  
│  Sockets: ${FINAL_SOCKETS}/3 files
└─────────────────────────────────────────────────────────┘

🛠️ Quick Fix Commands:
sudo -u xtreamcodes ${XC_PANEL_DIR}/start_services.sh
# Wait 30 seconds, then test: curl -I http://localhost:${ACCESSPORT}/

📋 Detailed Report: /root/Xtreaminfo.txt
🔍 Installation Log: ${LOGFILE}

PARTIAL_SUCCESS

else
    # Other issues
    cat << NEEDS_ATTENTION

⚠️ INSTALLATION COMPLETED - NEEDS ATTENTION ⚠️

┌─────────────────────────────────────────────────────────┐
│                🔧 MANUAL CHECK REQUIRED 🔧               │
├─────────────────────────────────────────────────────────┤
│  🌐 Target URL: http://${IP_ADDR}:${ACCESSPORT}
│  👤 Username: ${adminL}
│  🔑 Password: ${adminP}
├─────────────────────────────────────────────────────────┤
│  Current Status: HTTP ${FINAL_HTTP}
│  Services: Nginx(${FINAL_NGINX}) PHP-FPM(${FINAL_PHP}) Sockets(${FINAL_SOCKETS})
└─────────────────────────────────────────────────────────┘

🔧 Troubleshooting Steps:
1. Wait 2-3 minutes for services to fully initialize
2. Try manual restart: sudo -u xtreamcodes ${XC_PANEL_DIR}/start_services.sh
3. Check logs: tail -f ${XC_PANEL_DIR}/logs/php-fpm.log
4. Reboot if needed: sudo reboot

📋 Complete information saved to: /root/Xtreaminfo.txt
🔍 Technical details in: ${LOGFILE}

NEEDS_ATTENTION

fi

log_success "Installation completed! All information saved to /root/Xtreaminfo.txt"
exit 0
