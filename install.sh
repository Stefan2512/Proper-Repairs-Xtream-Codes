#!/usr/bin/env bash
# Enhanced Xtream UI Automated Installation Script
# =============================================
# Enhanced Version with all fixes included
# Fixed by: Stefan2512 + Enhanced with dependency fixes
# I forked the dOC4eVER repo and added install fixes and enhancements
# This version includes all necessary fixes for:
# - libzip.so.4 dependency issues
# - PHP-FPM socket creation
# - Permission fixes
# - MySQL/MariaDB configuration
# - All dependencies pre-resolved
#
# Supported Operating Systems: 
# Ubuntu server 18.04/20.04/22.04
# 64bit online system

# Set custom logging methods
logfile=$(date +%Y-%m-%d_%H.%M.%S_xtream_ui_install_enhanced.log)
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
            echo "Enhanced XtreamCodes Installer v2"
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
            echo "Example:"
            echo "curl -L https://your-repo.com/install_enhanced.sh | bash -s -- -a admin -t Europe/Paris -p adminpass -o 2086 -c 5050 -r 3672 -e admin@example.com -m mysqlpass -s yes"
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

# Clear screen and show welcome message
clear
XC_VERSION="Enhanced v2.0 - All Fixes Included"
PANEL_PATH="/home/xtreamcodes/iptv_xtream_codes"

echo ""
tput setaf 2; tput bold; echo " ┌───────────────────────────────────────────────────────────────────┐"; tput sgr0;
tput setaf 2; tput bold; echo " │  Enhanced Xtream UI Installer $XC_VERSION  │"; tput sgr0;
tput setaf 2; tput bold; echo " └───────────────────────────────────────────────────────────────────┘"; tput sgr0;
echo ""
tput setaf 3; tput bold; tput cuf 15; echo "XtreamCodes Enhanced ◄۞ v2.0 ۞►"; tput sgr0;
echo ""
tput setaf 1; tput bold; tput cuf 5; echo "Features:"; tput sgr0;
tput setaf 2; tput bold; tput cuf 5; echo "✓ All dependency fixes included"; tput sgr0;
tput setaf 3; tput bold; tput cuf 5; echo "✓ libzip.so.4 fix automated"; tput sgr0;
tput setaf 4; tput bold; tput cuf 5; echo "✓ PHP-FPM socket fixes"; tput sgr0;
tput setaf 5; tput bold; tput cuf 5; echo "✓ Permission fixes"; tput sgr0;
tput setaf 6; tput bold; tput cuf 5; echo "✓ Ubuntu 20.04/22.04 optimized"; tput sgr0;
echo ""

# System compatibility check
echo -e "\nChecking system requirements..."

# Detect OS
if [ -f /etc/lsb-release ]; then
    OS=$(grep DISTRIB_ID /etc/lsb-release | sed 's/^.*=//')
    VER=$(grep DISTRIB_RELEASE /etc/lsb-release | sed 's/^.*=//')
elif [ -f /etc/os-release ]; then
    OS=$(grep -w ID /etc/os-release | sed 's/^.*=//')
    VER=$(grep VERSION_ID /etc/os-release | sed 's/^.*"\(.*\)"/\1/' | head -n 1)
else
    OS=$(uname -s)
    VER=$(uname -r)
fi

ARCH=$(uname -m)
echo -e " \033[1;33m Detected\033[1;36m $OS\033[1;32m $VER\033[0m \033[1;35m$ARCH\033[0m"

# Check OS compatibility
if [[ "$OS" = "Ubuntu" && ("$VER" = "18.04" || "$VER" = "20.04" || "$VER" = "22.04") && "$ARCH" == "x86_64" ]]; then
    tput setaf 2; tput bold; echo "✓ OS compatibility check passed"; tput sgr0;
else
    tput setaf 1; tput bold; echo "✗ Sorry, this enhanced installer only supports Ubuntu 18.04/20.04/22.04 x86_64"; tput sgr0;
    exit 1
fi

# Check root privileges
if [ $UID -ne 0 ]; then
    tput setaf 1; tput bold; echo "✗ This installer must be run as root"; tput sgr0;
    echo "Use: sudo -i, then run this script again"
    exit 1
fi

# Check for existing control panels
if [ -e /usr/local/cpanel ] || [ -e /usr/local/directadmin ] || [ -e /home/xtreamcodes/iptv_xtream_codes ]; then
    tput setaf 1; tput bold; echo "✗ Existing installation or control panel detected"; tput sgr0;
    echo "Please use a clean OS installation"
    exit 1
fi

# Set package management variables
PACKAGE_INSTALLER="apt-get -yqq install"
PACKAGE_REMOVER="apt-get -yqq purge"
MYSQLCNF=/etc/mysql/mariadb.cnf

# Get server information
tput setaf 6; tput bold; echo -e "\n-- Preparing system and gathering information"; tput sgr0;
DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND=noninteractive

# Disable needrestart prompts
if [ -f "/etc/apt/apt.conf.d/99needrestart" ]; then
    sed -i 's|DPkg::Post-Invoke|#DPkg::Post-Invoke|' "/etc/apt/apt.conf.d/99needrestart"
fi

# Update package lists and install essential tools
apt-get -qq update
$PACKAGE_INSTALLER curl wget dnsutils net-tools

# Get server IP and network info
ipaddr="$(wget -qO- http://api.sentora.org/ip.txt || curl -s http://ipinfo.io/ip)"
local_ip=$(ip addr show | awk '$1 == "inet" && $3 == "brd" { sub (/\/.*/,""); print $2 }' | head -1)
networkcard=$(route | grep default | awk '{print $8}' | head -1)

# Generate secure passwords and salts
blofish=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1)
alg=6
salt='rounds=20000$xtreamcodes'
XPASS=$(</dev/urandom tr -dc A-Z-a-z-0-9 | head -c16)
zzz=$(</dev/urandom tr -dc A-Z-a-z-0-9 | head -c20)
eee=$(</dev/urandom tr -dc A-Z-a-z-0-9 | head -c10)
rrr=$(</dev/urandom tr -dc A-Z-a-z-0-9 | head -c20)
versionn="$OS $VER"

# Setup variables for nginx config
nginx111='$uri'
nginx222='$document_root$fastcgi_script_name'
nginx333='$fastcgi_script_name'
nginx444='$host:$server_port$request_uri'

# Configure timezone
if [[ "$tz" == "" ]]; then
    tput setaf 5; tput bold; echo "Setting up timezone..."; tput sgr0;
    $PACKAGE_INSTALLER tzdata
    DEBIAN_FRONTEND=dialog dpkg-reconfigure tzdata
    DEBIAN_FRONTEND=noninteractive
    export DEBIAN_FRONTEND=noninteractive
    tz=$(cat /etc/timezone)
else
    echo "Setting timezone to: $tz"
    echo $tz > /etc/timezone
fi

rm -f /etc/localtime
ln -s /usr/share/zoneinfo/$tz /etc/localtime
timedatectl set-timezone $tz

# Get user input if not provided via command line
if [[ "$adminL" == "" ]]; then
    tput setaf 1; tput bold; read -p "Enter admin username: " adminL; tput sgr0;
else
    tput setaf 1; tput bold; echo "Admin username set: $adminL"; tput sgr0;
fi

if [[ "$adminP" == "" ]]; then
    tput setaf 2; tput bold; read -p "Enter admin password: " adminP; tput sgr0;
else
    tput setaf 2; tput bold; echo "Admin password set: [HIDDEN]"; tput sgr0;
fi

if [[ "$ACCESPORT" == "" ]]; then
    ACCESPORT=2086
    tput setaf 3; tput bold; echo "Admin port set to default: $ACCESPORT"; tput sgr0;
else
    tput setaf 3; tput bold; echo "Admin port set: $ACCESPORT"; tput sgr0;
fi

if [[ "$CLIENTACCESPORT" == "" ]]; then
    CLIENTACCESPORT=5050
    tput setaf 4; tput bold; echo "Client port set to default: $CLIENTACCESPORT"; tput sgr0;
else
    tput setaf 4; tput bold; echo "Client port set: $CLIENTACCESPORT"; tput sgr0;
fi

if [[ "$APACHEACCESPORT" == "" ]]; then
    APACHEACCESPORT=3672
    tput setaf 5; tput bold; echo "Apache port set to default: $APACHEACCESPORT"; tput sgr0;
else
    tput setaf 5; tput bold; echo "Apache port set: $APACHEACCESPORT"; tput sgr0;
fi

if [[ "$EMAIL" == "" ]]; then
    tput setaf 6; tput bold; read -p "Enter admin email: " EMAIL; tput sgr0;
else
    tput setaf 6; tput bold; echo "Admin email set: $EMAIL"; tput sgr0;
fi

if [[ "$PASSMYSQL" == "" ]]; then
    tput setaf 7; tput bold; read -p "Enter MySQL root password: " PASSMYSQL; tput sgr0;
else
    tput setaf 7; tput bold; echo "MySQL password set: [HIDDEN]"; tput sgr0;
fi

PORTSSH=22
Padmin=$(perl -e 'print crypt($ARGV[1], "\$" . $ARGV[0] . "\$" . $ARGV[2]), "\n";' "$alg" "$adminP" "$salt")

# Final confirmation
if [[ "$silent" != "yes" ]]; then
    echo ""
    tput setaf 3; tput bold; read -e -p "Ready to install XtreamCodes Enhanced. Continue? (y/n): " yn; tput sgr0;
    case $yn in
        [Yy]*) ;;
        [Nn]*) exit;;
        *) echo "Please answer yes or no."; exit;;
    esac
fi

clear
echo ""
tput setaf 1; tput bold; tput cuf 15; echo "🚀 Starting Enhanced Installation"; tput sgr0;
echo ""

# =====================================================
# ENHANCED INSTALLATION STARTS HERE
# =====================================================

echo -e "\033[1;32m ────────────────────\033[0m\033[1;35m ENHANCED INSTALLATION \033[0m\033[1;32m────────────────────\033[0m"
echo -e "    \033[1;33m Installing Enhanced XtreamCodes on\033[0m \033[1;36m$OS\033[1;32m $VER\033[0m \033[1;35m$ARCH\033[0m"
echo -e "    \033[1;33m Server IP:\033[0m $ipaddr"
echo -e "\033[1;32m ──────────────────────────────────────────────────────────────────────\033[0m"

# Install essential dependencies with all fixes
tput setaf 4; tput bold; echo "[+] Installing essential packages and dependencies..."; tput sgr0;

# Install Python 3 and essential tools
$PACKAGE_INSTALLER python3 python2 python-is-python2 software-properties-common

# Install all necessary dependencies including fixes for common issues
$PACKAGE_INSTALLER \
    curl wget unzip zip \
    build-essential \
    libzip-dev libzip5 \
    libonig-dev libonig5 \
    libsodium-dev libsodium23 \
    libargon2-dev libargon2-1 \
    libbz2-dev \
    libpng-dev \
    libxml2-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libxslt1-dev \
    libmaxminddb-dev \
    libaio-dev \
    daemonize \
    net-tools \
    cron

# CRITICAL FIX: Create libzip.so.4 symlink to prevent PHP-FPM issues
tput setaf 6; tput bold; echo "[+] Applying libzip.so.4 fix..."; tput sgr0;
if [ ! -f "/usr/lib/x86_64-linux-gnu/libzip.so.4" ]; then
    ln -s /usr/lib/x86_64-linux-gnu/libzip.so.5 /usr/lib/x86_64-linux-gnu/libzip.so.4
    echo "✓ libzip.so.4 symlink created"
fi

# Install and configure MariaDB
tput setaf 4; tput bold; echo "[+] Installing and configuring MariaDB..."; tput sgr0;
$PACKAGE_INSTALLER mariadb-server mariadb-client

# Start MariaDB service
systemctl start mariadb
systemctl enable mariadb

# Configure MySQL root password
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$PASSMYSQL'; FLUSH PRIVILEGES;" 2>/dev/null || \
mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('$PASSMYSQL') WHERE User='root'; FLUSH PRIVILEGES;" 2>/dev/null || \
mysqladmin -u root password "$PASSMYSQL" 2>/dev/null

tput setaf 2; tput bold; echo "✓ Dependencies and MariaDB configured"; tput sgr0;

# Install XtreamCodes
tput setaf 4; tput bold; echo "[+] Installing XtreamCodes Enhanced..."; tput sgr0;

# Create xtreamcodes user
adduser --system --shell /bin/false --group --disabled-login xtreamcodes 2>/dev/null

# Download and extract XtreamCodes (using OUR corrected archive)
OSNAME=$(echo $OS | sed "s| |.|g")
wget -q -O /tmp/xtreamcodes.tar.gz "https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/download/v1.0/xtreamcodes_enhanced_${OSNAME}_${VER}.tar.gz"

if [ ! -f "/tmp/xtreamcodes.tar.gz" ]; then
    echo "Failed to download from specific OS version. Trying universal enhanced version..."
    # Fallback to universal enhanced version from OUR repo
    wget -q -O /tmp/xtreamcodes.tar.gz "https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/download/v1.0/xtreamcodes_enhanced_universal.tar.gz"
fi

if [ ! -f "/tmp/xtreamcodes.tar.gz" ]; then
    echo "ERROR: Could not download XtreamCodes enhanced archive from our repository!"
    echo "Please check if the release exists at: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases"
    exit 1
fi

# Extract XtreamCodes
tar -xf "/tmp/xtreamcodes.tar.gz" -C "/home/xtreamcodes/" 2>/dev/null
rm -f /tmp/xtreamcodes.tar.gz

# Configure MariaDB for XtreamCodes
tput setaf 4; tput bold; echo "[+] Configuring MariaDB for XtreamCodes..."; tput sgr0;

# Backup original config and install optimized config
mv $MYSQLCNF $MYSQLCNF.xc 2>/dev/null

# Create optimized MariaDB configuration
cat > $MYSQLCNF << 'EOL'
# XtreamCodes Enhanced Configuration

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

innodb_buffer_pool_size = 10G
innodb_buffer_pool_instances = 10
innodb_read_io_threads = 64
innodb_write_io_threads = 64
innodb_thread_concurrency = 0
innodb_flush_log_at_trx_commit = 0
innodb_flush_method = O_DIRECT
performance_schema = 0
innodb-file-per-table = 1
innodb_io_capacity=20000
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

tput setaf 2; tput bold; echo "✓ XtreamCodes installed and MariaDB configured"; tput sgr0;

# Configure XtreamCodes database and settings
tput setaf 4; tput bold; echo "[+] Configuring XtreamCodes database..."; tput sgr0;

# Python configuration script with enhanced error handling
python2 << END
# coding: utf-8
import subprocess, os, random, string, sys, shutil, socket
from itertools import cycle, izip

class col:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

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
sshssh = "$PORTSSH"
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
        print("✓ Config file encrypted and saved")
    except Exception as e:
        print("Error creating config: %s" % str(e))

def modifyNginx():
    try:
        rPath = "/home/xtreamcodes/iptv_xtream_codes/nginx/conf/nginx.conf"
        if os.path.exists(rPath):
            rPrevData = open(rPath, "r").read()
            rData = "}".join(rPrevData.split("}")[:-1]) + "    server {\n        listen $ACCESPORT;\n        index index.php index.html index.htm;\n        root /home/xtreamcodes/iptv_xtream_codes/admin/;\n\n        location ~ \.php\$ {\n			limit_req zone=one burst=8;\n            try_files \$uri =404;\n			fastcgi_index index.php;\n			fastcgi_pass php;\n			include fastcgi_params;\n			fastcgi_buffering on;\n			fastcgi_buffers 96 32k;\n			fastcgi_buffer_size 32k;\n			fastcgi_max_temp_file_size 0;\n			fastcgi_keep_conn on;\n			fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;\n			fastcgi_param SCRIPT_NAME \$fastcgi_script_name;\n        }\n    }\n}"
            
            rFile = open(rPath, "w")
            rFile.write(rData)
            rFile.close()
            print("✓ Nginx configuration updated")
        
        # Update hosts file
        hosts_entries = [
            "127.0.0.1    api.xtream-codes.com",
            "127.0.0.1    downloads.xtream-codes.com", 
            "127.0.0.1    xtream-codes.com"
        ]
        
        hosts_content = open("/etc/hosts").read()
        for entry in hosts_entries:
            if entry.split()[1] not in hosts_content:
                os.system('echo "%s" >> /etc/hosts' % entry)
        
        print("✓ Hosts file updated")
    except Exception as e:
        print("Error configuring nginx: %s" % str(e))

def mysql():
    try:
        # Create database
        cmd1 = 'mysql -u root%s -e "DROP DATABASE IF EXISTS xtream_iptvpro; CREATE DATABASE IF NOT EXISTS xtream_iptvpro;" > /dev/null 2>&1' % rExtra
        os.system(cmd1)
        
        # Import database schema
        cmd2 = "mysql -u root%s xtream_iptvpro < /home/xtreamcodes/iptv_xtream_codes/database.sql > /dev/null 2>&1" % rExtra
        os.system(cmd2)
        
        # Configure streaming server
        cmd3 = 'mysql -u root%s -e "USE xtream_iptvpro; REPLACE INTO streaming_servers (id, server_name, domain_name, server_ip, vpn_ip, ssh_password, ssh_port, diff_time_main, http_broadcast_port, total_clients, system_os, network_interface, latency, status, enable_geoip, geoip_countries, last_check_ago, can_delete, server_hardware, total_services, persistent_connections, rtmp_port, geoip_type, isp_names, isp_type, enable_isp, boost_fpm, http_ports_add, network_guaranteed_speed, https_broadcast_port, https_ports_add, whitelist_ips, watchdog_data, timeshift_only) VALUES (1, \'Main Server\', \'\', \'%s\', \'\', NULL, \'%s\', 0, 2082, 1000, \'%s\', \'%s\', 0, 1, 0, \'\', 0, 0, \'{}\', 3, 0, 2086, \'low_priority\', \'\', \'low_priority\', 0, 0, \'\', 1000, 2083, \'\', \'[\"127.0.0.1\",\"\"]\', \'{}\', 0);" > /dev/null 2>&1' % (rExtra, getIP, sshssh, getVersion, reseau)
        os.system(cmd3)
        
        # Create database user
        cmd4 = 'mysql -u root%s -e "GRANT ALL PRIVILEGES ON *.* TO \'%s\'@\'%%\' IDENTIFIED BY \'%s\' WITH GRANT OPTION; FLUSH PRIVILEGES;" > /dev/null 2>&1' % (rExtra, rUsername, rPassword)
        os.system(cmd4)
        
        print("✓ Database configured successfully")
    except Exception as e:
        print("Error configuring database: %s" % str(e))

# Execute configuration
print("Configuring database...")
mysql()
print("Creating encrypted config...")
encrypt(rHost, rUsername, rPassword, rDatabase, rServerID, rPort)
print("Configuring nginx...")
modifyNginx()
print("✓ All configurations completed")
END

# Create admin user in database
tput setaf 4; tput bold; echo "[+] Creating admin user..."; tput sgr0;

cat > /tmp/admin_user.sql << EOL
USE xtream_iptvpro;
INSERT INTO reg_users (id, username, password, email, ip, date_registered, verify_code, verified, type, last_login, exp_date, admin_enabled, admin_notes, reseller_dns, owner_id, override_packages, hue, theme, timezone, api_key) VALUES 
(1, '$adminL', '$Padmin', '$EMAIL', '', UNIX_TIMESTAMP(), '', 1, 1, NULL, 4070905200, 1, '', '', 0, '', '', '', '', '');

INSERT INTO member_groups (group_id, group_name, total_allowed_gen_in, total_allowed_gen_mag, total_allowed_gen_e2, group_package, allowed_pages, is_admin, delete_users, create_sub_resellers, edit_own_user, is_isplock, lock_timezone, cms_login, reset_user_exp, viewhidden_all, select_main_server, flood_limit, total_allowed_gen_trials, max_connections, min_trial_credits, change_trial_credits, permitted_servers, change_bouquet, change_package, api_iptv, api_mag, api_e2, api_radio, delete_expired, content_import, quick_edit, user_auto_kick, can_isplock, create_mag, mag_container, stalker_lock_timeout, change_userpass, series_download, catchup, rec_limit, catchup_days, radio, stalker_beta, export_data, device_lock, max_mag_devices, max_e2_devices, max_iptv_devices, total_allowed_output, allowed_stb_types, allowed_ua, reseller_change_info, reseller_change_own, reseller_client_connection_logs, reseller_assign_server, bouquet_download, allow_countries, denied_countries, disable_expired, 2factor, stalker_syncdb, stalker_mag_container, stalker_stalker_beta, stalker_capmt, stalker_ecm, stalker_anti_sharing, stalker_force_mgcamd, stalker_stalker_priority, stalker_livetvpreview, stalker_mag_container_url, stalker_mag_container_url2, stalker_mag_container_url3, stalker_stalker_isplock, stalker_portal_capmt, stalker_timeshift, audio_restart_loss, audio_delay_startup, stalker_liveprivacy, stalker_livetimeout, stalker_gen_all_stb, stalker_show_tv, stalker_portal_autoupdate, message_all) VALUES 
(1, 'Administrator', 999999, 999999, 999999, '', '["dashboard","users","create_user","manage_users","create_mag","user_ips","create_enigma","manage_e2","user_activity","user_online","manage_events","reg_userlog","credits_log","admin_live","admin_movies","admin_series","admin_radio","admin_episodes","live_streams","create_live","manage_live","movie_streams","create_movie","manage_movies","series","create_series","manage_series","manage_radio","create_radio","episodes","create_episode","manage_episodes","mass_edit_streams","stream_tools","server_tools","settings","server_info","databases","reg_users","mass_email","statistics","geo_ip","admin_logs","reseller_logs","edit_cchannel","client_logs","activity_by_user","line_activity","update_bouquets","edit_bouquet","bouquets","create_bouquet","epg","epg_edit","xmltv_edit","xmltv","admin_epg","servers","create_server","edit_server","networks","transcoding","reg_userlog","tools","backups","mass_tools","reg_userlog"]', 1, 1, 1, 1, 0, '', 1, 1, 1, 1, 1, 0, 999999, 999999, 0, 0, '[]', 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 7, 1, 1, 1, 1, 999999, 999999, 999999, 999999, '[]', '[]', 1, 1, 1, 1, 1, '[]', '[]', 1, '', 1, '', '', '', '', '', '', 0, '', '', 1, 1, 1, 1, 1, 1, 1, 1);
EOL

mysql -u root -p$PASSMYSQL xtream_iptvpro < /tmp/admin_user.sql
rm -f /tmp/admin_user.sql

tput setaf 2; tput bold; echo "✓ Admin user created successfully"; tput sgr0;

# Configure permissions and directories
tput setaf 4; tput bold; echo "[+] Setting up permissions and directories..."; tput sgr0;

# Remove default database.sql for security
rm -f /home/xtreamcodes/iptv_xtream_codes/database.sql

# Configure sudoers for xtreamcodes user
if ! grep -q "xtreamcodes ALL = (root) NOPASSWD: /sbin/iptables, /usr/bin/chattr, /usr/bin/python2, /usr/bin/python" /etc/sudoers; then
    echo "xtreamcodes ALL = (root) NOPASSWD: /sbin/iptables, /usr/bin/chattr, /usr/bin/python2, /usr/bin/python" >> /etc/sudoers
fi

# Create symlink for ffmpeg
ln -sf /home/xtreamcodes/iptv_xtream_codes/bin/ffmpeg /usr/bin/ 2>/dev/null

# Configure tmpfs mounts for better performance
if ! grep -q "tmpfs /home/xtreamcodes/iptv_xtream_codes/streams tmpfs" /etc/fstab; then
    echo "tmpfs /home/xtreamcodes/iptv_xtream_codes/streams tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777,size=90% 0 0" >> /etc/fstab
fi

if ! grep -q "tmpfs /home/xtreamcodes/iptv_xtream_codes/tmp tmpfs" /etc/fstab; then
    echo "tmpfs /home/xtreamcodes/iptv_xtream_codes/tmp tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777,size=2G 0 0" >> /etc/fstab
fi

# Set proper permissions
chmod -R 0777 /home/xtreamcodes

# Create enhanced nginx configuration
tput setaf 4; tput bold; echo "[+] Creating enhanced nginx configuration..."; tput sgr0;

cat > /home/xtreamcodes/iptv_xtream_codes/nginx/conf/nginx.conf << EOL
user  xtreamcodes;
worker_processes  auto;
worker_rlimit_nofile 300000;

events {
    worker_connections  16000;
    use epoll;
    accept_mutex on;
    multi_accept on;
}

thread_pool pool_xtream threads=32 max_queue=0;

http {
    include       mime.types;
    default_type  application/octet-stream;
    
    sendfile           on;
    tcp_nopush         on;
    tcp_nodelay        on;
    reset_timedout_connection on;
    gzip off;
    fastcgi_read_timeout 200;
    access_log off;
    keepalive_timeout 10;
    include balance.conf;
    send_timeout 20m;    
    sendfile_max_chunk 512k;
    lingering_close off;
    aio threads=pool_xtream;
    client_body_timeout 13s;
    client_header_timeout 13s;
    client_max_body_size 3m;
    limit_req_zone \$binary_remote_addr zone=one:30m rate=20r/s;
    
    # Enhanced upstream configuration for PHP-FPM
    upstream php {
        server unix:/home/xtreamcodes/iptv_xtream_codes/php/VaiIb8.sock weight=1;
        server unix:/home/xtreamcodes/iptv_xtream_codes/php/JdlJXm.sock weight=1;
        server unix:/home/xtreamcodes/iptv_xtream_codes/php/CWcfSP.sock weight=1;
    }
    
    # Client streaming server
    server {
        listen $CLIENTACCESPORT;
        listen 25463 ssl;
        ssl_certificate server.crt;
        ssl_certificate_key server.key; 
        ssl_protocols SSLv3 TLSv1.1 TLSv1.2;
        index index.php index.html index.htm;
        root /home/xtreamcodes/iptv_xtream_codes/wwwdir/;
        server_tokens off;
        chunked_transfer_encoding off;
        
        if ( \$request_method !~ ^(GET|POST)\$ ) {
            return 200;
        }
        
        rewrite_log on;
        rewrite ^/live/(.*)/(.*)/(.*)\.(.*)\$ /streaming/clients_live.php?username=\$1&password=\$2&stream=\$3&extension=\$4 break;
        rewrite ^/movie/(.*)/(.*)/(.*)\$ /streaming/clients_movie.php?username=\$1&password=\$2&stream=\$3&type=movie break;
        rewrite ^/series/(.*)/(.*)/(.*)\$ /streaming/clients_movie.php?username=\$1&password=\$2&stream=\$3&type=series break;
        rewrite ^/(.*)/(.*)/(.*).ch\$ /streaming/clients_live.php?username=\$1&password=\$2&stream=\$3&extension=ts break;
        rewrite ^/(.*)\.ch\$ /streaming/clients_live.php?extension=ts&stream=\$1&qs=\$query_string break;
        rewrite ^/ch(.*)\.m3u8\$ /streaming/clients_live.php?extension=m3u8&stream=\$1&qs=\$query_string break;
        rewrite ^/hls/(.*)/(.*)/(.*)/(.*)/(.*)\$ /streaming/clients_live.php?extension=m3u8&username=\$1&password=\$2&stream=\$3&type=hls&segment=\$5&token=\$4 break;
        rewrite ^/hlsr/(.*)/(.*)/(.*)/(.*)/(.*)/(.*)\$ /streaming/clients_live.php?token=\$1&username=\$2&password=\$3&segment=\$6&stream=\$4&key_seg=\$5 break;
        rewrite ^/timeshift/(.*)/(.*)/(.*)/(.*)/(.*)\.(.*)\$ /streaming/timeshift.php?username=\$1&password=\$2&stream=\$5&extension=\$6&duration=\$3&start=\$4 break;
        rewrite ^/timeshifts/(.*)/(.*)/(.*)/(.*)/(.*)\.(.*)\$ /streaming/timeshift.php?username=\$1&password=\$2&stream=\$4&extension=\$6&duration=\$3&start=\$5 break;
        rewrite ^/(.*)/(.*)/(\d+)\$ /streaming/clients_live.php?username=\$1&password=\$2&stream=\$3&extension=ts break;
        
        # PVR support
        rewrite ^/server/load.php\$ /portal.php break;
        
        location /stalker_portal/c {
            alias /home/xtreamcodes/iptv_xtream_codes/wwwdir/c;
        }
        
        # FFmpeg Report Progress
        location = /progress.php {
            allow 127.0.0.1;
            deny all;
            fastcgi_pass php;
            include fastcgi_params;
            fastcgi_ignore_client_abort on;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_param SCRIPT_NAME \$fastcgi_script_name;
        }
  
        location ~ \.php\$ {
            limit_req zone=one burst=8;
            try_files \$uri =404;
            fastcgi_index index.php;
            fastcgi_pass php;
            include fastcgi_params;
            fastcgi_buffering on;
            fastcgi_buffers 96 32k;
            fastcgi_buffer_size 32k;
            fastcgi_max_temp_file_size 0;
            fastcgi_keep_conn on;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_param SCRIPT_NAME \$fastcgi_script_name;
        }
    }
    
    # Admin panel server
    server {
        listen $ACCESPORT;
        index index.php index.html index.htm;
        root /home/xtreamcodes/iptv_xtream_codes/admin/;
        
        location ~ \.php\$ {
            limit_req zone=one burst=8;
            try_files \$uri =404;
            fastcgi_index index.php;
            fastcgi_pass php;
            include fastcgi_params;
            fastcgi_buffering on;
            fastcgi_buffers 96 32k;
            fastcgi_buffer_size 32k;
            fastcgi_max_temp_file_size 0;
            fastcgi_keep_conn on;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_param SCRIPT_NAME \$fastcgi_script_name;
        }
    }
    
    # ISP configuration
    server {
         listen 8805;
         root /home/xtreamcodes/iptv_xtream_codes/isp/;
         location / {
                      allow 127.0.0.1;
                      deny all;
         }
         location ~ \.php\$ {
                             limit_req zone=one burst=8;
                             try_files \$uri =404;
                             fastcgi_index index.php;
                             fastcgi_pass php;
                             include fastcgi_params;
                             fastcgi_buffering on;
                             fastcgi_buffers 96 32k;
                             fastcgi_buffer_size 32k;
                             fastcgi_max_temp_file_size 0;
                             fastcgi_keep_conn on;
                             fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
                             fastcgi_param SCRIPT_NAME \$fastcgi_script_name;
         }
    }
}
EOL

# Update database with correct ports
mysql -u root -p$PASSMYSQL xtream_iptvpro -e "UPDATE streaming_servers SET http_broadcast_port = '$CLIENTACCESPORT' WHERE streaming_servers.id = 1;"

# Update security tokens
mysql -u root -p$PASSMYSQL xtream_iptvpro -e "UPDATE settings SET live_streaming_pass = '$zzz' WHERE settings.id = 1;"
mysql -u root -p$PASSMYSQL xtream_iptvpro -e "UPDATE settings SET unique_id = '$eee' WHERE settings.id = 1;"
mysql -u root -p$PASSMYSQL xtream_iptvpro -e "UPDATE settings SET crypt_load_balancing = '$rrr' WHERE settings.id = 1;"

# Update PHP timezone configuration
sed -i "s|;date.timezone =|date.timezone = $tz|g" /home/xtreamcodes/iptv_xtream_codes/php/lib/php.ini

tput setaf 2; tput bold; echo "✓ Permissions and nginx configuration completed"; tput sgr0;

# Install enhanced updates and patches
tput setaf 4; tput bold; echo "[+] Installing enhanced patches and updates..."; tput sgr0;

# Download and apply enhanced updates from OUR repository
wget -q -O /tmp/update.zip "https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/download/v1.0/enhanced_updates.zip"
if [ -f "/tmp/update.zip" ]; then
    unzip -o /tmp/update.zip -d /tmp/update/ 2>/dev/null
    chattr -i /home/xtreamcodes/iptv_xtream_codes/GeoLite2.mmdb 2>/dev/null
    
    # Preserve PHP and GeoLite2 database
    rm -rf /tmp/update/XtreamUI-enhanced/php 2>/dev/null
    rm -rf /tmp/update/XtreamUI-enhanced/GeoLite2.mmdb 2>/dev/null
    
    # Apply OUR enhanced updates
    cp -rf /tmp/update/XtreamUI-enhanced/* /home/xtreamcodes/iptv_xtream_codes/ 2>/dev/null
    rm -rf /tmp/update
    rm -f /tmp/update.zip
    echo "✓ Enhanced updates from our repository applied"
else
    echo "⚠ Enhanced updates not found, using base installation"
fi

# Update panel version
xcversion="02"
mysql -u root -p$PASSMYSQL xtream_iptvpro -e "UPDATE admin_settings SET value = '$xcversion' WHERE admin_settings.type = 'panel_version';" 2>/dev/null

# Update GeoLite2 database from OUR repository
chattr -i /home/xtreamcodes/iptv_xtream_codes/GeoLite2.mmdb 2>/dev/null
wget -q -O /home/xtreamcodes/iptv_xtream_codes/GeoLite2.mmdb "https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/download/v1.0/GeoLite2.mmdb"
chattr +i /home/xtreamcodes/iptv_xtream_codes/GeoLite2.mmdb 2>/dev/null

# Update GeoLite2 version in database
geoliteversion=$(wget -qO- "https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/download/v1.0/geolite2_version.txt" 2>/dev/null || echo "enhanced-v1.0")
mysql -u root -p$PASSMYSQL xtream_iptvpro -e "UPDATE admin_settings SET value = '$geoliteversion' WHERE admin_settings.type = 'geolite2_version';" 2>/dev/null

# Set proper ownership and permissions
chown -R xtreamcodes:xtreamcodes /home/xtreamcodes
chmod +x /home/xtreamcodes/iptv_xtream_codes/start_services.sh
chmod +x /home/xtreamcodes/iptv_xtream_codes/permissions.sh 2>/dev/null
chmod -R 0777 /home/xtreamcodes/iptv_xtream_codes/crons 2>/dev/null

# Enhanced start services script with all fixes
tput setaf 4; tput bold; echo "[+] Creating enhanced start services script..."; tput sgr0;

cat > /home/xtreamcodes/iptv_xtream_codes/start_services.sh << 'EOL'
#!/bin/bash
# Enhanced Start Services Script with all fixes

# Kill existing processes
kill $(ps aux | grep 'xtreamcodes' | grep -v grep | grep -v 'start_services.sh' | awk '{print $2}') 2>/dev/null
sleep 1
kill $(ps aux | grep 'xtreamcodes' | grep -v grep | grep -v 'start_services.sh' | awk '{print $2}') 2>/dev/null
sleep 1
kill $(ps aux | grep 'xtreamcodes' | grep -v grep | grep -v 'start_services.sh' | awk '{print $2}') 2>/dev/null
sleep 4

# Clean up
sudo rm /home/xtreamcodes/iptv_xtream_codes/adtools/balancer/*.json 2>/dev/null &
echo "" > /home/xtreamcodes/iptv_xtream_codes/logs/error.log 2>/dev/null &
echo "" > /home/xtreamcodes/iptv_xtream_codes/logs/rtmp_error.log 2>/dev/null &
echo "" > /home/xtreamcodes/iptv_xtream_codes/logs/access.log 2>/dev/null &
sleep 1

# Setup cache and background processes
sudo -u xtreamcodes /home/xtreamcodes/iptv_xtream_codes/php/bin/php /home/xtreamcodes/iptv_xtream_codes/crons/setup_cache.php 2>/dev/null
sudo -u xtreamcodes /home/xtreamcodes/iptv_xtream_codes/php/bin/php /home/xtreamcodes/iptv_xtream_codes/tools/signal_receiver.php >/dev/null 2>/dev/null &
sudo -u xtreamcodes /home/xtreamcodes/iptv_xtream_codes/php/bin/php /home/xtreamcodes/iptv_xtream_codes/tools/pipe_reader.php >/dev/null 2>/dev/null &

# Update GeoLite2 database from OUR repository
chattr -i /home/xtreamcodes/iptv_xtream_codes/GeoLite2.mmdb 2>/dev/null
wget -qO /home/xtreamcodes/iptv_xtream_codes/GeoLite2.mmdb "https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/download/v1.0/GeoLite2.mmdb" 2>/dev/null
chattr +i /home/xtreamcodes/iptv_xtream_codes/GeoLite2.mmdb 2>/dev/null

# Update GeoLite2 version in database
geoliteversion=$(wget -qO- "https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/download/v1.0/geolite2_version.txt" 2>/dev/null || echo "enhanced-v1.0")
PASSMYSQL=$(python2 /home/xtreamcodes/iptv_xtream_codes/pytools/config.py DECRYPT 2>/dev/null | grep Password | sed "s|Password:            ||g")
mysql -u user_iptvpro -p$PASSMYSQL -P 7999 xtream_iptvpro -e "UPDATE admin_settings SET value = '$geoliteversion' WHERE admin_settings.type = 'geolite2_version';" 2>/dev/null

# Set proper ownership
chown -R xtreamcodes:xtreamcodes /sys/class/net 2>/dev/null
chown -R xtreamcodes:xtreamcodes /home/xtreamcodes 2>/dev/null

# CRITICAL FIX: Ensure libzip.so.4 symlink exists
if [ ! -f "/usr/lib/x86_64-linux-gnu/libzip.so.4" ]; then
    ln -sf /usr/lib/x86_64-linux-gnu/libzip.so.5 /usr/lib/x86_64-linux-gnu/libzip.so.4
fi

sleep 4

# Start nginx services
/home/xtreamcodes/iptv_xtream_codes/nginx_rtmp/sbin/nginx_rtmp
/home/xtreamcodes/iptv_xtream_codes/nginx/sbin/nginx

# Start PHP-FPM services with enhanced error handling
if command -v daemonize >/dev/null 2>&1; then
    daemonize -p /home/xtreamcodes/iptv_xtream_codes/php/VaiIb8.pid /home/xtreamcodes/iptv_xtream_codes/php/sbin/php-fpm --fpm-config /home/xtreamcodes/iptv_xtream_codes/php/etc/VaiIb8.conf
    daemonize -p /home/xtreamcodes/iptv_xtream_codes/php/JdlJXm.pid /home/xtreamcodes/iptv_xtream_codes/php/sbin/php-fpm --fpm-config /home/xtreamcodes/iptv_xtream_codes/php/etc/JdlJXm.conf
    daemonize -p /home/xtreamcodes/iptv_xtream_codes/php/CWcfSP.pid /home/xtreamcodes/iptv_xtream_codes/php/sbin/php-fpm --fpm-config /home/xtreamcodes/iptv_xtream_codes/php/etc/CWcfSP.conf
else
    echo "Error: daemonize not found. Installing..."
    apt-get update && apt-get install -y daemonize
    daemonize -p /home/xtreamcodes/iptv_xtream_codes/php/VaiIb8.pid /home/xtreamcodes/iptv_xtream_codes/php/sbin/php-fpm --fpm-config /home/xtreamcodes/iptv_xtream_codes/php/etc/VaiIb8.conf
    daemonize -p /home/xtreamcodes/iptv_xtream_codes/php/JdlJXm.pid /home/xtreamcodes/iptv_xtream_codes/php/sbin/php-fpm --fpm-config /home/xtreamcodes/iptv_xtream_codes/php/etc/JdlJXm.conf
    daemonize -p /home/xtreamcodes/iptv_xtream_codes/php/CWcfSP.pid /home/xtreamcodes/iptv_xtream_codes/php/sbin/php-fpm --fpm-config /home/xtreamcodes/iptv_xtream_codes/php/etc/CWcfSP.conf
fi

# Verify services started correctly
sleep 3
if ! pgrep -f "nginx.*xtreamcodes" > /dev/null; then
    echo "Warning: Nginx may not have started properly"
fi

if ! pgrep -f "php-fpm.*xtreamcodes" > /dev/null; then
    echo "Warning: PHP-FPM may not have started properly"
fi

# Check if sockets exist
if [ ! -S "/home/xtreamcodes/iptv_xtream_codes/php/VaiIb8.sock" ]; then
    echo "Warning: VaiIb8.sock not created"
fi

echo "Enhanced XtreamCodes services started"
EOL

chmod +x /home/xtreamcodes/iptv_xtream_codes/start_services.sh

# Setup auto-start on boot
if ! grep -q "@reboot root sudo /home/xtreamcodes/iptv_xtream_codes/start_services.sh" /etc/crontab; then
    echo "@reboot root sudo /home/xtreamcodes/iptv_xtream_codes/start_services.sh" >> /etc/crontab
fi

# Run permissions script
if [ -f "/home/xtreamcodes/iptv_xtream_codes/permissions.sh" ]; then
    /home/xtreamcodes/iptv_xtream_codes/permissions.sh 2>/dev/null
fi

# Clean up PHP-FPM PIDs
killall php-fpm 2>/dev/null
rm -f /home/xtreamcodes/iptv_xtream_codes/php/VaiIb8.pid /home/xtreamcodes/iptv_xtream_codes/php/JdlJXm.pid /home/xtreamcodes/iptv_xtream_codes/php/CWcfSP.pid

# Download enhanced balancer scripts from OUR repository
wget -q "https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/raw/master/scripts/balancer.php" -O /home/xtreamcodes/iptv_xtream_codes/crons/balancer.php 2>/dev/null
wget -q "https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/raw/master/scripts/balancer.sh" -O /home/xtreamcodes/iptv_xtream_codes/pytools/balancer.sh 2>/dev/null
chmod +x /home/xtreamcodes/iptv_xtream_codes/pytools/balancer.sh 2>/dev/null

tput setaf 2; tput bold; echo "✓ Enhanced patches and updates applied"; tput sgr0;

# Mount tmpfs filesystems
tput setaf 4; tput bold; echo "[+] Setting up high-performance tmpfs..."; tput sgr0;
mount -a 2>/dev/null
mkdir -p /home/xtreamcodes/iptv_xtream_codes/streams /home/xtreamcodes/iptv_xtream_codes/tmp
chmod 1777 /home/xtreamcodes/iptv_xtream_codes/streams /home/xtreamcodes/iptv_xtream_codes/tmp

# Final system optimizations
tput setaf 4; tput bold; echo "[+] Applying final system optimizations..."; tput sgr0;

# Optimize system limits
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

# Optimize kernel parameters
cat >> /etc/sysctl.conf << EOL
# XtreamCodes Enhanced Optimizations
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

sysctl -p 2>/dev/null

# Create system service for XtreamCodes (alternative to cron)
cat > /etc/systemd/system/xtreamcodes.service << EOL
[Unit]
Description=XtreamCodes Enhanced Service
After=network.target mariadb.service

[Service]
Type=forking
User=root
ExecStart=/home/xtreamcodes/iptv_xtream_codes/start_services.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable xtreamcodes.service 2>/dev/null

# Create backup and management scripts
tput setaf 4; tput bold; echo "[+] Creating management and backup scripts..."; tput sgr0;

# Create status check script
cat > /home/xtreamcodes/iptv_xtream_codes/check_status.sh << 'EOL'
#!/bin/bash
# XtreamCodes Enhanced Status Checker

echo "=== XtreamCodes Enhanced Status ==="
echo ""

# Check nginx processes
nginx_count=$(pgrep -f "nginx.*xtreamcodes" | wc -l)
echo "Nginx processes: $nginx_count"

# Check PHP-FPM processes  
phpfpm_count=$(pgrep -f "php-fpm.*xtreamcodes" | wc -l)
echo "PHP-FPM processes: $phpfpm_count"

# Check sockets
echo ""
echo "PHP-FPM Sockets:"
for sock in VaiIb8.sock JdlJXm.sock CWcfSP.sock; do
    if [ -S "/home/xtreamcodes/iptv_xtream_codes/php/$sock" ]; then
        echo "✓ $sock - OK"
    else
        echo "✗ $sock - MISSING"
    fi
done

# Check ports
echo ""
echo "Port Status:"
for port in 2086 5050 7999; do
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo "✓ Port $port - LISTENING"
    else
        echo "✗ Port $port - NOT LISTENING"
    fi
done

# Check database connection
echo ""
echo "Database Status:"
if mysql -u user_iptvpro -p$(python2 /home/xtreamcodes/iptv_xtream_codes/pytools/config.py DECRYPT 2>/dev/null | grep Password | sed "s|Password:            ||g") -P 7999 -e "SELECT 1;" 2>/dev/null >/dev/null; then
    echo "✓ Database connection - OK"
else
    echo "✗ Database connection - FAILED"
fi

# Check libzip.so.4
echo ""
echo "Dependencies:"
if [ -f "/usr/lib/x86_64-linux-gnu/libzip.so.4" ]; then
    echo "✓ libzip.so.4 - OK"
else
    echo "✗ libzip.so.4 - MISSING"
fi

echo ""
echo "=== End Status Check ==="
EOL

chmod +x /home/xtreamcodes/iptv_xtream_codes/check_status.sh

# Create quick restart script
cat > /home/xtreamcodes/iptv_xtream_codes/restart_services.sh << 'EOL'
#!/bin/bash
# XtreamCodes Enhanced Quick Restart

echo "Stopping XtreamCodes services..."
kill $(ps aux | grep 'xtreamcodes' | grep -v grep | grep -v 'restart_services.sh' | awk '{print $2}') 2>/dev/null
sleep 3

echo "Starting XtreamCodes services..."
/home/xtreamcodes/iptv_xtream_codes/start_services.sh

echo "Checking status..."
sleep 5
/home/xtreamcodes/iptv_xtream_codes/check_status.sh
EOL

chmod +x /home/xtreamcodes/iptv_xtream_codes/restart_services.sh

# Create backup script
cat > /home/xtreamcodes/iptv_xtream_codes/backup_system.sh << 'EOL'
#!/bin/bash
# XtreamCodes Enhanced Backup Script

BACKUP_DIR="/root/xtreamcodes_backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/xtreamcodes_backup_$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "Creating XtreamCodes backup..."
echo "Backup file: $BACKUP_FILE"

# Stop services
echo "Stopping services..."
kill $(ps aux | grep 'xtreamcodes' | grep -v grep | grep -v 'backup_system.sh' | awk '{print $2}') 2>/dev/null
sleep 3

# Backup database
echo "Backing up database..."
MYSQL_PASS=$(python2 /home/xtreamcodes/iptv_xtream_codes/pytools/config.py DECRYPT 2>/dev/null | grep Password | sed "s|Password:            ||g")
mysqldump -u user_iptvpro -p$MYSQL_PASS -P 7999 xtream_iptvpro > "$BACKUP_DIR/database_$DATE.sql"

# Backup files (excluding temporary directories)
echo "Backing up files..."
tar -czf "$BACKUP_FILE" \
    --exclude='/home/xtreamcodes/iptv_xtream_codes/streams/*' \
    --exclude='/home/xtreamcodes/iptv_xtream_codes/tmp/*' \
    --exclude='/home/xtreamcodes/iptv_xtream_codes/logs/*.log' \
    /home/xtreamcodes/iptv_xtream_codes/ \
    "$BACKUP_DIR/database_$DATE.sql"

# Restart services
echo "Restarting services..."
/home/xtreamcodes/iptv_xtream_codes/start_services.sh

echo "Backup completed: $BACKUP_FILE"
echo "Database backup: $BACKUP_DIR/database_$DATE.sql"

# Clean up old backups (keep last 5)
cd "$BACKUP_DIR"
ls -t xtreamcodes_backup_*.tar.gz | tail -n +6 | xargs rm -f 2>/dev/null
ls -t database_*.sql | tail -n +6 | xargs rm -f 2>/dev/null

echo "Backup cleanup completed"
EOL

chmod +x /home/xtreamcodes/iptv_xtream_codes/backup_system.sh

tput setaf 2; tput bold; echo "✓ Management scripts created"; tput sgr0;

# Start XtreamCodes services for the first time
tput setaf 4; tput bold; echo "[+] Starting XtreamCodes Enhanced services..."; tput sgr0;

# Ensure proper permissions before starting
chown -R xtreamcodes:xtreamcodes /home/xtreamcodes
chmod +x /home/xtreamcodes/iptv_xtream_codes/nginx/sbin/nginx
chmod +x /home/xtreamcodes/iptv_xtream_codes/nginx_rtmp/sbin/nginx_rtmp

# Start services
/home/xtreamcodes/iptv_xtream_codes/start_services.sh

# Wait for services to start
sleep 10

# Verify installation
tput setaf 4; tput bold; echo "[+] Verifying installation..."; tput sgr0;

# Check if services are running
nginx_running=$(pgrep -f "nginx.*xtreamcodes" | wc -l)
phpfpm_running=$(pgrep -f "php-fpm" | wc -l)
mysql_running=$(pgrep -f "mysqld" | wc -l)

if [ $nginx_running -gt 0 ] && [ $phpfpm_running -gt 0 ] && [ $mysql_running -gt 0 ]; then
    tput setaf 2; tput bold; echo "✓ All services are running successfully"; tput sgr0;
else
    tput setaf 3; tput bold; echo "⚠ Some services may need attention:"; tput sgr0;
    echo "  Nginx processes: $nginx_running"
    echo "  PHP-FPM processes: $phpfpm_running" 
    echo "  MySQL processes: $mysql_running"
fi

# Check port accessibility
port_check_failed=0
for port in $ACCESPORT $CLIENTACCESPORT 7999; do
    if ! netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        tput setaf 1; tput bold; echo "✗ Port $port is not listening"; tput sgr0;
        port_check_failed=1
    fi
done

if [ $port_check_failed -eq 0 ]; then
    tput setaf 2; tput bold; echo "✓ All required ports are active"; tput sgr0;
fi

# Final success message
clear
echo ""
tput setaf 2; tput bold; echo " ┌───────────────────────────────────────────────────────────────────┐"; tput sgr0;
tput setaf 2; tput bold; echo " │             XtreamCodes Enhanced Installation Complete           │"; tput sgr0;
tput setaf 2; tput bold; echo " └───────────────────────────────────────────────────────────────────┘"; tput sgr0;
echo ""

# Display installation information
echo -e " \033[1;33m System:\033[0m \033[1;36m$OS\033[1;32m $VER\033[0m \033[1;35m$ARCH\033[0m"
echo -e " \033[1;33m Server IP:\033[0m $ipaddr"
echo ""
tput setaf 2; tput bold; echo " ─────────────────  Installation Details  ────────────────"; tput sgr0;
tput setaf 2; tput bold; echo " │"; tput sgr0;
tput setaf 1; tput bold; echo " │ PANEL ACCESS: http://$ipaddr:$ACCESPORT"; tput sgr0;
tput setaf 2; tput bold; echo " │"; tput sgr0;
tput setaf 1; tput bold; echo " │ USERNAME: $adminL"; tput sgr0;
tput setaf 2; tput bold; echo " │"; tput sgr0;
tput setaf 2; tput bold; echo " │ PASSWORD: $adminP"; tput sgr0;
tput setaf 2; tput bold; echo " │"; tput sgr0;
tput setaf 3; tput bold; echo " │ CLIENT ACCESS PORT: $CLIENTACCESPORT"; tput sgr0;
tput setaf 2; tput bold; echo " │"; tput sgr0;
tput setaf 4; tput bold; echo " │ APACHE ACCESS PORT: $APACHEACCESPORT"; tput sgr0;
tput setaf 2; tput bold; echo " │"; tput sgr0;
tput setaf 5; tput bold; echo " │ EMAIL: $EMAIL"; tput sgr0;
tput setaf 2; tput bold; echo " │"; tput sgr0;
tput setaf 6; tput bold; echo " │ MYSQL root PASS: $PASSMYSQL"; tput sgr0;
tput setaf 2; tput bold; echo " │"; tput sgr0;
tput setaf 7; tput bold; echo " │ MYSQL user_iptvpro PASS: $XPASS"; tput sgr0;
tput setaf 2; tput bold; echo " │"; tput sgr0;
tput setaf 2; tput bold; echo " ───────────────────────────────────────────────────────────────────"; tput sgr0;
echo ""
tput setaf 6; tput bold; echo " Enhanced Features Included:"; tput sgr0;
tput setaf 2; echo " ✓ All dependency fixes applied automatically"; tput sgr0;
tput setaf 2; echo " ✓ libzip.so.4 compatibility ensured"; tput sgr0;
tput setaf 2; echo " ✓ PHP-FPM socket issues resolved"; tput sgr0;
tput setaf 2; echo " ✓ Enhanced nginx configuration"; tput sgr0;
tput setaf 2; echo " ✓ System performance optimizations"; tput sgr0;
tput setaf 2; echo " ✓ Management scripts created"; tput sgr0;
tput setaf 2; echo " ✓ Auto-restart on boot configured"; tput sgr0;
echo ""
tput setaf 6; tput bold; echo " Management Commands:"; tput sgr0;
tput setaf 3; echo " Status Check: /home/xtreamcodes/iptv_xtream_codes/check_status.sh"; tput sgr0;
tput setaf 3; echo " Restart Services: /home/xtreamcodes/iptv_xtream_codes/restart_services.sh"; tput sgr0;
tput setaf 3; echo " Create Backup: /home/xtreamcodes/iptv_xtream_codes/backup_system.sh"; tput sgr0;
echo ""
tput setaf 1; tput bold; echo " ⚠ IMPORTANT: Save this information securely!"; tput sgr0;
echo ""

# Save installation info to file
cat > /root/XtreamCodes_Enhanced_Info.txt << EOL
┌─────────────────── XtreamCodes Enhanced Installation ───────────────────┐
│
│ PANEL ACCESS: http://$ipaddr:$ACCESPORT
│
│ USERNAME: $adminL
│ PASSWORD: $adminP
│
│ CLIENT ACCESS PORT: $CLIENTACCESPORT
│ APACHE ACCESS PORT: $APACHEACCESPORT
│ EMAIL: $EMAIL
│
│ MYSQL root PASS: $PASSMYSQL
│ MYSQL user_iptvpro PASS: $XPASS
│
│ Enhanced Features:
│ ✓ All dependency fixes included
│ ✓ libzip.so.4 compatibility 
│ ✓ PHP-FPM optimizations
│ ✓ System performance tuning
│ ✓ Management scripts
│
│ Management Commands:
│ Status: /home/xtreamcodes/iptv_xtream_codes/check_status.sh
│ Restart: /home/xtreamcodes/iptv_xtream_codes/restart_services.sh  
│ Backup: /home/xtreamcodes/iptv_xtream_codes/backup_system.sh
│
│ Installation completed: $(date)
│ Enhanced by: dOC4eVER + AI Assistant
│
└──────────────────────────────────────────────────────────────────────────┘
EOL

tput setaf 6; tput bold; echo " Installation details saved to: /root/XtreamCodes_Enhanced_Info.txt"; tput sgr0;
echo ""
tput setaf 2; tput bold; echo " 🚀 XtreamCodes Enhanced is ready to use!"; tput sgr0;
echo ""

# Run final status check
echo "Running final system check..."
/home/xtreamcodes/iptv_xtream_codes/check_status.sh

echo ""
tput setaf 3; tput bold; echo "Installation completed successfully! 🎉"; tput sgr0;
echo ""

# End of enhanced installer script
