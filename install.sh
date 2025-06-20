cat << 'EOF' > install.sh
#!/usr/bin/env bash
#
# ==============================================================================
# ***       Xtream Codes "Proper Repairs" - Installer v5.1 Stefan2512        ***
# ==============================================================================
# Created by: Gemini AI
# Date: 20-06-2025
#
# KEY IMPROVEMENTS:
# - v5.1: Switched to downloading the single 'Source code' archive from the release
#         to prevent multiple download failures and ensure all files are present.
# - Fully non-interactive, compatible with Ubuntu 18.04, 20.04, 22.04.
# - Includes all previous fixes for MariaDB, Python 3, and file extraction.
# ==============================================================================

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Variables and Constants ---
readonly RELEASE_ARCHIVE_URL="https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/archive/refs/tags/v1.0.zip"
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
  rm -f "/tmp/release.zip"
  rm -rf "/tmp/Proper-Repairs-Xtream-Codes-1.0"
  log_info "Temporary files have been deleted."
}

# ==============================================================================
# SCRIPT START
# ==============================================================================

clear
cat << "HEADER"
┌───────────────────────────────────────────────────────────────────┐
│   Xtream Codes "Proper Repairs" Installer v5.1 (Stefan2512 Fork)  │
│                  (Fully Automatic / Non-Interactive)              │
└───────────────────────────────────────────────────────────────────┘
> This script will install the panel using assets from the Stefan2512 fork.
HEADER
echo
log_warning "This is a non-interactive script. Installation will proceed automatically."
log_warning "All existing MariaDB/MySQL data on this server will be DELETED."
sleep 5

# --- 1. Initial Checks ---
log_step "Initial system checks"

if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root. Try 'sudo ./install.sh'"
fi

if ! ping -c 1 -W 2 google.com &>/dev/null; then
    log_warning "Could not detect an internet connection. Installation may fail."
    sleep 3
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
apt-get install -yqq curl wget unzip zip tar software-properties-common apt-transport-https ca-certificates gnupg python3 perl &>> "$LOGFILE"
log_success "Base packages installed."

log_info "Installing PHP..."
if [[ "$OS_VER" == "22.04" ]]; then
    log_info "Adding PPA for PHP 7.4 on Ubuntu 22.04..."
    add-apt-repository -y ppa:ondrej/php &>> "$LOGFILE"
    apt-get update -qq
fi

if apt-get install -yqq php7.4{,-fpm,-cli,-mysql,-curl,-gd,-json,-zip,-xml,-mbstring,-soap,-intl,-bcmath} &>> "$LOGFILE"; then
    PHP_VERSION="7.4"
    PHP_SOCK="/run/php/php7.4-fpm.sock"
else
    log_warning "PHP 7.4 could not be installed. Attempting to install the system's default PHP version..."
    apt-get install -yqq php{,-fpm,-cli,-mysql,-curl,-gd,-json,-zip,-xml,-mbstring,-soap,-intl,-bcmath} &>> "$LOGFILE"
    PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    PHP_SOCK="/run/php/php${PHP_VERSION}-fpm.sock"
fi
log_success "PHP version $PHP_VERSION has been installed."

log_info "Installing Nginx and other libraries..."
apt-get install -yqq nginx libzip-dev libonig-dev &>> "$LOGFILE"
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
debconf-set-selections <<< "mariadb-server mysql-server/root_password password $PASSMYSQL"
debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password $PASSMYSQL"
apt-get install -yqq mariadb-server &>> "$LOGFILE"

cat > /etc/mysql/mariadb.conf.d/99-xtreamcodes.cnf <<EOF
[mysqld]
bind-address = 127.0.0.1
skip-name-resolve
EOF

systemctl restart mariadb
systemctl enable mariadb

if ! systemctl is-active --quiet mariadb; then
    log_error "MariaDB service could not start. Please check the logs."
fi

log_info "Securing MariaDB installation..."
mysql -u root -p"$PASSMYSQL" <<-EOSQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${PASSMYSQL}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOSQL
log_success "MariaDB has been installed and secured."

# --- 5. User and Database Creation ---
log_step "Creating system user and database"

if id "$XC_USER" &>/dev/null; then
    log_info "System user '$XC_USER' already exists."
else
    adduser --system --shell /bin/false --group --disabled-login "$XC_USER"
    log_success "System user '$XC_USER' has been created."
fi

log_info "Creating 'xtream_iptvpro' database..."
mysql -u root -p"$PASSMYSQL" -e "CREATE DATABASE xtream_iptvpro;"
mysql -u root -p"$PASSMYSQL" -e "GRANT ALL PRIVILEGES ON xtream_iptvpro.* TO 'user_iptvpro'@'localhost' IDENTIFIED BY '$XPASS';"
mysql -u root -p"$PASSMYSQL" -e "FLUSH PRIVILEGES;"
log_success "Database and user created successfully."

# --- 6. Panel Download and Installation ---
log_step "Downloading and installing panel files"

log_info "Downloading single release archive..."
wget -q -O "/tmp/release.zip" "$RELEASE_ARCHIVE_URL"
log_success "Release archive downloaded."

log_info "Extracting files..."
unzip -o -q "/tmp/release.zip" -d "/tmp/"

# Muta fisierele din directorul extras in locatia finala
TEMP_DIR="/tmp/Proper-Repairs-Xtream-Codes-1.0"
if [ -d "$TEMP_DIR" ]; then
    log_info "Moving files from temporary directory to $XC_PANEL_DIR"
    # Asigură-te că directorul destinație există
    mkdir -p "$XC_PANEL_DIR"
    # Mută tot conținutul, inclusiv fișierele ascunse
    mv ${TEMP_DIR}/* ${TEMP_DIR}/.github ${XC_PANEL_DIR}/
else
    log_error "Could not find the unzipped directory: $TEMP_DIR"
fi

log_info "Importing database..."
if [ -f "${XC_PANEL_DIR}/database.sql" ]; then
    mysql -u root -p"$PASSMYSQL" xtream_iptvpro < "${XC_PANEL_DIR}/database.sql"
else
    log_error "database.sql not found in the extracted files."
fi

log_info "Updating settings in the database..."
Padmin=$(perl -e 'print crypt($ARGV[0], "$6$rounds=5000$xtreamcodes")' "$ADMIN_PASS")
mysql -u root -p"$PASSMYSQL" xtream_iptvpro -e "UPDATE reg_users SET username = '$ADMIN_USER', password = '$Padmin', email = '$ADMIN_EMAIL' WHERE id = 1;"
mysql -u root -p"$PASSMYSQL" xtream_iptvpro -e "UPDATE streaming_servers SET server_ip='127.0.0.1' WHERE id=1;"

log_success "Panel installed and database imported."

# --- 7. Configuration Generation and Permissions ---
log_step "Generating config file and setting permissions"

log_info "Generating config file (Python 3 compatible)..."
python3 -c "
import base64
from itertools import cycle

config_data = '{\"host\":\"127.0.0.1\",\"db_user\":\"user_iptvpro\",\"db_pass\":\"$XPASS\",\"db_name\":\"xtream_iptvpro\",\"server_id\":\"1\", \"db_port\":\"3306\"}'
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
chmod -R 777 "${XC_PANEL_DIR}/streams" "${XC_PANEL_DIR}/tmp" "${XC_PANEL_DIR}/logs"

log_success "Configuration and permissions have been set."

# --- 8. Service Configuration (PHP-FPM & Nginx) ---
log_step "Configuring PHP-FPM and Nginx"

cat > "/etc/php/${PHP_VERSION}/fpm/pool.d/xtreamcodes.conf" <<EOF
[${XC_USER}]
user = ${XC_USER}
group = ${XC_USER}
listen = ${PHP_SOCK}
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 15
chdir = /
EOF

cat > /etc/nginx/sites-available/xtreamcodes.conf <<EOF
server {
    listen $ACCESSPORT default_server;
    server_name _;

    root ${XC_PANEL_DIR}/admin;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${PHP_SOCK};
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -s -f /etc/nginx/sites-available/xtreamcodes.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

if ! nginx -t; then
    log_error "Nginx configuration is invalid. Please check the file /etc/nginx/sites-available/xtreamcodes.conf"
fi

log_info "Restarting services..."
systemctl restart "php${PHP_VERSION}-fpm"
systemctl enable "php${PHP_VERSION}-fpm"
systemctl restart nginx
systemctl enable nginx

log_success "PHP-FPM and Nginx have been configured and restarted."

# --- 9. Finalization ---
log_step "Installation Complete!"

IP_ADDR=$(hostname -I | awk '{print $1}')

cat << "FINAL_MSG"

Congratulations! The Xtream Codes panel has been successfully installed.

You can access the admin panel at:
URL: http://${IP_ADDR}:${ACCESSPORT}

Login credentials:
Username: ${ADMIN_USER}
Password: ${ADMIN_PASS}

SECURITY WARNING:
- Please save this password in a secure location.
- It is recommended to clear your command history ('history -c') to remove any trace of the passwords.

FINAL_MSG

exit 0
EOF

chmod +x install.sh && sudo ./install.sh
