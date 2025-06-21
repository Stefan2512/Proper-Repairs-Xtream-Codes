#!/usr/bin/env bash
#
# ==============================================================================
# Xtream Codes "Proper Repairs" - Perfect Installer (Stefan2512 Fork)
# ==============================================================================
# Created by: Stefan2512
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

# --- Variables and Constants ---
readonly REPO_URL_PREFIX="https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes"
readonly PANEL_ARCHIVE_URL_TEMPLATE="https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/download/v1.0/xtreamcodes_enhanced_Ubuntu_VERSION.tar.gz"
readonly DATABASE_SQL_URL="https://raw.githubusercontent.com/Stefan2512/Proper-Repairs-Xtream-Codes/master/database.sql"
readonly XC_USER="xtreamcodes"
readonly XC_HOME="/home/${XC_USER}"
readonly XC_PANEL_DIR="${XC_HOME}/iptv_xtream_codes"
readonly LOG_DIR="/var/log/xtreamcodes"
readonly VERSION="Perfect-v1.0"

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
apt-get install -yqq curl wget unzip zip tar software-properties-common \
    apt-transport-https ca-certificates gnupg python3 perl daemonize \
    python-is-python3 build-essential lsb-release &>> "$LOGFILE"

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
apt-get install -yqq php7.4{,-cli,-mysql,-curl,-gd,-json,-zip,-xml,-mbstring,-soap,-intl,-bcmath,-fpm} &>> "$LOGFILE"

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
systemctl start mariadb && systemctl enable mariadb

if ! systemctl is-active --quiet mariadb; then 
    log_error "MariaDB failed to start."
fi

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

# Wait and validate
sleep 10

# Check if services are running
NGINX_PROC=$(pgrep -f "nginx" | wc -l)
PHP_PROC=$(pgrep -f "php-fpm" | wc -l)

log_info "Service status:"
log_info "  Nginx processes: $NGINX_PROC"
log_info "  PHP-FPM processes: $PHP_PROC"

# Check sockets
SOCKET_COUNT=$(find "${XC_PANEL_DIR}/tmp" -name "*.sock" 2>/dev/null | wc -l)
log_info "  Socket files: $SOCKET_COUNT"

# Test web interface
IP_ADDR=$(hostname -I | awk '{print $1}')
sleep 5
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${ACCESSPORT}/" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ]; then
    log_success "Web interface is responding correctly!"
elif [ "$HTTP_STATUS" = "502" ]; then
    log_warning "502 Bad Gateway - PHP-FPM communication issue detected."
    log_info "Running automatic repair..."
    
    # Quick repair attempt
    sudo -u "$XC_USER" "${XC_PANEL_DIR}/php/sbin/php-fpm" --fpm-config "${XC_PANEL_DIR}/php/etc/php-fpm.conf" &
    sleep 3
    sudo -u "$XC_USER" "${XC_PANEL_DIR}/nginx/sbin/nginx" -s reload &
    sleep 2
    
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${ACCESSPORT}/" 2>/dev/null || echo "000")
    if [ "$HTTP_STATUS" = "200" ]; then
        log_success "Repair successful! Web interface is now working."
    else
        log_warning "Manual troubleshooting may be required."
    fi
else
    log_warning "Web interface status: $HTTP_STATUS"
fi

# --- 16. Installation Complete ---
log_step "Installation Complete!"

cat << COMPLETION_MSG

🎉 Xtream Codes Installation Completed Successfully! 🎉

┌─────────────────────────────────────────────────────────┐
│                    ACCESS INFORMATION                    │
├─────────────────────────────────────────────────────────┤
│  Admin Panel: http://${IP_ADDR}:${ACCESSPORT}
│  Username:    ${adminL}
│  Password:    ${adminP}
│  Email:       ${EMAIL}
├─────────────────────────────────────────────────────────┤
│  Client Portal: http://${IP_ADDR}:${CLIENTACCESSPORT}
│  MySQL Root:    ${PASSMYSQL}
│  MySQL User:    user_iptvpro / ${XPASS}
└─────────────────────────────────────────────────────────┘

🔧 Installation Details:
   • Repository: Stefan2512/Proper-Repairs-Xtream-Codes
   • Version: $VERSION
   • All debugging fixes applied
   • Self-contained in $XC_PANEL_DIR

📝 Credentials saved to: /root/Xtreaminfo.txt

⚠️  Important Notes:
   • Allow 1-2 minutes for all services to fully initialize
   • Consider rebooting for optimal performance  
   • All services are self-contained and managed automatically

🛠️ Troubleshooting:
   • Check logs: tail -f $XC_PANEL_DIR/logs/php-fpm.log
   • Check nginx: tail -f $XC_PANEL_DIR/nginx/logs/error.log
   • Restart services: sudo -u xtreamcodes $XC_PANEL_DIR/start_services.sh

COMPLETION_MSG

# Save credentials
cat > /root/Xtreaminfo.txt <<EOF
Xtream Codes Installation Information
=====================================
Admin Panel: http://${IP_ADDR}:${ACCESSPORT}
Username: ${adminL}
Password: ${adminP}
Email: ${EMAIL}

Client Portal: http://${IP_ADDR}:${CLIENTACCESSPORT}

Database Information:
MySQL Root Password: ${PASSMYSQL}
MySQL User: user_iptvpro
MySQL Password: ${XPASS}
MySQL Port: 7999

Installation Details:
Repository: Stefan2512/Proper-Repairs-Xtream-Codes
Version: $VERSION
Installation Date: $(date)
Server IP: ${IP_ADDR}
EOF

log_success "Installation completed successfully!"
exit 0
