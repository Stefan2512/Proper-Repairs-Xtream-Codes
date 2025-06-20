#!/usr/bin/env bash
#
# ==============================================================================
# Xtream Codes "Proper Repairs" - Final Installer (Stefan2512 Fork)
# ==============================================================================
# Created by: Gemini AI
# Date: 2025-06-20
#
# Logic:
# - vDefinitive-3: Corrected MariaDB user logic. The script now creates the
#   panel user ('user_iptvpro') on the default port first, then switches
#   to the custom port and uses the new user for all subsequent operations.
#   This respects MariaDB's default security and resolves the 'Host not allowed' error.
# ==============================================================================

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Variables and Constants ---
readonly RELEASE_URL_PREFIX="https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/download/v1.0"
readonly PANEL_ARCHIVE_URL_TEMPLATE="https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/download/v1.0/xtreamcodes_enhanced_Ubuntu_VERSION.tar.gz"
readonly DATABASE_SQL_URL="https://raw.githubusercontent.com/Stefan2512/Proper-Repairs-Xtream-Codes/master/database.sql"
readonly XC_USER="xtreamcodes"
readonly XC_HOME="/home/${XC_USER}"
readonly XC_PANEL_DIR="${XC_HOME}/iptv_xtream_codes"
readonly LOG_DIR="/var/log/xtreamcodes"

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

# --- Cleanup Function on Exit ---
trap cleanup EXIT
cleanup() {
  rm -f "/tmp/panel.tar.gz" "/tmp/database.sql"
  log_info "Temporary files have been deleted."
}

# ==============================================================================
# SCRIPT START
# ==============================================================================

clear
cat << "HEADER"
┌───────────────────────────────────────────────────────────────────┐
│   Xtream Codes "Proper Repairs" Installer (Stefan2512 Fork)       │
│                  (Definitive Version 3)                           │
└───────────────────────────────────────────────────────────────────┘
> This script will install the panel using the correct assets from your GitHub fork.
HEADER
echo
log_warning "This is a non-interactive script. Installation will proceed automatically."
log_warning "All existing MariaDB/MySQL data on this server will be DELETED."
sleep 5

# --- 1. Initial Checks ---
log_step "Initial system checks"

if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root."
fi

OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
OS_VER=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')
ARCH=$(uname -m)

log_info "Detected system: ${OS_ID^} $OS_VER ($ARCH)"

if [[ "$OS_ID" != "ubuntu" || ! "$OS_VER" =~ ^(18\.04|20\.04|22\.04)$ || "$ARCH" != "x86_64" ]]; then
    log_error "This script is only compatible with Ubuntu 18.04, 20.04, 22.04 (64-bit)."
fi

log_success "Initial checks passed."

# --- 2. Set Installation Variables ---
log_step "Setting installation variables"

PANEL_ARCHIVE_URL="${PANEL_ARCHIVE_URL_TEMPLATE/VERSION/$OS_VER}"
PASSMYSQL=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
XPASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
ADMIN_USER="admin"
ADMIN_PASS="admin$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)"
ADMIN_EMAIL="admin@example.com"
ACCESSPORT=2086

log_info "Variables have been set."

# --- 3. System Preparation & Dependencies ---
log_step "Installing system dependencies"
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq

log_info "Installing base packages..."
apt-get install -yqq curl wget unzip zip tar software-properties-common apt-transport-https ca-certificates gnupg python3 perl daemonize python-is-python3 &>> "$LOGFILE"
log_success "Base packages installed."

log_info "Installing PHP..."
if [[ "$OS_VER" == "22.04" ]]; then
    log_info "Adding PPA for PHP 7.4 on Ubuntu 22.04..."
    add-apt-repository -y ppa:ondrej/php &>> "$LOGFILE"
    apt-get update -qq
fi
apt-get install -yqq php7.4{,-cli,-mysql,-curl,-gd,-json,-zip,-xml,-mbstring,-soap,-intl,-bcmath} &>> "$LOGFILE"
log_success "PHP and modules installed."

log_info "Installing other libraries..."
apt-get install -yqq libzip-dev libonig-dev &>> "$LOGFILE"
if [ ! -f "/usr/lib/x86_64-linux-gnu/libzip.so.4" ] && [ -f "/usr/lib/x86_64-linux-gnu/libzip.so.5" ]; then
    ln -s /usr/lib/x86_64-linux-gnu/libzip.so.5 /usr/lib/x86_64-linux-gnu/libzip.so.4
    log_info "Created symlink for libzip compatibility."
fi
ldconfig
log_success "Dependencies have been installed."

# --- 4. MariaDB Installation & Configuration ---
log_step "Installing and configuring MariaDB"

if systemctl list-units --type=service --state=active | grep -q 'mysql\|mariadb'; then
    log_warning "Existing MySQL/MariaDB service detected. It will be COMPLETELY PURGED automatically."
    sleep 3
    log_info "Stopping and purging existing MySQL/MariaDB installation..."
    systemctl stop mariadb mysql || true
    systemctl disable mariadb mysql || true
    apt-get -y purge 'mysql-.*' 'mariadb-.*' &>> "$LOGFILE"
    apt-get -y autoremove &>> "$LOGFILE"
    apt-get -y autoclean &>> "$LOGFILE"
    rm -rf /etc/mysql /var/lib/mysql /var/log/mysql
    log_success "Cleanup completed."
fi

log_info "Installing MariaDB Server..."
apt-get install -yqq mariadb-server &>> "$LOGFILE"

systemctl start mariadb
systemctl enable mariadb

if ! systemctl is-active --quiet mariadb; then
    log_error "MariaDB service could not start."
fi

log_info "Securing MariaDB and creating users on default port..."
# On a fresh install, root can connect without a password via the socket
mysql -u root <<-EOSQL
-- Set root password
ALTER USER 'root'@'localhost' IDENTIFIED BY '${PASSMYSQL}';
-- Clean up default insecure settings
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
-- Create panel database and user
CREATE DATABASE xtream_iptvpro;
CREATE USER 'user_iptvpro'@'localhost' IDENTIFIED BY '${XPASS}';
GRANT ALL PRIVILEGES ON xtream_iptvpro.* TO 'user_iptvpro'@'localhost';
FLUSH PRIVILEGES;
EOSQL
log_success "MariaDB initial security and user creation complete."

log_info "Switching MariaDB to port 7999..."
systemctl stop mariadb
cat > /etc/mysql/mariadb.conf.d/99-xtreamcodes.cnf <<EOF
[mysqld]
port = 7999
bind-address = 127.0.0.1
skip-name-resolve
EOF
systemctl start mariadb
log_success "MariaDB is now running on port 7999."

# --- 5. User and Panel Creation (This step is now integrated into step 4 and 6) ---
log_step "User and Database creation step is now complete."


# --- 6. Panel Download and Installation ---
log_step "Downloading and installing panel files"

log_info "Cleaning up any previous panel installation..."
rm -rf "$XC_PANEL_DIR"
mkdir -p "$XC_PANEL_DIR"
log_success "Panel directory is clean."

log_info "Downloading panel archive for Ubuntu ${OS_VER}..."
wget --no-check-certificate -q -O "/tmp/panel.tar.gz" "$PANEL_ARCHIVE_URL"
log_success "Panel archive downloaded."

log_info "Downloading database.sql from main branch..."
wget --no-check-certificate -q -O "/tmp/database.sql" "$DATABASE_SQL_URL"
log_success "Database SQL file downloaded."

log_info "Extracting panel files into $XC_PANEL_DIR..."
tar -xzf "/tmp/panel.tar.gz" -C "$XC_PANEL_DIR" --strip-components=1

if [ ! -f "${XC_PANEL_DIR}/start_services.sh" ]; then
    log_error "Extraction failed. The 'start_services.sh' script was not found in $XC_PANEL_DIR."
fi
log_success "Panel files extracted."

log_info "Importing database..."
if [ -f "/tmp/database.sql" ]; then
    # Use the new, more secure user for the import
    mysql -u user_iptvpro -p"$XPASS" -h 127.0.0.1 -P 7999 xtream_iptvpro < "/tmp/database.sql"
else
    log_error "Downloaded database.sql file not found."
fi

log_info "Updating settings in the database..."
Padmin=$(perl -e 'print crypt($ARGV[0], "$6$rounds=5000$xtreamcodes")' "$ADMIN_PASS")
# Use the new, more secure user for updates
mysql -u user_iptvpro -p"$XPASS" -h 127.0.0.1 -P 7999 xtream_iptvpro -e "UPDATE reg_users SET username = '$ADMIN_USER', password = '$Padmin', email = '$ADMIN_EMAIL' WHERE id = 1;"

log_success "Panel installed and database imported."

# --- 7. Configuration Generation and Permissions ---
log_step "Generating config file and setting permissions"

log_info "Generating config file (Python 3 compatible)..."
python3 -c "
import base64
from itertools import cycle

config_data = '{\"host\":\"127.0.0.1\",\"db_user\":\"user_iptvpro\",\"db_pass\":\"$XPASS\",\"db_name\":\"xtream_iptvpro\",\"server_id\":\"1\", \"db_port\":\"7999\"}'
key = '5709650b0d7806074842c6de575025b1'

encrypted_bytes = bytes([ord(c) ^ ord(k) for c, k in zip(config_data, cycle(key))])
encoded = base64.b64encode(encrypted_bytes).decode('ascii')

with open('${XC_PANEL_DIR}/config', 'w') as f:
    f.write(encoded)
"
if [[ ! -f "${XC_PANEL_DIR}/config" ]]; then
    log_error "Config file generation failed."
fi

log_info "Setting correct file permissions..."
chown -R "$XC_USER":"$XC_USER" "$XC_HOME"
chmod +x "${XC_PANEL_DIR}/start_services.sh"
chmod -R 0777 "${XC_PANEL_DIR}/crons"

echo "xtreamcodes ALL = (root) NOPASSWD: /sbin/iptables, /usr/bin/chattr, /usr/bin/python, /usr/bin/python3" | sudo tee /etc/sudoers.d/99-xtreamcodes

log_success "Configuration and permissions have been set."

# --- 8. Final Service Configuration ---
log_step "Disabling system services and setting up panel auto-start"

systemctl disable nginx &>/dev/null || true
systemctl stop nginx &>/dev/null || true
systemctl disable php7.4-fpm &>/dev/null || true
systemctl stop php7.4-fpm &>/dev/null || true
killall -9 nginx &>/dev/null || true
killall -9 php-fpm &>/dev/null || true

log_info "Adding panel to startup (crontab)..."
(crontab -l 2>/dev/null | grep -v "start_services.sh" ; echo "@reboot ${XC_PANEL_DIR}/start_services.sh") | crontab -

# --- 9. Starting Panel Services ---
log_step "Starting panel's self-contained services..."
sudo -u "$XC_USER" bash "${XC_PANEL_DIR}/start_services.sh"

sleep 5

log_success "Panel services started."


# --- 10. Finalization ---
log_step "Installation Complete!"

IP_ADDR=$(hostname -I | awk '{print $1}')

cat << FINAL_MSG

Congratulations! The Xtream Codes panel has been successfully installed.

You can access the admin panel at:
URL: http://${IP_ADDR}:${ACCESSPORT}  (Please allow a minute for services to fully initialize)

Login credentials:
Username: ${ADMIN_USER}
Password: ${ADMIN_PASS}

SECURITY WARNING:
- Please save this password in a secure location.
- It is recommended to clear your command history ('history -c').

FINAL_MSG

exit 0
