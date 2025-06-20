#!/usr/bin/env bash
# XtreamCodes Enhanced Installer v2.0 - Stefan Edition with MariaDB VM Fix
# =============================================
# Repository: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes
# Version: 2.0 - Fixed for VM installations with proper MariaDB handling

set +e

LOG_DIR="/var/log/xtreamcodes"
mkdir -p "$LOG_DIR" 2>/dev/null
logfile="$LOG_DIR/$(date +%Y-%m-%d_%H.%M.%S)_install.log"
touch "$logfile" 2>/dev/null

log() { local level=$1; shift; local message="$@"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] $level: $message" | tee -a "$logfile"; }
log_step() { echo "🔧 $1"; log "STEP" "$1"; }
log_info() { echo "ℹ️  $1"; log "INFO" "$1"; }
log_success() { echo "✅ $1"; log "SUCCESS" "$1"; }
log_error() { echo "❌ $1"; log "ERROR" "$1"; }
log_warning() { echo "⚠️  $1"; log "WARNING" "$1"; }

tz=""; adminL=""; adminP=""; ACCESPORT=""; CLIENTACCESPORT=""; APACHEACCESPORT=""; EMAIL=""; PASSMYSQL=""; silent="no"

while getopts ":t:a:p:o:c:r:e:m:s:h" option 2>/dev/null; do
    case "${option}" in
        t) tz=${OPTARG} ;; a) adminL=${OPTARG} ;; p) adminP=${OPTARG} ;;
        o) ACCESPORT=${OPTARG} ;; c) CLIENTACCESPORT=${OPTARG} ;;
        r) APACHEACCESPORT=${OPTARG} ;; e) EMAIL=${OPTARG} ;; m) PASSMYSQL=${OPTARG} ;;
        s) silent="yes" ;;
        h) echo "XtreamCodes Enhanced Installer v2.0 - Stefan Edition with VM Fix"; exit 0 ;;
        *) ;;
    esac
done

clear
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│        XtreamCodes Enhanced Installer v2.0 - Stefan Edition        │"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo "🚀 Repository: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes"

log_step "Detecting system information"
OS="Unknown"; VER="Unknown"
if [ -f /etc/lsb-release ]; then
    OS=$(grep DISTRIB_ID /etc/lsb-release | sed 's/^.*=//' 2>/dev/null || echo "Unknown")
    VER=$(grep DISTRIB_RELEASE /etc/lsb-release | sed 's/^.*=//' 2>/dev/null || echo "Unknown")
elif [ -f /etc/os-release ]; then
    OS=$(grep -w ID /etc/os-release | sed 's/^.*=//' 2>/dev/null || echo "Unknown")
    VER=$(grep VERSION_ID /etc/os-release | sed 's/^.*"\(.*\)"/\1/' | head -n 1 2>/dev/null || echo "Unknown")
fi
ARCH=$(uname -m 2>/dev/null || echo "Unknown")
log_info "Detected: $OS $VER $ARCH"

if [[ "$OS" = "Ubuntu" && ("$VER" = "18.04" || "$VER" = "20.04" || "$VER" = "22.04") && "$ARCH" == "x86_64" ]]; then
    log_success "System compatibility check passed"
else
    log_error "This installer only supports Ubuntu 18.04/20.04/22.04 x86_64"
    exit 1
fi

log_step "Checking prerequisites"
if [ $UID -ne 0 ]; then
    log_error "This installer must be run as root"
    exit 1
fi

log_success "Prerequisites check passed"

XPASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16 || echo "XtreamPass2024")
zzz=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20 || echo "LiveStreamPass2024")
eee=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10 || echo "UniqueId24")
rrr=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20 || echo "CryptLoadBalance2024")

tz=${tz:-"Europe/Bucharest"}
adminL=${adminL:-"admin"}
adminP=${adminP:-"admin123"}
EMAIL=${EMAIL:-"admin@example.com"}
PASSMYSQL=${PASSMYSQL:-"mysqlPassWord1da2da3Nu"}
ACCESPORT=${ACCESPORT:-2086}
CLIENTACCESPORT=${CLIENTACCESPORT:-8080}
APACHEACCESPORT=${APACHEACCESPORT:-3672}

export DEBIAN_FRONTEND=noninteractive
log_step "Preparing system for installation"
apt-get update -qq 2>/dev/null
log_success "System prepared"

log_step "Installing system dependencies"
apt-get -y install \
    curl wget unzip zip software-properties-common \
    net-tools daemonize perl cron sudo lsb-release \
    apt-transport-https ca-certificates gnupg \
    >>"$logfile" 2>>"$logfile"
log_success "Dependencies installed successfully"
log_step "Installing PHP and other dependencies..."

if [ "$VER" = "22.04" ]; then
    log_info "Ubuntu 22.04 detected. Adding PHP 7.4 repository..."
    apt install software-properties-common -y >>"$logfile" 2>>"$logfile"
    add-apt-repository -y ppa:ondrej/php >>"$logfile" 2>>"$logfile"
    apt-get update -qq >>"$logfile" 2>>"$logfile"
fi

log_info "Installing PHP 7.4 packages..."
apt-get -y install \
    php7.4 php7.4-fpm php7.4-cli \
    php7.4-mysql php7.4-curl php7.4-gd \
    php7.4-json php7.4-zip php7.4-xml \
    php7.4-mbstring php7.4-soap php7.4-intl \
    php7.4-bcmath php7.4-opcache >>"$logfile" 2>>"$logfile"

if ! php7.4 -v >/dev/null 2>&1; then
    log_warning "PHP 7.4 not available. Falling back to PHP 8.1..."
    apt-get -y install \
        php php-fpm php-cli \
        php-mysql php-curl php-gd \
        php-json php-zip php-xml \
        php-mbstring php-soap php-intl \
        php-bcmath php-opcache >>"$logfile" 2>>"$logfile"

    PHP_VERSION="8.1"
    PHP_SOCK="/run/php/php8.1-fpm.sock"
else
    PHP_VERSION="7.4"
    PHP_SOCK="/run/php/php7.4-fpm-xtreamcodes.sock"
fi

log_success "PHP version in use: $PHP_VERSION"

log_info "Installing Nginx..."
apt-get -y install nginx nginx-core nginx-common >>"$logfile" 2>>"$logfile"

log_info "Installing required system libraries..."
apt-get -y install \
    libzip-dev libonig-dev libsodium-dev libargon2-dev \
    libbz2-dev libpng-dev libxml2-dev libssl-dev \
    libcurl4-openssl-dev libxslt1-dev libmaxminddb-dev libaio-dev python2 \
    >>"$logfile" 2>>"$logfile"

if [ ! -f "/usr/lib/x86_64-linux-gnu/libzip.so.4" ] && [ -f "/usr/lib/x86_64-linux-gnu/libzip.so.5" ]; then
    ln -sf /usr/lib/x86_64-linux-gnu/libzip.so.5 /usr/lib/x86_64-linux-gnu/libzip.so.4
fi
ldconfig
log_success "All PHP and system dependencies installed"
log_step "Creating XtreamCodes system user"
if id "xtreamcodes" &>/dev/null; then
    log_info "User 'xtreamcodes' already exists"
else
    adduser --system --shell /bin/false --group --disabled-login xtreamcodes >/dev/null 2>&1
    log_success "User 'xtreamcodes' created"
fi

log_step "Installing and configuring MariaDB"

systemctl stop mysql 2>/dev/null || true
systemctl stop mariadb 2>/dev/null || true
killall -9 mysqld 2>/dev/null || true
killall -9 mariadbd 2>/dev/null || true
sleep 2

apt-get -y purge mysql* mariadb* >>"$logfile" 2>>"$logfile" || true
apt-get -y autoremove >>"$logfile" 2>>"$logfile" || true
apt-get -y autoclean >>"$logfile" 2>>"$logfile" || true

rm -rf /etc/mysql /etc/mariadb /var/lib/mysql /var/lib/mariadb /var/log/mysql /var/log/mariadb /run/mysqld /run/mariadb
rm -f /root/.my.cnf /home/*/.my.cnf

log_success "MySQL/MariaDB cleanup completed"

log_info "Installing MariaDB packages..."
mkdir -p /etc/mysql/mariadb.conf.d /var/lib/mysql /var/log/mysql /run/mysqld
chown mysql:mysql /var/lib/mysql /var/log/mysql /run/mysqld

debconf-set-selections <<< "mariadb-server-10.6 mysql-server/root_password password $PASSMYSQL"
debconf-set-selections <<< "mariadb-server-10.6 mysql-server/root_password_again password $PASSMYSQL"

apt-get -y install mariadb-server mariadb-client mariadb-common >>"$logfile" 2>>"$logfile"

cat > /etc/mysql/mariadb.cnf <<EOF
[mysqld]
user = mysql
port = 7999
basedir = /usr
datadir = /var/lib/mysql
tmpdir = /tmp
bind-address = 127.0.0.1
skip-external-locking
skip-name-resolve
EOF

if [ ! -d "/var/lib/mysql/mysql" ]; then
    mysql_install_db --user=mysql --datadir=/var/lib/mysql >>"$logfile" 2>>"$logfile"
fi

systemctl enable mariadb >>"$logfile" 2>>"$logfile"
systemctl start mariadb 2>/dev/null || true
sleep 5

mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$PASSMYSQL'; FLUSH PRIVILEGES;" 2>/dev/null || true
log_success "MariaDB installed and configured"

log_info "Setting up XtreamCodes database..."

mysql -u root -p$PASSMYSQL -e "DROP DATABASE IF EXISTS xtream_iptvpro;" 2>/dev/null || true
mysql -u root -p$PASSMYSQL -e "CREATE DATABASE xtream_iptvpro;" 2>/dev/null || true

log_info "Downloading database.sql from GitHub..."
wget -q -O /tmp/database.sql "https://raw.githubusercontent.com/Stefan2512/Proper-Repairs-Xtream-Codes/master/database.sql" || \
curl -s -o /tmp/database.sql "https://raw.githubusercontent.com/Stefan2512/Proper-Repairs-Xtream-Codes/master/database.sql"

if [ -f "/tmp/database.sql" ] && [ -s "/tmp/database.sql" ]; then
    mysql -u root -p$PASSMYSQL xtream_iptvpro < /tmp/database.sql
    log_success "Database imported successfully"
else
    log_error "Failed to download database.sql"
    exit 1
fi

mysql -u root -p$PASSMYSQL -e "GRANT ALL PRIVILEGES ON *.* TO 'user_iptvpro'@'%' IDENTIFIED BY '$XPASS' WITH GRANT OPTION; FLUSH PRIVILEGES;" 2>/dev/null || true

log_info "Creating XtreamCodes directory structure..."
mkdir -p /home/xtreamcodes/iptv_xtream_codes/{admin,wwwdir,bin,logs,streams,tmp,nginx/{conf,logs},nginx_rtmp/{conf,logs},php,includes}

alg=6
salt='rounds=20000$xtreamcodes'
Padmin=$(perl -e 'print crypt($ARGV[1], "\$" . $ARGV[0] . "\$" . $ARGV[2]), "\n";' "$alg" "$adminP" "$salt" 2>/dev/null || echo '$6$rounds=20000$xtreamcodes$defaulthash')

mysql -u root -p$PASSMYSQL xtream_iptvpro -e "INSERT INTO reg_users (id, username, password, email, ip, date_registered, verify_key, verified, member_group_id, status, last_login, exp_date, admin_enabled, admin_notes, reseller_dns, owner_id, override_packages, google_2fa_sec) VALUES (1, '$adminL', '$Padmin', '$EMAIL', '', UNIX_TIMESTAMP(), '', 1, 1, 1, NULL, 4070905200, 1, '', '', 0, '', '');"

mysql -u root -p$PASSMYSQL xtream_iptvpro -e "UPDATE streaming_servers SET server_ip='127.0.0.1', ssh_port='22', system_os='$OS $VER', http_broadcast_port=$CLIENTACCESPORT WHERE id=1;"
mysql -u root -p$PASSMYSQL xtream_iptvpro -e "UPDATE settings SET live_streaming_pass = '$zzz', unique_id = '$eee', crypt_load_balancing = '$rrr' WHERE id = 1;"
export XPASS

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

log_info "Configuring PHP-FPM..."
cat > /etc/php/$PHP_VERSION/fpm/pool.d/xtreamcodes.conf <<EOF
[xtreamcodes]
user = xtreamcodes
group = xtreamcodes
listen = $PHP_SOCK
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

log_info "Configuring Nginx..."
cat > /etc/nginx/nginx.conf <<EOF
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
            fastcgi_pass unix:$PHP_SOCK;
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
            fastcgi_pass unix:$PHP_SOCK;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_param PATH_INFO \$fastcgi_path_info;
            fastcgi_read_timeout 300;
        }
    }
}
EOF

log_success "Installation completed for XtreamCodes Enhanced v2.0 with PHP fallback"

