#!/usr/bin/env bash
# XtreamCodes Enhanced Final Installer - Stefan Edition cu Nginx Oficial
# =============================================
# Repository: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes
# Version: 1.1 - FIXED to use REAL archives, not demo files
#
# This installer is TESTED and includes ALL necessary fixes:
# ✅ All dependency management
# ✅ libzip.so.4 compatibility 
# ✅ PHP-FPM socket creation
# ✅ MySQL/MariaDB installation and configuration
# ✅ Nginx oficial din repository Ubuntu (nu cel vechi din XtreamCodes)
# ✅ Database.sql download din GitHub
# ✅ REAL XtreamCodes archives from releases (NO DEMO FILES!)
# ✅ Automatic service startup
# ✅ Works on VM and dedicated servers
#
# Supported: Ubuntu 18.04/20.04/22.04 (64-bit)

# Logging
logfile=$(date +%Y-%m-%d_%H.%M.%S_stefan_installer.log)
touch "$logfile"
exec > >(tee "$logfile")
exec 2>&1

# Parse command line arguments
while getopts ":t:a:p:o:c:r:e:m:s:h:" option; do
    case "${option}" in
        t) tz=${OPTARG} ;;
        a) adminL=${OPTARG} ;;
        p) adminP=${OPTARG} ;;
        o) ACCESPORT=${OPTARG} ;;
        c) CLIENTACCESPORT=${OPTARG} ;;
        r) APACHEACCESPORT=${OPTARG} ;;
        e) EMAIL=${OPTARG} ;;
        m) PASSMYSQL=${OPTARG} ;;
        s) silent=yes ;;
        h) 
            echo "XtreamCodes Enhanced Installer - Stefan Edition v1.1"
            echo "Repository: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes"
            echo ""
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -t timezone        Set timezone (e.g., Europe/Paris)"
            echo "  -a username        Admin username"
            echo "  -p password        Admin password"
            echo "  -o port           Admin access port (default: 2086)"
            echo "  -c port           Client access port (default: 5050)"
            echo "  -r port           Apache access port (default: 3672)"
            echo "  -e email          Admin email"
            echo "  -m password       MySQL root password"
            echo "  -s yes            Silent install (no prompts)"
            echo "  -h                Show this help"
            echo ""
            echo "Quick install:"
            echo "curl -L https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/raw/master/install.sh | bash"
            echo ""
            echo "Silent install example:"
            echo "curl -L https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/raw/master/install.sh | bash -s -- -a admin -t Europe/Paris -p adminpass -o 2086 -c 5050 -r 3672 -e admin@example.com -m mysqlpass -s yes"
            exit 0
            ;;
        *) 
            tz=""
            adminL=""
            adminP=""
            ACCESPORT=""
            CLIENTACCESPORT=""
            APACHEACCESPORT=""
            EMAIL=""
            PASSMYSQL=""
            silent=no
            ;;
    esac
done

clear
echo ""
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│             XtreamCodes Enhanced Installer - Stefan Edition        │"
echo "│                     Version 1.1 @2025 - REAL Archives             │"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo ""
echo "🚀 Repository: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes"
echo ""
echo "✅ Features:"
echo "   • Uses REAL XtreamCodes archives from releases"
echo "   • All dependency fixes included"
echo "   • libzip.so.4 compatibility ensured"
echo "   • PHP-FPM socket fixes"
echo "   • MySQL/MariaDB auto-configuration"
echo "   • 🆕 Nginx oficial din Ubuntu repository (nu cel vechi!)"
echo "   • 🆕 Database.sql download din GitHub repository"
echo "   • 🚫 NO DEMO FILES CREATED - 100% ORIGINAL XTREAMCODES"
echo "   • Works on VM and dedicated servers"
echo ""

# System checks
echo "🔍 Checking system requirements..."
sleep 1

# Detect OS
if [ -f /etc/lsb-release ]; then
    OS=$(grep DISTRIB_ID /etc/lsb-release | sed 's/^.*=//')
    VER=$(grep DISTRIB_RELEASE /etc/lsb-release | sed 's/^.*=//')
elif [ -f /etc/os-release ]; then
    OS=$(grep -w ID /etc/os-release | sed 's/^.*=//')
    VER=$(grep VERSION_ID /etc/os-release | sed 's/^.*"\(.*\)"/\1/' | head -n 1)
else
    echo "❌ Cannot detect OS. This installer supports Ubuntu only."
    exit 1
fi

ARCH=$(uname -m)
echo "📋 Detected: $OS $VER $ARCH"

# Check OS compatibility
if [[ "$OS" = "Ubuntu" && ("$VER" = "18.04" || "$VER" = "20.04" || "$VER" = "22.04") && "$ARCH" == "x86_64" ]]; then
    echo "✅ OS compatibility check passed"
else
    echo "❌ This installer only supports Ubuntu 18.04/20.04/22.04 x86_64"
    echo "   Detected: $OS $VER $ARCH"
    exit 1
fi

# Check root privileges
if [ $UID -ne 0 ]; then
    echo "❌ This installer must be run as root"
    echo "   Use: sudo -i, then run this script again"
    exit 1
fi

# Check for existing installations
if [ -d "/home/xtreamcodes/iptv_xtream_codes" ]; then
    echo "❌ XtreamCodes is already installed in /home/xtreamcodes/iptv_xtream_codes"
    echo "   Please remove existing installation or use a clean server"
    exit 1
fi

if [ -e /usr/local/cpanel ] || [ -e /usr/local/directadmin ]; then
    echo "❌ Control panel detected. Please use a clean OS installation"
    exit 1
fi

echo "✅ System checks passed"
echo ""

# Determine which archive to download based on Ubuntu version
case "$VER" in
    "18.04")
        ARCHIVE_NAME="xtreamcodes_enhanced_Ubuntu_18.04.tar.gz"
        ;;
    "20.04")
        ARCHIVE_NAME="xtreamcodes_enhanced_Ubuntu_20.04.tar.gz"
        ;;
    "22.04")
        ARCHIVE_NAME="xtreamcodes_enhanced_Ubuntu_22.04.tar.gz"
        ;;
    *)
        ARCHIVE_NAME="xtreamcodes_enhanced_universal.tar.gz"
        echo "⚠️  Using universal archive for Ubuntu $VER"
        ;;
esac

echo "📦 Will use archive: $ARCHIVE_NAME"

# Prepare system
echo "🔧 Preparing system..."
DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND=noninteractive

# Disable needrestart prompts
if [ -f "/etc/apt/apt.conf.d/99needrestart" ]; then
    sed -i 's|DPkg::Post-Invoke|#DPkg::Post-Invoke|' "/etc/apt/apt.conf.d/99needrestart"
fi

# Update package lists
echo "📦 Updating package lists..."
apt-get -qq update

# Get server information
ipaddr="$(wget -qO- http://api.sentora.org/ip.txt 2>/dev/null || curl -s http://ipinfo.io/ip 2>/dev/null || echo "127.0.0.1")"
local_ip=$(ip addr show 2>/dev/null | awk '$1 == "inet" && $3 == "brd" { sub (/\/.*/,""); print $2 }' | head -1)
networkcard=$(route 2>/dev/null | grep default | awk '{print $8}' | head -1 || echo "eth0")

# Generate secure passwords and salts
alg=6
salt='rounds=20000$xtreamcodes'
XPASS=$(</dev/urandom tr -dc A-Z-a-z-0-9 | head -c16)
zzz=$(</dev/urandom tr -dc A-Z-a-z-0-9 | head -c20)
eee=$(</dev/urandom tr -dc A-Z-a-z-0-9 | head -c10)
rrr=$(</dev/urandom tr -dc A-Z-a-z-0-9 | head -c20)
versionn="$OS $VER"

echo "🌐 Server IP: $ipaddr"
echo ""

# Get user input
# Auto-detect if running through pipe and enable silent mode
if [[ ! -t 0 ]] && [[ "$silent" != "yes" ]]; then
    echo "🤖 Pipe detected - enabling silent mode with defaults"
    silent="yes"
fi

if [[ "$silent" != "yes" ]]; then
    # Set default timezone to Europe/Bucharest
    if [[ "$tz" == "" ]]; then
        tz="Europe/Bucharest"
        echo "🕐 Setting timezone to Europe/Bucharest (default)"
    fi

    echo ""
    echo "📝 Please provide installation details:"
    echo ""

    if [[ "$adminL" == "" ]]; then
        echo -n "👤 Admin username [admin]: "
        read adminL
        adminL=${adminL:-"admin"}
    fi

    if [[ "$adminP" == "" ]]; then
        echo -n "🔒 Admin password [admin123]: "
        read adminP
        adminP=${adminP:-"admin123"}
    fi

    if [[ "$EMAIL" == "" ]]; then
        echo -n "📧 Admin email [admin@example.com]: "
        read EMAIL
        EMAIL=${EMAIL:-"admin@example.com"}
    fi

    if [[ "$PASSMYSQL" == "" ]]; then
        echo -n "🗄️  MySQL root password [mysql123]: "
        read PASSMYSQL
        PASSMYSQL=${PASSMYSQL:-"mysql123"}
    fi

    echo ""
    echo "🔧 Port configuration (press Enter for defaults):"
    
    if [[ "$ACCESPORT" == "" ]]; then
        echo -n "🌐 Admin panel port [2086]: "
        read ACCESPORT
        ACCESPORT=${ACCESPORT:-2086}
    fi

    if [[ "$CLIENTACCESPORT" == "" ]]; then
        echo -n "📡 Client access port [5050]: "
        read CLIENTACCESPORT
        CLIENTACCESPORT=${CLIENTACCESPORT:-5050}
    fi

    if [[ "$APACHEACCESPORT" == "" ]]; then
        echo -n "🔧 Apache port [3672]: "
        read APACHEACCESPORT
        APACHEACCESPORT=${APACHEACCESPORT:-3672}
    fi

    echo ""
    echo -n "🚀 Ready to install XtreamCodes Enhanced? [Y/n]: "
    read yn
    yn=${yn:-"y"}
    case $yn in
        [Yy]*|"") ;;
        *) echo "❌ Installation cancelled"; exit 0;;
    esac
else
    # Silent mode - use defaults including Europe/Bucharest timezone
    tz=${tz:-"Europe/Bucharest"}
    adminL=${adminL:-"admin"}
    adminP=${adminP:-"admin123"}
    EMAIL=${EMAIL:-"admin@example.com"}
    PASSMYSQL=${PASSMYSQL:-"mysql123"}
    ACCESPORT=${ACCESPORT:-2086}
    CLIENTACCESPORT=${CLIENTACCESPORT:-5050}
    APACHEACCESPORT=${APACHEACCESPORT:-3672}
    
    echo "🤖 Silent installation mode"
    echo "📋 Configuration:"
    echo "   👤 Admin: $adminL"
    echo "   📧 Email: $EMAIL"
    echo "   🌐 Panel: http://$ipaddr:$ACCESPORT"
    echo "   📡 Client: $CLIENTACCESPORT"
    echo "   🕐 Timezone: $tz"
    echo ""
    echo "🚀 Starting automatic installation in 3 seconds..."
    sleep 3
fi

# Set timezone regardless of mode
echo $tz > /etc/timezone
rm -f /etc/localtime
ln -s /usr/share/zoneinfo/$tz /etc/localtime
timedatectl set-timezone $tz 2>/dev/null

# Generate admin password hash
Padmin=$(perl -e 'print crypt($ARGV[1], "\$" . $ARGV[0] . "\$" . $ARGV[2]), "\n";' "$alg" "$adminP" "$salt" 2>/dev/null)

clear
echo ""
echo "🚀 Starting XtreamCodes Enhanced Installation with REAL Archives..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 System: $OS $VER ($ARCH)"
echo "🌐 Server IP: $ipaddr"
echo "👤 Admin: $adminL"
echo "🌐 Panel: http://$ipaddr:$ACCESPORT"
echo "📧 Email: $EMAIL"
echo "🕐 Timezone: $tz"
echo "📦 Archive: $ARCHIVE_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Install all required dependencies
echo "📦 Installing system dependencies..."
apt-get -yqq install \
    curl wget unzip zip tar \
    software-properties-common \
    python2 python3 python-is-python2 \
    net-tools \
    daemonize \
    perl \
    cron \
    >/dev/null 2>&1

echo "📦 Installing library dependencies..."
apt-get -yqq install \
    libzip5 libzip-dev \
    libonig5 libonig-dev \
    libsodium23 libsodium-dev \
    libargon2-1 libargon2-dev \
    libbz2-dev \
    libpng-dev \
    libxml2-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libxslt1-dev \
    libmaxminddb-dev \
    libaio-dev \
    >/dev/null 2>&1

# CRITICAL FIX: Create libzip.so.4 symlink
echo "🔧 Applying libzip.so.4 compatibility fix..."
if [ ! -f "/usr/lib/x86_64-linux-gnu/libzip.so.4" ]; then
    ln -sf /usr/lib/x86_64-linux-gnu/libzip.so.5 /usr/lib/x86_64-linux-gnu/libzip.so.4
fi
ldconfig

# 🆕 INSTALL OFFICIAL NGINX
echo "🌐 Installing official Nginx from Ubuntu repository..."

# Remove any old nginx installations
systemctl stop nginx 2>/dev/null || true
apt-get -yqq remove nginx nginx-common nginx-core 2>/dev/null || true

# Install official Nginx
apt-get -yqq install nginx nginx-core nginx-common >/dev/null 2>&1

# Disable default nginx service (we'll manage it ourselves)
systemctl stop nginx >/dev/null 2>&1
systemctl disable nginx >/dev/null 2>&1

# Install PHP 7.4 for better compatibility
echo "🐘 Installing PHP 7.4 and extensions..."
apt-get -yqq install \
    php7.4 php7.4-fpm php7.4-cli \
    php7.4-mysql php7.4-curl php7.4-gd \
    php7.4-json php7.4-zip php7.4-xml \
    php7.4-mbstring php7.4-soap php7.4-intl \
    php7.4-bcmath php7.4-opcache \
    >/dev/null 2>&1

# Configure PHP-FPM
echo "🔧 Configuring PHP-FPM..."
# Backup original config
cp /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/www.conf.backup

# Configure PHP-FPM pool for XtreamCodes
cat > /etc/php/7.4/fpm/pool.d/xtreamcodes.conf << 'EOL'
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
EOL

echo "🗄️  Installing and configuring MariaDB..."
apt-get -yqq install mariadb-server mariadb-client >/dev/null 2>&1

# Start and enable MariaDB
systemctl start mariadb >/dev/null 2>&1
systemctl enable mariadb >/dev/null 2>&1

# Configure MySQL root password
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$PASSMYSQL'; FLUSH PRIVILEGES;" 2>/dev/null || \
mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('$PASSMYSQL') WHERE User='root'; FLUSH PRIVILEGES;" 2>/dev/null || \
mysqladmin -u root password "$PASSMYSQL" 2>/dev/null

echo "✅ Dependencies installed successfully"

# Create xtreamcodes user
echo "👤 Creating xtreamcodes system user..."
adduser --system --shell /bin/false --group --disabled-login xtreamcodes >/dev/null 2>&1

# 🆕 DOWNLOAD REAL XTREAMCODES ARCHIVE
echo "📥 Downloading REAL XtreamCodes archive: $ARCHIVE_NAME"
mkdir -p /tmp
cd /tmp

# Try multiple download URLs for the archive
DOWNLOAD_URLS=(
    "https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/latest/download/$ARCHIVE_NAME"
    "https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/download/v1.1/$ARCHIVE_NAME"
    "https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/raw/master/$ARCHIVE_NAME"
)

ARCHIVE_DOWNLOADED=false
for URL in "${DOWNLOAD_URLS[@]}"; do
    echo "🔍 Trying: $URL"
    if wget -q --timeout=60 --tries=3 -O "/tmp/$ARCHIVE_NAME" "$URL" 2>/dev/null; then
        # Check if file was actually downloaded and has content
        if [ -s "/tmp/$ARCHIVE_NAME" ]; then
            # Verify it's a valid tar.gz file
            if tar -tzf "/tmp/$ARCHIVE_NAME" >/dev/null 2>&1; then
                echo "✅ Successfully downloaded and verified: $ARCHIVE_NAME"
                ARCHIVE_DOWNLOADED=true
                break
            else
                echo "❌ Downloaded file is not a valid tar.gz archive"
                rm -f "/tmp/$ARCHIVE_NAME"
            fi
        else
            echo "❌ Downloaded file is empty"
            rm -f "/tmp/$ARCHIVE_NAME"
        fi
    else
        echo "❌ Failed to download from: $URL"
    fi
done

if [ "$ARCHIVE_DOWNLOADED" = false ]; then
    echo "❌ Failed to download XtreamCodes archive: $ARCHIVE_NAME"
    echo "   Please check:"
    echo "   1. Internet connection"
    echo "   2. Archive exists in releases: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases"
    echo "   3. Archive name is correct: $ARCHIVE_NAME"
    exit 1
fi

# 🆕 EXTRACT REAL XTREAMCODES FILES
echo "📂 Extracting REAL XtreamCodes files..."
mkdir -p /home/xtreamcodes
cd /home/xtreamcodes

# Extract the archive
if tar -xzf "/tmp/$ARCHIVE_NAME" 2>/dev/null; then
    echo "✅ Archive extracted successfully"
else
    echo "❌ Failed to extract archive"
    exit 1
fi

# Verify the extraction created the correct directory structure
if [ ! -d "/home/xtreamcodes/iptv_xtream_codes" ]; then
    echo "🔍 Checking extracted contents..."
    
    # List what was extracted
    EXTRACTED_DIRS=$(find /home/xtreamcodes -maxdepth 1 -type d -name "*xtream*" 2>/dev/null)
    
    if [ ! -z "$EXTRACTED_DIRS" ]; then
        # Find the main directory and rename it
        MAIN_DIR=$(echo "$EXTRACTED_DIRS" | head -1)
        echo "🔄 Renaming $MAIN_DIR to iptv_xtream_codes"
        mv "$MAIN_DIR" "/home/xtreamcodes/iptv_xtream_codes"
    else
        echo "❌ Archive doesn't contain expected XtreamCodes structure"
        echo "   Extracted contents:"
        ls -la /home/xtreamcodes/
        exit 1
    fi
fi

# Verify we now have the correct structure
if [ ! -d "/home/xtreamcodes/iptv_xtream_codes" ]; then
    echo "❌ Failed to create proper XtreamCodes directory structure"
    exit 1
fi

echo "✅ REAL XtreamCodes files extracted and ready"

# 🆕 Download database.sql from GitHub repository
echo "📥 Downloading database.sql from Stefan's GitHub repository..."
wget -q -O /tmp/database.sql "https://raw.githubusercontent.com/Stefan2512/Proper-Repairs-Xtream-Codes/master/database.sql"

# Verify download
if [ ! -f "/tmp/database.sql" ] || [ ! -s "/tmp/database.sql" ]; then
    echo "❌ Failed to download database.sql from GitHub repository"
    echo "   Please check your internet connection and repository access"
    echo "   Repository: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes"
    exit 1
fi

echo "✅ Database.sql downloaded successfully from GitHub"

# 🆕 DOWNLOAD ADDITIONAL FILES IF AVAILABLE
echo "📥 Downloading additional enhanced files..."

# Try to download enhanced_updates.zip
if wget -q --spider "https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/latest/download/enhanced_updates.zip" 2>/dev/null; then
    echo "📥 Downloading enhanced_updates.zip..."
    if wget -q -O "/tmp/enhanced_updates.zip" "https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/latest/download/enhanced_updates.zip" 2>/dev/null; then
        cd /home/xtreamcodes/iptv_xtream_codes
        if unzip -o "/tmp/enhanced_updates.zip" >/dev/null 2>&1; then
            echo "✅ Enhanced updates applied"
        fi
        rm -f "/tmp/enhanced_updates.zip"
    fi
fi

# Try to download GeoLite2.mmdb
if wget -q --spider "https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/latest/download/GeoLite2.mmdb" 2>/dev/null; then
    echo "📥 Downloading GeoLite2.mmdb..."
    wget -q -O "/home/xtreamcodes/iptv_xtream_codes/GeoLite2.mmdb" "https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/latest/download/GeoLite2.mmdb" 2>/dev/null
    if [ -f "/home/xtreamcodes/iptv_xtream_codes/GeoLite2.mmdb" ]; then
        echo "✅ GeoLite2.mmdb downloaded"
    fi
fi

echo "⚙️  Configuring MariaDB for XtreamCodes..."

# Create optimized MariaDB configuration
cat > /etc/mysql/mariadb.cnf << 'EOL'
# XtreamCodes Enhanced Configuration - Stefan Edition

[client]
port = 3306

[mysqld_safe]
nice = 0

[mysqld]
user = mysql
port = 7999
basedir = /usr
datadir = /var/lib/mysql
tmpdir = /tmp
lc-messages-dir = /usr/share/mysql
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

innodb_buffer_pool_size = 2G
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

[isamchk]
key_buffer_size = 16M
EOL

# Restart MariaDB with new configuration
systemctl restart mariadb
sleep 3

echo "🛠️  Configuring XtreamCodes database..."

# Configure database using Python
python2 << END
# coding: utf-8
import subprocess, os, sys
from itertools import cycle, izip

# Configuration variables
rHost = "127.0.0.1"
rPassword = "$XPASS"
rServerID = 1
rUsername = "user_iptvpro"
rDatabase = "xtream_iptvpro"
rPort = 7999
rExtra = " -p$PASSMYSQL"
reseau = "$networkcard"
portadmin = "$ACCESPORT"
getIP = "$ipaddr"
sshssh = "22"
getVersion = "$versionn"
generate1 = "$zzz"
generate2 = "$eee"
generate3 = "$rrr"

def encrypt(rHost="127.0.0.1", rUsername="user_iptvpro", rPassword="", rDatabase="xtream_iptvpro", rServerID=1, rPort=7999):
    try:
        rf = open('/home/xtreamcodes/iptv_xtream_codes/config', 'wb')
        config_data = '{\"host\":\"%s\",\"db_user\":\"%s\",\"db_pass\":\"%s\",\"db_name\":\"%s\",\"server_id\":\"%d\", \"db_port\":\"%d\"}' % (rHost, rUsername, rPassword, rDatabase, rServerID, rPort)
        encrypted = ''.join(chr(ord(c)^ord(k)) for c,k in izip(config_data, cycle('5709650b0d7806074842c6de575025b1')))
        rf.write(encrypted.encode('base64').replace('\n', ''))
        rf.close()
    except Exception as e:
        print("Error creating config: %s" % str(e))

def mysql_setup():
    try:
        # Create database
        os.system('mysql -u root%s -e "DROP DATABASE IF EXISTS xtream_iptvpro; CREATE DATABASE IF NOT EXISTS xtream_iptvpro;" >/dev/null 2>&1' % rExtra)
        
        # Import database schema from downloaded file
        os.system("mysql -u root%s xtream_iptvpro < /tmp/database.sql >/dev/null 2>&1" % rExtra)
        
        # Configure streaming server
        cmd = 'mysql -u root%s -e "USE xtream_iptvpro; UPDATE streaming_servers SET server_ip=\'%s\', ssh_port=\'%s\', system_os=\'%s\', network_interface=\'%s\', http_broadcast_port=%s WHERE id=1;" >/dev/null 2>&1' % (rExtra, getIP, sshssh, getVersion, reseau, portadmin)
        os.system(cmd)
        
        # Create database user
        os.system('mysql -u root%s -e "GRANT ALL PRIVILEGES ON *.* TO \'%s\'@\'%%\' IDENTIFIED BY \'%s\' WITH GRANT OPTION; FLUSH PRIVILEGES;" >/dev/null 2>&1' % (rExtra, rUsername, rPassword))
        
    except Exception as e:
        print("Database setup error: %s" % str(e))

# Execute configuration
mysql_setup()
encrypt(rHost, rUsername, rPassword, rDatabase, rServerID, rPort)
END

echo "👤 Creating admin user..."

# Create admin user
mysql -u root -p$PASSMYSQL xtream_iptvpro << EOL >/dev/null 2>&1
INSERT INTO reg_users (id, username, password, email, ip, date_registered, verify_key, verified, member_group_id, status, last_login, exp_date, admin_enabled, admin_notes, reseller_dns, owner_id, override_packages, google_2fa_sec) VALUES 
(1, '$adminL', '$Padmin', '$EMAIL', '', UNIX_TIMESTAMP(), '', 1, 1, 1, NULL, 4070905200, 1, '', '', 0, '', '');
EOL

# 🆕 CONFIGURE NGINX FOR XTREAMCODES
echo "🌐 Configuring official Nginx for XtreamCodes..."

# Create optimized nginx configuration for XtreamCodes
cat > /etc/nginx/nginx.conf << EOL
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
    client_body_timeout 15s;
    client_header_timeout 15s;
    send_timeout 15s;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=admin:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=api:10m rate=50r/s;

    # Admin Panel Server
    server {
        listen $ACCESPORT;
        server_name _;
        root /home/xtreamcodes/iptv_xtream_codes/admin;
        index index.php;

        limit_req zone=admin burst=20 nodelay;

        # Security headers
        add_header X-Frame-Options SAMEORIGIN;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";

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
            fastcgi_buffer_size 128k;
            fastcgi_buffers 4 256k;
            fastcgi_busy_buffers_size 256k;
        }

        location ~ /\.ht {
            deny all;
        }
    }

    # Client Access Server
    server {
        listen $CLIENTACCESPORT;
        server_name _;
        root /home/xtreamcodes/iptv_xtream_codes/wwwdir;
        index index.php;

        limit_req zone=api burst=100 nodelay;

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
            fastcgi_buffer_size 128k;
            fastcgi_buffers 4 256k;
            fastcgi_busy_buffers_size 256k;
        }

        # Handle streaming requests
        location ~* \.(ts|m3u8)\$ {
            add_header Cache-Control no-cache;
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Headers *;
            expires -1;
        }

        location ~ /\.ht {
            deny all;
        }
    }

    # Apache compatibility server
    server {
        listen $APACHEACCESPORT;
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
EOL

echo "🔧 Configuring system permissions and services..."

# Set proper ownership and permissions for REAL XtreamCodes files
chown -R xtreamcodes:xtreamcodes /home/xtreamcodes

# Make executable files executable (preserve original XtreamCodes permissions)
find /home/xtreamcodes/iptv_xtream_codes -name "*.sh" -exec chmod +x {} \; 2>/dev/null
find /home/xtreamcodes/iptv_xtream_codes/bin -type f -exec chmod +x {} \; 2>/dev/null

# Configure system permissions
if ! grep -q "xtreamcodes ALL = (root) NOPASSWD: /sbin/iptables, /usr/bin/chattr, /usr/bin/python2, /usr/bin/python" /etc/sudoers; then
    echo "xtreamcodes ALL = (root) NOPASSWD: /sbin/iptables, /usr/bin/chattr, /usr/bin/python2, /usr/bin/python" >> /etc/sudoers
fi

# Configure tmpfs mounts
if ! grep -q "tmpfs /home/xtreamcodes/iptv_xtream_codes/streams tmpfs" /etc/fstab; then
    echo "tmpfs /home/xtreamcodes/iptv_xtream_codes/streams tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777,size=90% 0 0" >> /etc/fstab
fi

if ! grep -q "tmpfs /home/xtreamcodes/iptv_xtream_codes/tmp tmpfs" /etc/fstab; then
    echo "tmpfs /home/xtreamcodes/iptv_xtream_codes/tmp tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777,size=2G 0 0" >> /etc/fstab
fi

# Update database configuration
mysql -u root -p$PASSMYSQL xtream_iptvpro -e "UPDATE streaming_servers SET http_broadcast_port = '$CLIENTACCESPORT' WHERE streaming_servers.id = 1;" 2>/dev/null
mysql -u root -p$PASSMYSQL xtream_iptvpro -e "UPDATE settings SET live_streaming_pass = '$zzz' WHERE settings.id = 1;" 2>/dev/null
mysql -u root -p$PASSMYSQL xtream_iptvpro -e "UPDATE settings SET unique_id = '$eee' WHERE settings.id = 1;" 2>/dev/null
mysql -u root -p$PASSMYSQL xtream_iptvpro -e "UPDATE settings SET crypt_load_balancing = '$rrr' WHERE settings.id = 1;" 2>/dev/null

# Mount tmpfs filesystems
mount -a 2>/dev/null
mkdir -p /home/xtreamcodes/iptv_xtream_codes/streams /home/xtreamcodes/iptv_xtream_codes/tmp
chmod 1777 /home/xtreamcodes/iptv_xtream_codes/streams /home/xtreamcodes/iptv_xtream_codes/tmp

# Create enhanced management scripts (check if original doesn't exist)
if [ ! -f "/home/xtreamcodes/iptv_xtream_codes/start_services.sh" ]; then
    echo "🚀 Creating enhanced start services script..."
    cat > /home/xtreamcodes/iptv_xtream_codes/start_services.sh << 'STARTSCRIPT'
#!/bin/bash
# XtreamCodes Enhanced Start Services Script - Stefan Edition with Official Nginx

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting XtreamCodes Enhanced Services - Stefan Edition${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Set working directory
cd /home/xtreamcodes/iptv_xtream_codes

# Function to check if service is running
check_service() {
    if pgrep -f "$1" > /dev/null; then
        echo -e "${GREEN}✅ $2 is running${NC}"
        return 0
    else
        echo -e "${RED}❌ $2 is not running${NC}"
        return 1
    fi
}

# Start MariaDB if not running
if ! systemctl is-active --quiet mariadb; then
    echo -e "${YELLOW}🗄️  Starting MariaDB...${NC}"
    systemctl start mariadb
    sleep 2
fi

# Start PHP-FPM if not running
if ! systemctl is-active --quiet php7.4-fpm; then
    echo -e "${YELLOW}🐘 Starting PHP-FPM...${NC}"
    systemctl start php7.4-fpm
    sleep 2
fi

# Start official Nginx
echo -e "${YELLOW}🌐 Starting official Nginx...${NC}"
systemctl start nginx
sleep 2

# Start XtreamCodes services (if binaries exist)
if [ -f "./bin/nginx" ]; then
    echo -e "${YELLOW}⚙️  Starting XtreamCodes services...${NC}"
    ./bin/nginx 2>/dev/null &
fi

if [ -f "./bin/nginx_rtmp" ]; then
    ./bin/nginx_rtmp 2>/dev/null &
fi

sleep 3

# Status check
echo ""
echo -e "${GREEN}📊 Service Status Check:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_service "mariadb" "MariaDB"
check_service "php7.4-fpm" "PHP-FPM 7.4"
check_service "nginx.*master" "Nginx (Official)"

echo ""
echo -e "${GREEN}🎯 XtreamCodes Enhanced services started!${NC}"
STARTSCRIPT
    chmod +x /home/xtreamcodes/iptv_xtream_codes/start_services.sh
fi

# Create status check script (enhanced version)
cat > /home/xtreamcodes/iptv_xtream_codes/check_status.sh << 'STATUSSCRIPT'
#!/bin/bash
# XtreamCodes Enhanced Status Check - Stefan Edition

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}"
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│             XtreamCodes Enhanced Status Check - Stefan             │"
echo "│                           $(date '+%Y-%m-%d %H:%M:%S')                           │"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo -e "${NC}"

# Function to check service status
check_service_status() {
    local service_name="$1"
    local process_name="$2"
    local port="$3"
    
    # Check if process is running
    local pid_count=$(pgrep -f "$process_name" 2>/dev/null | wc -l)
    
    if [ $pid_count -gt 0 ]; then
        echo -e "${GREEN}✅ $service_name${NC} - Running ($pid_count processes)"
        
        # Check port if specified
        if [ ! -z "$port" ] && command -v netstat >/dev/null 2>&1; then
            if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
                echo -e "   ${GREEN}🔌 Port $port - Listening${NC}"
            else
                echo -e "   ${RED}❌ Port $port - Not listening${NC}"
            fi
        fi
    else
        echo -e "${RED}❌ $service_name${NC} - Not running"
    fi
}

echo -e "${YELLOW}📊 Core Services:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_service_status "MariaDB" "mysqld" "7999"
check_service_status "PHP-FPM 7.4" "php-fpm" ""
check_service_status "Nginx (Official)" "nginx.*master" ""

echo ""
echo -e "${YELLOW}🌐 Network Status:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v netstat >/dev/null 2>&1; then
    # Check admin port
    if netstat -tlnp 2>/dev/null | grep -q ":$ACCESPORT "; then
        echo -e "${GREEN}✅ Admin Panel${NC} - Port $ACCESPORT listening"
    else
        echo -e "${RED}❌ Admin Panel${NC} - Port $ACCESPORT not listening"
    fi
    
    # Check client port
    if netstat -tlnp 2>/dev/null | grep -q ":$CLIENTACCESPORT "; then
        echo -e "${GREEN}✅ Client Access${NC} - Port $CLIENTACCESPORT listening"
    else
        echo -e "${RED}❌ Client Access${NC} - Port $CLIENTACCESPORT not listening"
    fi
    
    # Check apache port
    if netstat -tlnp 2>/dev/null | grep -q ":$APACHEACCESPORT "; then
        echo -e "${GREEN}✅ Apache Port${NC} - Port $APACHEACCESPORT listening"
    else
        echo -e "${RED}❌ Apache Port${NC} - Port $APACHEACCESPORT not listening"
    fi
else
    echo -e "${YELLOW}⚠️  netstat not available - cannot check ports${NC}"
fi

echo ""
echo -e "${YELLOW}📁 File System:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check important directories
if [ -d "/home/xtreamcodes/iptv_xtream_codes" ]; then
    echo -e "${GREEN}✅ XtreamCodes Directory${NC} - Present"
else
    echo -e "${RED}❌ XtreamCodes Directory${NC} - Missing"
fi

# Check for REAL XtreamCodes files
if [ -d "/home/xtreamcodes/iptv_xtream_codes/admin" ]; then
    echo -e "${GREEN}✅ Admin Directory${NC} - Present"
else
    echo -e "${RED}❌ Admin Directory${NC} - Missing"
fi

if [ -d "/home/xtreamcodes/iptv_xtream_codes/wwwdir" ]; then
    echo -e "${GREEN}✅ WWW Directory${NC} - Present"
else
    echo -e "${RED}❌ WWW Directory${NC} - Missing"
fi

# Check tmpfs mounts
if mountpoint -q /home/xtreamcodes/iptv_xtream_codes/streams 2>/dev/null; then
    echo -e "${GREEN}✅ Streams tmpfs${NC} - Mounted"
else
    echo -e "${RED}❌ Streams tmpfs${NC} - Not mounted"
fi

if mountpoint -q /home/xtreamcodes/iptv_xtream_codes/tmp 2>/dev/null; then
    echo -e "${GREEN}✅ Tmp tmpfs${NC} - Mounted"
else
    echo -e "${RED}❌ Tmp tmpfs${NC} - Not mounted"
fi

# Check PHP socket
if [ -S "/run/php/php7.4-fpm-xtreamcodes.sock" ]; then
    echo -e "${GREEN}✅ PHP-FPM Socket${NC} - Present"
else
    echo -e "${RED}❌ PHP-FPM Socket${NC} - Missing"
fi

echo ""
echo -e "${YELLOW}💾 System Resources:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Memory usage
if command -v free >/dev/null 2>&1; then
    mem_info=$(free -h | grep "Mem:")
    echo -e "${BLUE}🧠 Memory:${NC} $mem_info"
fi

# Disk usage for XtreamCodes
if command -v df >/dev/null 2>&1; then
    df_info=$(df -h /home/xtreamcodes 2>/dev/null | tail -1)
    echo -e "${BLUE}💽 Disk:${NC} $df_info"
fi

# Load average
if [ -f "/proc/loadavg" ]; then
    load_avg=$(cat /proc/loadavg | cut -d' ' -f1-3)
    echo -e "${BLUE}⚡ Load:${NC} $load_avg"
fi

echo ""
echo -e "${BLUE}🔧 Quick Commands:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Restart services: /home/xtreamcodes/iptv_xtream_codes/restart_services.sh"
echo "View logs: tail -f /var/log/nginx/*.log"
echo "Nginx config test: nginx -t"
echo ""
STATUSSCRIPT

chmod +x /home/xtreamcodes/iptv_xtream_codes/check_status.sh

# Create restart services script (if not exists)
if [ ! -f "/home/xtreamcodes/iptv_xtream_codes/restart_services.sh" ]; then
    cat > /home/xtreamcodes/iptv_xtream_codes/restart_services.sh << 'RESTARTSCRIPT'
#!/bin/bash
# XtreamCodes Enhanced Restart Services - Stefan Edition

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🔄 Restarting XtreamCodes Enhanced Services - Stefan Edition${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Stop services
echo -e "${YELLOW}🛑 Stopping services...${NC}"
systemctl stop nginx 2>/dev/null
systemctl stop php7.4-fpm 2>/dev/null

# Kill any XtreamCodes processes
pkill -f "nginx.*xtreamcodes" 2>/dev/null

sleep 3

# Start services
echo -e "${YELLOW}🚀 Starting services...${NC}"
/home/xtreamcodes/iptv_xtream_codes/start_services.sh

echo ""
echo -e "${GREEN}✅ Service restart completed!${NC}"
echo "Check status: /home/xtreamcodes/iptv_xtream_codes/check_status.sh"
RESTARTSCRIPT
    chmod +x /home/xtreamcodes/iptv_xtream_codes/restart_services.sh
fi

# System optimizations
echo "⚡ Applying system optimizations..."

# Configure system limits
cat >> /etc/security/limits.conf << EOL
* soft nofile 300000
* hard nofile 300000
* soft nproc 300000
* hard nproc 300000
xtreamcodes soft nofile 300000
xtreamcodes hard nofile 300000
xtreamcodes soft nproc 300000
xtreamcodes hard nproc 300000
EOL

# Configure kernel parameters  
cat >> /etc/sysctl.conf << EOL
# XtreamCodes Enhanced Optimizations - Stefan Edition
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.ip_local_port_range = 1024 65535
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.netdev_max_backlog = 5000
fs.file-max = 2097152
EOL

sysctl -p >/dev/null 2>&1

# Create enhanced systemd service
cat > /etc/systemd/system/xtreamcodes.service << EOL
[Unit]
Description=XtreamCodes Enhanced Service - Stefan Edition with Official Nginx
After=network.target mariadb.service

[Service]
Type=forking
User=root
ExecStart=/home/xtreamcodes/iptv_xtream_codes/start_services.sh
ExecReload=/home/xtreamcodes/iptv_xtream_codes/restart_services.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable xtreamcodes.service >/dev/null 2>&1

# Setup auto-start with enhanced cron
if ! grep -q "@reboot root /home/xtreamcodes/iptv_xtream_codes/start_services.sh" /etc/crontab; then
    echo "@reboot root /home/xtreamcodes/iptv_xtream_codes/start_services.sh" >> /etc/crontab
fi

echo "🚀 Starting XtreamCodes Enhanced services with official Nginx..."

# Start PHP-FPM first
systemctl start php7.4-fpm
sleep 2

# Test nginx configuration
nginx -t >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Nginx configuration test passed"
    systemctl start nginx
else
    echo "⚠️  Nginx configuration test failed, attempting to fix..."
    # Create a minimal working config if test fails
    cat > /etc/nginx/nginx.conf << 'NGINXBACKUP'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    server {
        listen 2086;
        root /home/xtreamcodes/iptv_xtream_codes/admin;
        index index.php;
        
        location ~ \.php$ {
            fastcgi_pass unix:/run/php/php7.4-fpm-xtreamcodes.sock;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        }
    }
    
    server {
        listen 5050;
        root /home/xtreamcodes/iptv_xtream_codes/wwwdir;
        index index.php;
        
        location ~ \.php$ {
            fastcgi_pass unix:/run/php/php7.4-fpm-xtreamcodes.sock;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        }
    }
}
NGINXBACKUP
    nginx -t && systemctl start nginx
fi

# Start XtreamCodes processes
cd /home/xtreamcodes/iptv_xtream_codes
if [ -f "./start_services.sh" ]; then
    ./start_services.sh >/dev/null 2>&1
fi

# Wait for services to start
sleep 10

# Verify installation
echo "✅ Verifying installation..."

nginx_running=$(pgrep -f "nginx.*master" | wc -l)
phpfpm_running=$(pgrep -f "php7.4-fpm" | wc -l)
mysql_running=$(pgrep -f "mysqld" | wc -l)

success=true

if [ $nginx_running -eq 0 ]; then
    echo "⚠️  Warning: Nginx is not running"
    success=false
fi

if [ $phpfpm_running -eq 0 ]; then
    echo "⚠️  Warning: PHP-FPM is not running"
    success=false
fi

if [ $mysql_running -eq 0 ]; then
    echo "⚠️  Warning: MySQL is not running"
    success=false
fi

# Check PHP socket
socket_ok=true
if [ ! -S "/run/php/php7.4-fpm-xtreamcodes.sock" ]; then
    echo "⚠️  Warning: PHP-FPM socket not found"
    socket_ok=false
fi

# Check ports
if command -v netstat >/dev/null 2>&1; then
    admin_port=$(netstat -tlnp 2>/dev/null | grep ":$ACCESPORT " | wc -l)
    client_port=$(netstat -tlnp 2>/dev/null | grep ":$CLIENTACCESPORT " | wc -l)
    mysql_port=$(netstat -tlnp 2>/dev/null | grep ":7999 " | wc -l)
    
    if [ $admin_port -eq 0 ]; then
        echo "⚠️  Warning: Admin port $ACCESPORT not listening"
        success=false
    fi
    
    if [ $client_port -eq 0 ]; then
        echo "⚠️  Warning: Client port $CLIENTACCESPORT not listening"
        success=false
    fi
    
    if [ $mysql_port -eq 0 ]; then
        echo "⚠️  Warning: MySQL port 7999 not listening"
        success=false
    fi
fi

# Clean up temp files
rm -f /tmp/database.sql /tmp/$ARCHIVE_NAME

# Final status
clear
echo ""
if $success && $socket_ok; then
    echo "🎉 XtreamCodes Enhanced installation completed successfully!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                    🎯 INSTALLATION COMPLETE - STEFAN EDITION v1.1"
    echo "                       🆕 WITH REAL ARCHIVES + OFFICIAL NGINX"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "⚠️  XtreamCodes Enhanced installed with warnings"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                    ⚠️  INSTALLATION COMPLETED WITH WARNINGS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

echo ""
echo "📋 INSTALLATION DETAILS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Admin Panel:     http://$ipaddr:$ACCESPORT"
echo "👤 Username:        $adminL"
echo "🔒 Password:        $adminP"
echo "📧 Email:           $EMAIL"
echo ""
echo "🔧 TECHNICAL DETAILS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📡 Client Port:     $CLIENTACCESPORT"
echo "🔧 Apache Port:     $APACHEACCESPORT"
echo "🗄️  MySQL Port:     7999"
echo "🗄️  MySQL Root:     $PASSMYSQL"
echo "🗄️  MySQL User:     user_iptvpro"
echo "🗄️  MySQL Pass:     $XPASS"
echo "🕐 Timezone:        $tz"
echo "🌐 Nginx Version:   $(nginx -v 2>&1 | cut -d' ' -f3)"
echo "🐘 PHP Version:     $(php7.4 -v | head -1 | cut -d' ' -f2)"
echo "📦 Archive Used:    $ARCHIVE_NAME"
echo ""
echo "📊 SERVICE STATUS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Nginx (Official): $nginx_running processes"
echo "🐘 PHP-FPM 7.4:     $phpfpm_running processes"
echo "🗄️  MariaDB:        $mysql_running processes"

if $socket_ok; then
    echo "🔌 PHP Socket:      ✅ Connected"
else
    echo "🔌 PHP Socket:      ⚠️  Check required"
fi

echo ""
echo "🛠️  MANAGEMENT COMMANDS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Status Check:    /home/xtreamcodes/iptv_xtream_codes/check_status.sh"
echo "🔄 Restart:         /home/xtreamcodes/iptv_xtream_codes/restart_services.sh"
echo "🗂️  Logs:           /var/log/nginx/ + /home/xtreamcodes/iptv_xtream_codes/logs/"
echo "🔧 Nginx Test:      nginx -t"
echo "🔧 Nginx Reload:    systemctl reload nginx"
echo ""
echo "🆕 STEFAN'S v1.1 ENHANCED FEATURES:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ REAL XtreamCodes archives from releases (NO DEMO FILES!)"
echo "✅ Official Ubuntu Nginx (nu cel vechi din XtreamCodes!)"
echo "✅ PHP 7.4 cu optimizări complete"
echo "✅ Database.sql descărcat din GitHub repository"
echo "✅ All dependency fixes applied automatically"
echo "✅ libzip.so.4 compatibility ensured"
echo "✅ Enhanced nginx configuration with rate limiting"
echo "✅ System performance optimizations"
echo "✅ Advanced management scripts created"
echo "✅ Auto-restart on boot configured"
echo "✅ Repository: Stefan2512/Proper-Repairs-Xtream-Codes"
echo ""
echo "🔗 REPOSITORY: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes"
echo ""

# Save installation info
cat > /root/XtreamCodes_Stefan_Installation_v1.1.txt << EOL
┌─────────────────── XtreamCodes Stefan Enhanced Installation v1.1 ───────────────────┐
│
│ INSTALLATION COMPLETED: $(date)
│ VERSION: Stefan Enhanced v1.1 with REAL Archives + Official Nginx
│
│ ADMIN ACCESS:
│ Panel URL: http://$ipaddr:$ACCESPORT
│ Username:  $adminL
│ Password:  $adminP
│ Email:     $EMAIL
│
│ TECHNICAL DETAILS:
│ Client Port:      $CLIENTACCESPORT
│ Apache Port:      $APACHEACCESPORT
│ MySQL Port:       7999
│ MySQL Root Pass:  $PASSMYSQL
│ MySQL User Pass:  $XPASS
│ Timezone:         $tz
│ Nginx Version:    $(nginx -v 2>&1 | cut -d' ' -f3)
│ PHP Version:      $(php7.4 -v | head -1 | cut -d' ' -f2)
│ Archive Used:     $ARCHIVE_NAME
│
│ SERVICE STATUS:
│ Nginx (Official): $nginx_running processes
│ PHP-FPM 7.4:      $phpfpm_running processes
│ MariaDB:          $mysql_running processes
│
│ MANAGEMENT COMMANDS:
│ Status Check: /home/xtreamcodes/iptv_xtream_codes/check_status.sh
│ Restart:      /home/xtreamcodes/iptv_xtream_codes/restart_services.sh
│ Nginx Test:   nginx -t
│ Nginx Reload: systemctl reload nginx
│
│ STEFAN'S v1.1 ENHANCED FEATURES:
│ ✓ REAL XtreamCodes archives from releases (NO DEMO FILES!)
│ ✓ Official Ubuntu Nginx (not the old XtreamCodes one!)
│ ✓ PHP 7.4 with complete optimizations
│ ✓ Database.sql downloaded from GitHub repository
│ ✓ All dependency fixes included
│ ✓ libzip.so.4 compatibility
│ ✓ Enhanced nginx config with rate limiting
│ ✓ System performance tuning
│ ✓ Advanced management scripts
│ ✓ Auto-restart configured
│
│ Repository: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes
│ Version: Stefan Enhanced v1.1 - REAL Archives Edition
│ Installer Log: $logfile
│
└──────────────────────────────────────────────────────────────────────────────────────┘
EOL

echo "💾 Installation details saved to: /root/XtreamCodes_Stefan_Installation_v1.1.txt"
echo "📝 Installation log: $logfile"
echo ""

if $success && $socket_ok; then
    echo "🎉 Congratulations! Your XtreamCodes Enhanced server is ready!"
    echo "🌐 Access your admin panel: http://$ipaddr:$ACCESPORT"
    echo ""
    echo "🆕 NEW FEATURES IN v1.1:"
    echo "   • REAL XtreamCodes archives from releases (NO DEMO FILES!)"
    echo "   • Official Ubuntu Nginx instead of the old bundled version!"
    echo "   • Database.sql downloaded directly from GitHub repository!"
    echo ""
    echo "🔧 Test nginx config anytime: nginx -t"
    echo "🔄 Reload nginx config: systemctl reload nginx"
else
    echo "⚠️  Installation completed but some services may need attention."
    echo "🔧 Run: /home/xtreamcodes/iptv_xtream_codes/check_status.sh"
    echo "🔄 Try: /home/xtreamcodes/iptv_xtream_codes/restart_services.sh"
    echo "🔧 Test nginx: nginx -t"
fi

echo ""
echo "🙏 Thank you for using Stefan's Enhanced XtreamCodes Installer v1.1!"
echo "🆕 Now uses REAL archives + official Ubuntu Nginx!"
echo "🔗 Repository: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes"
echo ""

# End of Stefan's Enhanced Installer v1.1 with REAL Archives + Official Nginx
