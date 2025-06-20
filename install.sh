#!/usr/bin/env bash
#
# ==============================================================================
# Xtream Codes "Proper Repairs" - Final Installer (Stefan2512 Fork)
# ==============================================================================
# Created by: Gemini AI
# Date: 2025-06-20
#
# Logic:
# - vDefinitive-Final: Added explicit creation of required log/tmp/pid directories
#   after extraction, fixing the 'No such file or directory' errors at startup.
#   This ensures the panel's services have a valid directory structure to run.
# ==============================================================================

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Variables and Constants ---
readonly REPO_URL_PREFIX="https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes"
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
│                  (Definitive Final Version)                       │
└───────────────────────────────────────────────────────────────────┘
> This script will install the panel using the correct assets from your GitHub fork.
HEADER
echo
log_warning "This is a non-interactive script. Installation will proceed automatically."
log_warning "All existing MariaDB/MySQL data on this server will be DELETED."
sleep 5

# --- 1. Initial Checks ---
log_step "Initial system checks"
if [[ $EUID -ne 0 ]]; then log_error "This script must be run as root."; fi
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
apt-get install -yqq curl wget unzip zip tar software-properties-common apt-transport-https ca-certificates gnupg python3 perl daemonize python-is-python3 build-essential &>> "$LOGFILE"
log_success "Base packages installed."

log_info "Installing PHP..."
if [[ "$OS_VER" == "22.04" ]]; then
    log_info "Adding PPA for PHP 7.4 on Ubuntu 22.04..."
    add-apt-repository -y ppa:ondrej/php &>> "$LOGFILE"
    apt-get update -qq
fi
apt-get install -yqq php7.4{,-cli,-mysql,-curl,-gd,-json,-zip,-xml,-mbstring,-soap,-intl,-bcmath} &>> "$LOGFILE"
log_success "PHP and modules installed."

# --- 4. MariaDB Installation & Configuration ---
log_step "Installing and configuring MariaDB"
if systemctl list-units --type=service --state=active | grep -q 'mysql\|mariadb'; then
    log_warning "Existing MySQL/MariaDB service detected. It will be COMPLETELY PURGED."
    systemctl stop mariadb mysql || true
    apt-get -y purge 'mysql-.*' 'mariadb-.*' &>> "$LOGFILE"
    rm -rf /etc/mysql /var/lib/mysql
    log_success "Cleanup completed."
fi
log_info "Installing MariaDB Server..."
apt-get install -yqq mariadb-server &>> "$LOGFILE"
systemctl start mariadb && systemctl enable mariadb
if ! systemctl is-active --quiet mariadb; then log_error "MariaDB service could not start."; fi

log_info "Securing MariaDB and creating users on default port..."
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

# --- 5. User Creation and Panel Download ---
log_step "Downloading and installing panel files"
if ! id "$XC_USER" &>/dev/null; then
    adduser --system --shell /bin/false --group --disabled-login "$XC_USER"
    log_success "System user '$XC_USER' has been created."
fi
log_info "Cleaning up any previous panel installation..."
rm -rf "$XC_PANEL_DIR"
mkdir -p "$XC_PANEL_DIR"
log_info "Downloading panel archive for Ubuntu ${OS_VER}..."
wget --no-check-certificate -q -O "/tmp/panel.tar.gz" "$PANEL_ARCHIVE_URL"
log_success "Panel archive downloaded."
log_info "Extracting panel files into $XC_PANEL_DIR..."
tar -xzf "/tmp/panel.tar.gz" -C "$XC_PANEL_DIR" --strip-components=1
if [ ! -f "${XC_PANEL_DIR}/start_services.sh" ]; then
    log_error "Extraction failed. The 'start_services.sh' script was not found."
fi
log_success "Panel files extracted."

# --- 6. Final Configuration ---
log_step "Finalizing configuration"

# **MODIFICAREA CHEIE AICI: Crearea directoarelor lipsă**
log_info "Creating required directories for logs, tmp, and pids..."
mkdir -p "${XC_PANEL_DIR}/logs" "${XC_PANEL_DIR}/tmp" "${XC_PANEL_DIR}/streams"
mkdir -p "${XC_PANEL_DIR}/nginx/logs"
mkdir -p "${XC_PANEL_DIR}/nginx_rtmp/logs"
mkdir -p "${XC_PANEL_DIR}/php/pids"
log_success "Panel directory structure verified."

log_info "Downloading and importing database..."
wget --no-check-certificate -q -O "/tmp/database.sql" "$DATABASE_SQL_URL"
mysql -u user_iptvpro -p"$XPASS" -h 127.0.0.1 -P 7999 xtream_iptvpro < "/tmp/database.sql"
log_info "Updating admin user in database..."
Padmin=$(perl -e 'print crypt($ARGV[0], "$6$rounds=5000$xtreamcodes")' "$ADMIN_PASS")
mysql -u user_iptvpro -p"$XPASS" -h 127.0.0.1 -P 7999 xtream_iptvpro -e "UPDATE reg_users SET username = '$ADMIN_USER', password = '$Padmin', email = '$ADMIN_EMAIL' WHERE id = 1;"
log_success "Database configured."

log_info "Patching start_services.sh to use the correct database password..."
# This sed command replaces the python2 decryption line with the actual password
sed -i 's|PASSMYSQL=$(python2.*)|PASSMYSQL="'"$XPASS"'"|g' "${XC_PANEL_DIR}/start_services.sh"

log_info "Generating config file..."
python3 -c "
import base64, itertools
config_data = '{\"host\":\"127.0.0.1\",\"db_user\":\"user_iptvpro\",\"db_pass\":\"$XPASS\",\"db_name\":\"xtream_iptvpro\",\"server_id\":\"1\", \"db_port\":\"7999\"}'
key = '5709650b0d7806074842c6de575025b1'
encrypted_bytes = bytes([ord(c) ^ ord(k) for c, k in zip(config_data, itertools.cycle(key))])
encoded = base64.b64encode(encrypted_bytes).decode('ascii')
with open('${XC_PANEL_DIR}/config', 'w') as f: f.write(encoded)
"
log_info "Setting final permissions..."
chown -R "$XC_USER":"$XC_USER" "$XC_HOME"
chmod +x "${XC_PANEL_DIR}/start_services.sh"
chmod -R 0777 "${XC_PANEL_DIR}/crons"
echo "xtreamcodes ALL = (root) NOPASSWD: /sbin/iptables, /usr/bin/chattr, /usr/bin/python, /usr/bin/python3" | tee /etc/sudoers.d/99-xtreamcodes &> /dev/null
log_success "Configuration complete."

# --- 7. Final Service Start ---
log_step "Disabling system services and starting panel"
systemctl disable --now nginx &>/dev/null || true
systemctl disable --now php7.4-fpm &>/dev/null || true
killall -9 nginx php-fpm &>/dev/null || true
log_info "Adding panel to startup (crontab)..."
(crontab -l 2>/dev/null | grep -v "start_services.sh" ; echo "@reboot ${XC_PANEL_DIR}/start_services.sh") | crontab -
log_info "Starting panel's self-contained services..."
sudo -u "$XC_USER" bash "${XC_PANEL_DIR}/start_services.sh"
sleep 5
log_success "Panel services started."

# --- 8. Finalization ---
log_step "Installation Complete!"
IP_ADDR=$(hostname -I | awk '{print $1}')
cat << FINAL_MSG

Congratulations! The Xtream Codes panel has been successfully installed.
The server may need a REBOOT for all changes to take full effect.

You can access the admin panel at:
URL: http://${IP_ADDR}:${ACCESSPORT}  (Please allow a minute for services to fully initialize)

Login credentials:
Username: ${ADMIN_USER}
Password: ${ADMIN_PASS}
(Also saved in /root/Xtreaminfo.txt)

FINAL_MSG
echo "URL: http://${IP_ADDR}:${ACCESSPORT} | User: ${ADMIN_USER} | Pass: ${ADMIN_PASS}" > /root/Xtreaminfo.txt
exit 0
