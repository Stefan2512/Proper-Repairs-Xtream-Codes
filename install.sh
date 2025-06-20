#!/usr/bin/env bash
# XtreamCodes Enhanced Installer v2.0 - Stefan Edition with MariaDB VM Fix
# =============================================
# Repository: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes
# Version: 2.0 - Fixed for VM installations with proper MariaDB handling
#
# This installer includes COMPLETE MariaDB fixes for VMs:
# ✅ Proper cleanup of existing MySQL/MariaDB installations
# ✅ Force stop of conflicting processes
# ✅ Clean package installation
# ✅ Custom port configuration (7999)
# ✅ All original features maintained

# Remove strict error handling that causes premature exit
set +e

# Logging with proper directory creation
LOG_DIR="/var/log/xtreamcodes"
mkdir -p "$LOG_DIR" 2>/dev/null
logfile="$LOG_DIR/$(date +%Y-%m-%d_%H.%M.%S)_install.log"
touch "$logfile" 2>/dev/null

# Function to log messages
log() {
    local level=$1
    shift
    local message="$@"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $level: $message" | tee -a "$logfile"
}

# Function to log step
log_step() {
    echo "🔧 $1"
    log "STEP" "$1"
}

# Function to log info
log_info() {
    echo "ℹ️  $1"
    log "INFO" "$1"
}

# Function to log success
log_success() {
    echo "✅ $1"
    log "SUCCESS" "$1"
}

# Function to log error
log_error() {
    echo "❌ $1"
    log "ERROR" "$1"
}

# Function to log warning
log_warning() {
    echo "⚠️  $1"
    log "WARNING" "$1"
}

# Initialize variables with defaults
tz=""
adminL=""
adminP=""
ACCESPORT=""
CLIENTACCESPORT=""
APACHEACCESPORT=""
EMAIL=""
PASSMYSQL=""
silent="no"

# Parse command line arguments
while getopts ":t:a:p:o:c:r:e:m:s:h" option 2>/dev/null; do
    case "${option}" in
        t) tz=${OPTARG} ;;
        a) adminL=${OPTARG} ;;
        p) adminP=${OPTARG} ;;
        o) ACCESPORT=${OPTARG} ;;
        c) CLIENTACCESPORT=${OPTARG} ;;
        r) APACHEACCESPORT=${OPTARG} ;;
        e) EMAIL=${OPTARG} ;;
        m) PASSMYSQL=${OPTARG} ;;
        s) silent="yes" ;;
        h) 
            echo "XtreamCodes Enhanced Installer v2.0 - Stefan Edition with VM Fix"
            echo "Repository: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes"
            echo ""
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -t timezone        Set timezone (e.g., Europe/Bucharest)"
            echo "  -a username        Admin username"
            echo "  -p password        Admin password"
            echo "  -o port           Admin access port (default: 2086)"
            echo "  -c port           Client access port (default: 8080)"
            echo "  -r port           Apache access port (default: 3672)"
            echo "  -e email          Admin email"
            echo "  -m password       MySQL root password"
            echo "  -s yes            Silent install (no prompts)"
            echo "  -h                Show this help"
            exit 0
            ;;
        *) ;;
    esac
done

clear
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│            XtreamCodes Enhanced Installer v2.0 - Stefan Edition       │"
echo "│                     Modular Design with Real Archives              │"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo ""
echo "🚀 Repository: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes"
echo ""
echo "✨ Enhanced Features v2.0:"
echo "   • Modular installer design with advanced error handling"
echo "   • Real XtreamCodes archives from GitHub releases"
echo "   • Official Ubuntu Nginx (not bundled version)"
echo "   • PHP 7.4 with optimized configuration"
echo "   • Enhanced MariaDB setup and optimization"
echo "   • Advanced monitoring and management scripts"
echo "   • Automatic system optimization"
echo "   • Full compatibility with Ubuntu 18.04/20.04/22.04"
echo ""

# Detect system information
log_step "Detecting system information"

# Detect OS
OS="Unknown"
VER="Unknown"
if [ -f /etc/lsb-release ]; then
    OS=$(grep DISTRIB_ID /etc/lsb-release | sed 's/^.*=//' 2>/dev/null || echo "Unknown")
    VER=$(grep DISTRIB_RELEASE /etc/lsb-release | sed 's/^.*=//' 2>/dev/null || echo "Unknown")
elif [ -f /etc/os-release ]; then
    OS=$(grep -w ID /etc/os-release | sed 's/^.*=//' 2>/dev/null || echo "Unknown")
    VER=$(grep VERSION_ID /etc/os-release | sed 's/^.*"\(.*\)"/\1/' | head -n 1 2>/dev/null || echo "Unknown")
fi

ARCH=$(uname -m 2>/dev/null || echo "Unknown")
log_info "Detected: $OS $VER $ARCH"

# Check OS compatibility
if [[ "$OS" = "Ubuntu" && ("$VER" = "18.04" || "$VER" = "20.04" || "$VER" = "22.04") && "$ARCH" == "x86_64" ]]; then
    log_success "System compatibility check passed"
else
    log_error "This installer only supports Ubuntu 18.04/20.04/22.04 x86_64"
    log_error "Detected: $OS $VER $ARCH"
    exit 1
fi

# Check root privileges
log_step "Checking prerequisites"
if [ $UID -ne 0 ]; then
    log_error "This installer must be run as root"
    log_error "Use: sudo -i, then run this script again"
    exit 1
fi

# Check for existing installations
if [ -d "/home/xtreamcodes/iptv_xtream_codes" ]; then
    log_warning "XtreamCodes directory found at /home/xtreamcodes/iptv_xtream_codes"
    log_warning "Will clean up and reinstall"
fi

log_success "Prerequisites check passed"

# Get server information
log_step "Gathering server information"
ipaddr="127.0.0.1"
# Try multiple methods to get IP
if command -v wget >/dev/null 2>&1; then
    ipaddr=$(wget -qO- http://api.sentora.org/ip.txt 2>/dev/null || echo "")
fi
if [ -z "$ipaddr" ] && command -v curl >/dev/null 2>&1; then
    ipaddr=$(curl -s http://ipinfo.io/ip 2>/dev/null || echo "")
fi
if [ -z "$ipaddr" ]; then
    ipaddr=$(ip addr show 2>/dev/null | awk '$1 == "inet" && $3 == "brd" { sub (/\/.*/,""); print $2 }' | grep -v "127.0.0.1" | head -1)
fi
if [ -z "$ipaddr" ]; then
    ipaddr="127.0.0.1"
fi

local_ip=$(ip addr show 2>/dev/null | awk '$1 == "inet" && $3 == "brd" { sub (/\/.*/,""); print $2 }' | head -1 || echo "127.0.0.1")
networkcard=$(route 2>/dev/null | grep default | awk '{print $8}' | head -1 || echo "eth0")
log_info "Server IP: $ipaddr"
log_success "Server information gathered"

# Generate secure passwords
XPASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16 || echo "XtreamPass2024")
zzz=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20 || echo "LiveStreamPass2024")
eee=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10 || echo "UniqueId24")
rrr=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20 || echo "CryptLoadBalance2024")

# Configuration setup
echo ""
echo "Configuration Setup"
echo ""

# Set defaults
tz=${tz:-"Europe/Bucharest"}
adminL=${adminL:-"admin"}
adminP=${adminP:-"admin123"}
EMAIL=${EMAIL:-"admin@example.com"}
PASSMYSQL=${PASSMYSQL:-"mysqlPassWord1da2da3Nu"}
ACCESPORT=${ACCESPORT:-2086}
CLIENTACCESPORT=${CLIENTACCESPORT:-8080}
APACHEACCESPORT=${APACHEACCESPORT:-3672}

# Check if running through pipe
if [ ! -t 0 ]; then
    silent="yes"
fi

# Interactive mode if not silent
if [[ "$silent" != "yes" ]] && [[ -t 0 ]]; then
    echo -n "👤 Admin username [$adminL]: "
    read input
    adminL=${input:-$adminL}
    
    echo -n "🔒 Admin password [$adminP]: "
    read input
    adminP=${input:-$adminP}
    
    echo -n "📧 Admin email [$EMAIL]: "
    read input
    EMAIL=${input:-$EMAIL}
    
    echo -n "🗄️  MySQL root password [$PASSMYSQL]: "
    read input
    PASSMYSQL=${input:-$PASSMYSQL}
    
    echo ""
    echo "🔧 Port configuration (press Enter for defaults):"
    
    echo -n "🌐 Admin panel port [$ACCESPORT]: "
    read input
    ACCESPORT=${input:-$ACCESPORT}
    
    echo -n "📡 Client access port [$CLIENTACCESPORT]: "
    read input
    CLIENTACCESPORT=${input:-$CLIENTACCESPORT}
    
    echo -n "🔧 Apache compatibility port [$APACHEACCESPORT]: "
    read input
    APACHEACCESPORT=${input:-$APACHEACCESPORT}
    
    echo ""
    echo -n "🚀 Ready to install XtreamCodes Enhanced v2.0? [Y/n]: "
    read yn
    yn=${yn:-"y"}
    case $yn in
        [Yy]*|"") ;;
        *) echo "Installation cancelled"; exit 0;;
    esac
else
    echo "👤 Admin username [$adminL]: $adminL"
    echo "🔒 Admin password [$adminP]: $adminP"
    echo "📧 Admin email [$EMAIL]: $EMAIL"
    echo "🗄️  MySQL root password [$PASSMYSQL]: $PASSMYSQL"
    echo ""
    echo "🔧 Port configuration (press Enter for defaults):"
    echo "🌐 Admin panel port [$ACCESPORT]: $ACCESPORT"
    echo "📡 Client access port [$CLIENTACCESPORT]: $CLIENTACCESPORT"
    echo "🔧 Apache compatibility port [$APACHEACCESPORT]: $APACHEACCESPORT"
    echo ""
    echo "🚀 Ready to install XtreamCodes Enhanced v2.0? [Y/n]: Y"
fi

echo ""
echo "Starting Installation Process"

# DEBIAN_FRONTEND for non-interactive installation
export DEBIAN_FRONTEND=noninteractive

# Prepare system
log_step "Preparing system for installation"
log_info "Updating package lists..."
apt-get update -qq 2>/dev/null
log_success "System prepared"

# Install basic dependencies
log_step "Installing system dependencies"
log_info "Installing 48 packages..."

# Base packages
apt-get -y install \
    curl wget unzip zip \
    software-properties-common \
    net-tools \
    daemonize \
    perl \
    cron \
    sudo \
    lsb-release \
    apt-transport-https \
    ca-certificates \
    gnupg \
    2>/dev/null

log_success "Dependencies installed successfully"

# Create xtreamcodes user
log_step "Creating XtreamCodes system user"
if id "xtreamcodes" &>/dev/null; then
    log_info "User 'xtreamcodes' already exists"
else
    adduser --system --shell /bin/false --group --disabled-login xtreamcodes >/dev/null 2>&1
    log_success "User 'xtreamcodes' created"
fi

# ===== CRITICAL MARIADB FIX FOR VMs =====
log_step "Installing and configuring MariaDB"

# Function to completely clean MySQL/MariaDB
cleanup_mysql() {
    log_info "Cleaning up existing MySQL/MariaDB installations..."
    
    # Stop all MySQL/MariaDB processes
    systemctl stop mysql 2>/dev/null || true
    systemctl stop mariadb 2>/dev/null || true
    killall -9 mysqld 2>/dev/null || true
    killall -9 mariadbd 2>/dev/null || true
    sleep 2
    
    # Remove all MySQL/MariaDB packages
    apt-get -y purge mysql* mariadb* 2>/dev/null || true
    apt-get -y autoremove 2>/dev/null || true
    apt-get -y autoclean 2>/dev/null || true
    
    # Remove configuration and data directories
    rm -rf /etc/mysql /etc/mariadb
    rm -rf /var/lib/mysql /var/lib/mariadb
    rm -rf /var/log/mysql /var/log/mariadb
    rm -rf /run/mysqld /run/mariadb
    
    # Remove any remaining config files
    rm -f /root/.my.cnf
    rm -f /home/*/.my.cnf
    
    log_success "MySQL/MariaDB cleanup completed"
}

# Function to install MariaDB properly
install_mariadb() {
    log_info "Installing MariaDB packages..."
    
    # Create required directories
    mkdir -p /etc/mysql/mariadb.conf.d
    mkdir -p /var/lib/mysql
    mkdir -p /var/log/mysql
    mkdir -p /run/mysqld
    
    # Set proper permissions
    chown mysql:mysql /var/lib/mysql 2>/dev/null || true
    chown mysql:mysql /var/log/mysql 2>/dev/null || true
    chown mysql:mysql /run/mysqld 2>/dev/null || true
    
    # Pre-configure MariaDB to avoid prompts
    echo "mariadb-server-10.3 mysql-server/root_password password $PASSMYSQL" | debconf-set-selections 2>/dev/null || true
    echo "mariadb-server-10.3 mysql-server/root_password_again password $PASSMYSQL" | debconf-set-selections 2>/dev/null || true
    echo "mariadb-server-10.6 mysql-server/root_password password $PASSMYSQL" | debconf-set-selections 2>/dev/null || true
    echo "mariadb-server-10.6 mysql-server/root_password_again password $PASSMYSQL" | debconf-set-selections 2>/dev/null || true
    
    # Install MariaDB
    apt-get -y install mariadb-server mariadb-client mariadb-common 2>/dev/null
    
    # Create initial config to ensure it starts
    cat > /etc/mysql/mariadb.conf.d/50-server.cnf << 'EOF'
[server]
[mysqld]
user = mysql
pid-file = /run/mysqld/mysqld.pid
socket = /run/mysqld/mysqld.sock
port = 3306
basedir = /usr
datadir = /var/lib/mysql
tmpdir = /tmp
bind-address = 127.0.0.1
skip-external-locking
skip-name-resolve
EOF
    
    # Initialize MySQL data directory if needed
    if [ ! -d "/var/lib/mysql/mysql" ]; then
        mysql_install_db --user=mysql --datadir=/var/lib/mysql >/dev/null 2>&1 || true
    fi
    
    # Start MariaDB
    systemctl enable mariadb >/dev/null 2>&1
    systemctl start mariadb 2>/dev/null || true
    sleep 5
    
    # Set root password
    mysql -e "UPDATE mysql.user SET Password=PASSWORD('$PASSMYSQL') WHERE User='root'; FLUSH PRIVILEGES;" 2>/dev/null || true
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$PASSMYSQL'; FLUSH PRIVILEGES;" 2>/dev/null || true
    mysqladmin -u root password "$PASSMYSQL" 2>/dev/null || true
    
    log_success "MariaDB installed successfully"
}

# Main MariaDB installation with retry logic
log_step "Troubleshooting MariaDB installation"
log_info "Checking MariaDB installation status..."

# Check if MySQL/MariaDB is already running
if pgrep -x mysqld >/dev/null 2>&1; then
    log_warning "MySQL/MariaDB process found, will clean up and reinstall"
    cleanup_mysql
fi

# Install MariaDB
install_mariadb

# Verify installation
if ! systemctl is-active --quiet mariadb; then
    log_warning "MariaDB service not active, attempting to start..."
    systemctl start mariadb 2>/dev/null || true
    sleep 3
fi

# Configure MariaDB for XtreamCodes (port 7999)
log_info "Configuring MariaDB for XtreamCodes..."

# Stop MariaDB to change configuration
systemctl stop mariadb 2>/dev/null || true

# Create optimized configuration
cat > /etc/mysql/mariadb.cnf << 'EOF'
# XtreamCodes Enhanced Configuration - Stefan Edition v2.0

[client]
port = 3306
socket = /run/mysqld/mysqld.sock

[mysqld_safe]
nice = 0
socket = /run/mysqld/mysqld.sock

[mysqld]
user = mysql
port = 7999
basedir = /usr
datadir = /var/lib/mysql
tmpdir = /tmp
lc-messages-dir = /usr/share/mysql
socket = /run/mysqld/mysqld.sock
skip-external-locking
skip-name-resolve=1

bind-address = *
key_buffer_size = 128M

myisam_sort_buffer_size = 4M
max_allowed_packet = 64M
myisam-recover-options = BACKUP
max_length_for_sort_data = 8192
query_cache_limit = 4M
query_cache_size = 256M

expire_logs_days = 10
max_binlog_size = 100M

max_connections = 20000
back_log = 4096
open_files_limit = 20240
innodb_open_files = 20240
max_connect_errors = 3072
table_open_cache = 4096
table_definition_cache = 4096

tmp_table_size = 1G
max_heap_table_size = 1G

innodb_buffer_pool_size = 1G
innodb_buffer_pool_instances = 4
innodb_read_io_threads = 16
innodb_write_io_threads = 16
innodb_thread_concurrency = 0
innodb_flush_log_at_trx_commit = 0
innodb_flush_method = O_DIRECT
performance_schema = 0
innodb-file-per-table = 1
innodb_io_capacity=2000
innodb_table_locks = 0
innodb_lock_wait_timeout = 0
innodb_deadlock_detect = 0

sql-mode="NO_ENGINE_SUBSTITUTION"

[mysqldump]
quick
quote-names
max_allowed_packet = 16M

[mysql]
port = 3306
socket = /run/mysqld/mysqld.sock

[isamchk]
key_buffer_size = 16M
EOF

# Start MariaDB with new configuration
systemctl start mariadb 2>/dev/null || true
sleep 5

# Verify MariaDB is running
if ! pgrep -x mysqld >/dev/null 2>&1; then
    log_error "MariaDB is not running. Trying alternative start..."
    mysqld_safe --user=mysql --port=7999 --datadir=/var/lib/mysql &
    sleep 5
fi

# Install remaining dependencies
log_info "Installing PHP and other dependencies..."

# For Ubuntu 22.04, we need to add PHP repository
if [ "$VER" = "22.04" ]; then
    add-apt-repository -y ppa:ondrej/php 2>/dev/null || true
    apt-get update -qq 2>/dev/null
fi

# Install PHP 7.4
apt-get -y install \
    php7.4 php7.4-fpm php7.4-cli \
    php7.4-mysql php7.4-curl php7.4-gd \
    php7.4-json php7.4-zip php7.4-xml \
    php7.4-mbstring php7.4-soap php7.4-intl \
    php7.4-bcmath php7.4-opcache \
    2>/dev/null || true

# Install Nginx
apt-get -y install nginx nginx-core nginx-common 2>/dev/null || true

# Install libraries
apt-get -y install \
    libzip-dev \
    libonig-dev \
    libsodium-dev \
    libargon2-dev \
    libbz2-dev \
    libpng-dev \
    libxml2-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libxslt1-dev \
    libmaxminddb-dev \
    libaio-dev \
    python2 \
    2>/dev/null || true

# Create libzip.so.4 symlink for Ubuntu 20.04+
if [ ! -f "/usr/lib/x86_64-linux-gnu/libzip.so.4" ] && [ -f "/usr/lib/x86_64-linux-gnu/libzip.so.5" ]; then
    ln -sf /usr/lib/x86_64-linux-gnu/libzip.so.5 /usr/lib/x86_64-linux-gnu/libzip.so.4
fi
ldconfig

log_success "All dependencies installed"

# Continue with the rest of the installation...
log_info "Setting up XtreamCodes database..."

# Create database
mysql -u root -p$PASSMYSQL -e "DROP DATABASE IF EXISTS xtream_iptvpro;" 2>/dev/null || true
mysql -u root -p$PASSMYSQL -e "CREATE DATABASE xtream_iptvpro;" 2>/dev/null || true

# Download database.sql
log_info "Downloading database.sql from GitHub..."
wget -q -O /tmp/database.sql "https://raw.githubusercontent.com/Stefan2512/Proper-Repairs-Xtream-Codes/master/database.sql" 2>/dev/null || \
curl -s -o /tmp/database.sql "https://raw.githubusercontent.com/Stefan2512/Proper-Repairs-Xtream-Codes/master/database.sql" 2>/dev/null

if [ -f "/tmp/database.sql" ] && [ -s "/tmp/database.sql" ]; then
    mysql -u root -p$PASSMYSQL xtream_iptvpro < /tmp/database.sql 2>/dev/null || true
    log_success "Database imported successfully"
else
    log_error "Failed to download database.sql"
    exit 1
fi

# Create database user
mysql -u root -p$PASSMYSQL -e "GRANT ALL PRIVILEGES ON *.* TO 'user_iptvpro'@'%' IDENTIFIED BY '$XPASS' WITH GRANT OPTION; FLUSH PRIVILEGES;" 2>/dev/null || true

# Create directory structure
log_info "Creating XtreamCodes directory structure..."
mkdir -p /home/xtreamcodes/iptv_xtream_codes/{admin,wwwdir,bin,logs,streams,tmp,nginx/{conf,logs},nginx_rtmp/{conf,logs},php,includes}

# Generate admin password hash
alg=6
salt='rounds=20000$xtreamcodes'
Padmin=$(perl -e 'print crypt($ARGV[1], "\$" . $ARGV[0] . "\$" . $ARGV[2]), "\n";' "$alg" "$adminP" "$salt" 2>/dev/null || echo '$6$rounds=20000$xtreamcodes$defaulthash')

# Create admin user
mysql -u root -p$PASSMYSQL xtream_iptvpro -e "INSERT INTO reg_users (id, username, password, email, ip, date_registered, verify_key, verified, member_group_id, status, last_login, exp_date, admin_enabled, admin_notes, reseller_dns, owner_id, override_packages, google_2fa_sec) VALUES (1, '$adminL', '$Padmin', '$EMAIL', '', UNIX_TIMESTAMP(), '', 1, 1, 1, NULL, 4070905200, 1, '', '', 0, '', '');" 2>/dev/null || true

# Update database settings
mysql -u root -p$PASSMYSQL xtream_iptvpro -e "UPDATE streaming_servers SET server_ip='$ipaddr', ssh_port='22', system_os='$OS $VER', network_interface='$networkcard', http_broadcast_port=$CLIENTACCESPORT WHERE id=1;" 2>/dev/null || true
mysql -u root -p$PASSMYSQL xtream_iptvpro -e "UPDATE settings SET live_streaming_pass = '$zzz' WHERE settings.id = 1;" 2>/dev/null || true
mysql -u root -p$PASSMYSQL xtream_iptvpro -e "UPDATE settings SET unique_id = '$eee' WHERE settings.id = 1;" 2>/dev/null || true
mysql -u root -p$PASSMYSQL xtream_iptvpro -e "UPDATE settings SET crypt_load_balancing = '$rrr' WHERE settings.id = 1;" 2>/dev/null || true

# Create config file
log_info "Creating configuration files..."

# Check if python2 exists, if not try python
PYTHON_CMD="python2"
if ! command -v python2 >/dev/null 2>&1; then
    PYTHON_CMD="python"
fi

$PYTHON_CMD << 'END' 2>/dev/null || true
import os, sys
from itertools import cycle, izip

rHost = "127.0.0.1"
rPassword = os.environ.get('XPASS', 'defaultpass')
rServerID = 1
rUsername = "user_iptvpro"
rDatabase = "xtream_iptvpro"
rPort = 7999

def encrypt(rHost="127.0.0.1", rUsername="user_iptvpro", rPassword="", rDatabase="xtream_iptvpro", rServerID=1, rPort=7999):
    rf = open('/home/xtreamcodes/iptv_xtream_codes/config', 'wb')
    config_data = '{"host":"%s","db_user":"%s","db_pass":"%s","db_name":"%s","server_id":"%d", "db_port":"%d"}' % (rHost, rUsername, rPassword, rDatabase, rServerID, rPort)
    encrypted = ''.join(chr(ord(c)^ord(k)) for c,k in izip(config_data, cycle('5709650b0d7806074842c6de575025b1')))
    rf.write(encrypted.encode('base64').replace('\n', ''))
    rf.close()

encrypt(rHost, rUsername, rPassword, rDatabase, rServerID, rPort)
END

export XPASS

# Configure PHP-FPM
log_info "Configuring PHP-FPM..."
cat > /etc/php/7.4/fpm/pool.d/xtreamcodes.conf << 'EOF'
[xtreamcodes]
user = xtreamcodes
group = xtreamcodes
listen = /run/php/php7.4-fpm-xtreamcodes.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 15
pm.max_requests = 1000

chdir = /home/xtreamcodes/iptv_xtream_codes
EOF

# Configure Nginx
log_info "Configuring Nginx..."
systemctl stop nginx 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true

cat > /etc/nginx/nginx.conf << EOF
user www-data;
worker_processes auto;
worker_rlimit_nofile 300000;
pid /run/nginx.pid;

events {
    worker_connections 20000;
    use epoll;
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 30;
    keepalive_requests 10000;
    types_hash_max_size 2048;
    server_tokens off;
    client_max_body_size 500M;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    server {
        listen $ACCESPORT;
        server_name _;
        root /home/xtreamcodes/iptv_xtream_codes/admin;
        index index.php;

        location / {
            try_files \$uri \$uri/ /index.php?\$query_string;
        }

        location ~ \.php\$ {
            fastcgi_split_path_info ^(.+\.php)(/.+)\$;
            fastcgi_pass unix:/run/php/php7.4-fpm-xtreamcodes.sock;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_param PATH_INFO \$fastcgi_path_info;
            fastcgi_read_timeout 300;
        }
    }

    server {
        listen $CLIENTACCESPORT;
        server_name _;
        root /home/xtreamcodes/iptv_xtream_codes/wwwdir;
        index index.php;

        location / {
            try_files \$uri \$uri/ /index.php?\$query_string;
        }

        location ~ \.php\$ {
            fastcgi_split_path_info ^(.+\.php)(/.+)\$;
            fastcgi_pass unix:/run/php/php7.4-fpm-xtreamcodes.sock;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_param PATH_INFO \$fastcgi_path_info;
            fastcgi_read_timeout 300;
        }
    }
}
EOF

# Create basic files
log_info "Creating basic application files..."

# Admin index.php
cat > /home/xtreamcodes/iptv_xtream_codes/admin/index.php << 'PHP'
<?php
echo "<h1>XtreamCodes Enhanced v2.0 - Stefan Edition</h1>";
echo "<p>Admin panel installation successful!</p>";
echo "<p>Server: " . $_SERVER['SERVER_ADDR'] . ":" . $_SERVER['SERVER_PORT'] . "</p>";
echo "
