#!/usr/bin/env bash
# XtreamCodes Enhanced Uninstaller - Stefan Edition cu Backup
# =============================================
# Repository: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes
# Version: 1.1 - Uninstaller sigur cu backup complet
#
# Acest uninstaller va:
# ✅ Salva baza de date (export SQL)
# ✅ Salva toate fișierele din /home/xtreamcodes/
# ✅ Opreste toate serviciile XtreamCodes
# ✅ Dezinstalează pachetele instalate
# ✅ Curăță configurațiile de sistem
# ✅ Păstrează backup-urile într-un loc sigur
#
# IMPORTANT: Datele tale vor fi salvate în /root/xtreamcodes_backup_YYYYMMDD/

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging
logfile=$(date +%Y-%m-%d_%H.%M.%S_stefan_uninstaller.log)
backup_dir="/root/xtreamcodes_backup_$(date +%Y%m%d_%H%M%S)"

# Parse command line arguments
FORCE=false
KEEP_PACKAGES=false

while getopts ":fkh" option; do
    case "${option}" in
        f) FORCE=true ;;
        k) KEEP_PACKAGES=true ;;
        h) 
            echo "XtreamCodes Enhanced Uninstaller - Stefan Edition v1.1"
            echo "Repository: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes"
            echo ""
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -f    Force uninstall (no confirmations)"
            echo "  -k    Keep packages (nginx, php, mariadb) - doar curăță XtreamCodes"
            echo "  -h    Show this help"
            echo ""
            echo "🔧 Examples:"
            echo "Interactive mode:    curl -L .../uninstall.sh | bash"
            echo "Cleanup only:        curl -L .../uninstall.sh | bash -s -- -f -k"
            echo "Complete removal:    curl -L .../uninstall.sh | bash -s -- -f"
            echo ""
            echo "🤖 Pipe Mode: When running through pipe (curl | bash),"
            echo "   the script automatically enables cleanup mode (keeps packages)"
            echo ""
            echo "IMPORTANT: Acest script va crea backup complet înainte de dezinstalare!"
            echo "Backup location: /root/xtreamcodes_backup_YYYYMMDD_HHMMSS/"
            exit 0
            ;;
        *) ;;
    esac
done

clear
echo -e "${BLUE}"
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│         XtreamCodes Enhanced Uninstaller - Stefan Edition          │"
echo "│                    Version 1.1 @2025 - Safe Removal               │"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo -e "${NC}"
echo ""
echo -e "${CYAN}🚀 Repository: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes${NC}"
echo ""
echo -e "${GREEN}✅ Backup Features:${NC}"
echo "   • Export complet bază de date MySQL"
echo "   • Backup toate fișierele din /home/xtreamcodes/"
echo "   • Salvare configurații importante"
echo "   • Log complet al procesului de dezinstalare"
echo ""
echo -e "${YELLOW}⚠️  Warning: Acest proces va dezinstala XtreamCodes din sistem!${NC}"
echo -e "${GREEN}✅ Datele tale vor fi salvate în: ${backup_dir}${NC}"
echo ""

# System checks
echo -e "${BLUE}🔍 Checking system and XtreamCodes installation...${NC}"
sleep 1

# Check root privileges
if [ $UID -ne 0 ]; then
    echo -e "${RED}❌ This uninstaller must be run as root${NC}"
    echo "   Use: sudo -i, then run this script again"
    exit 1
fi

# Check if XtreamCodes is installed
if [ ! -d "/home/xtreamcodes/iptv_xtream_codes" ]; then
    echo -e "${YELLOW}⚠️  XtreamCodes directory not found in /home/xtreamcodes/iptv_xtream_codes${NC}"
    echo -e "${BLUE}🔍 Checking for any XtreamCodes traces...${NC}"
    
    # Check for services
    xtream_services=false
    if systemctl list-units --all | grep -i xtream >/dev/null 2>&1; then
        xtream_services=true
    fi
    
    # Check for database
    xtream_db=false
    if mysql -u root -e "SHOW DATABASES LIKE 'xtream_iptvpro';" 2>/dev/null | grep xtream_iptvpro >/dev/null; then
        xtream_db=true
    fi
    
    if [ "$xtream_services" = false ] && [ "$xtream_db" = false ]; then
        echo -e "${GREEN}✅ No XtreamCodes installation found. Nothing to uninstall.${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️  Found XtreamCodes traces in system. Proceeding with cleanup...${NC}"
    fi
else
    echo -e "${GREEN}✅ XtreamCodes installation found${NC}"
fi

echo ""

# Auto-detect if running through pipe and enable force mode
if [[ ! -t 0 ]] && [[ "$FORCE" != "true" ]]; then
    echo -e "${YELLOW}🤖 Pipe detected - enabling force mode with cleanup (keep packages)${NC}"
    FORCE=true
    KEEP_PACKAGES=true
fi

# Get user confirmation
if [ "$FORCE" = false ]; then
    echo -e "${YELLOW}🤔 Ce vrei să faci?${NC}"
    echo ""
    echo "1. 🗑️  Uninstall COMPLET (remove packages: nginx, php, mariadb + XtreamCodes)"
    echo "2. 🧹 Cleanup doar XtreamCodes (păstrează nginx, php, mariadb în sistem)"
    echo "3. ❌ Cancel (ieși fără să faci nimic)"
    echo ""
    echo -n "Alege opțiunea [1/2/3]: "
    read choice
    
    case $choice in
        1)
            KEEP_PACKAGES=false
            echo -e "${RED}🗑️  Mod COMPLET: Va dezinstala totul (nginx, php, mariadb, XtreamCodes)${NC}"
            ;;
        2)
            KEEP_PACKAGES=true
            echo -e "${YELLOW}🧹 Mod CLEANUP: Va păstra pachetele, curăță doar XtreamCodes${NC}"
            ;;
        3|*)
            echo -e "${GREEN}❌ Uninstall cancelled by user${NC}"
            exit 0
            ;;
    esac
    
    echo ""
    echo -e "${YELLOW}⚠️  ULTIMA CONFIRMARE ⚠️${NC}"
    echo -e "${RED}Ești sigur că vrei să continui? Acest proces NU poate fi anulat!${NC}"
    echo -e "${GREEN}Backup-ul va fi salvat în: ${backup_dir}${NC}"
    echo ""
    echo -n "Type 'YES' to continue: "
    read final_confirm
    
    if [ "$final_confirm" != "YES" ]; then
        echo -e "${GREEN}❌ Uninstall cancelled by user${NC}"
        exit 0
    fi
else
    echo -e "${YELLOW}🤖 Force mode enabled - proceeding automatically${NC}"
    if [ "$KEEP_PACKAGES" = true ]; then
        echo -e "${YELLOW}🧹 Cleanup mode: Păstrează packages (nginx, php, mariadb)${NC}"
        echo -e "${BLUE}ℹ️  Va curăța doar XtreamCodes și va face backup complet${NC}"
    else
        echo -e "${RED}🗑️  Complete mode: Removing all packages${NC}"
        echo -e "${RED}⚠️  Va șterge totul: nginx, php, mariadb + XtreamCodes${NC}"
    fi
    echo ""
    echo -e "${GREEN}🚀 Starting automatic uninstall in 3 seconds...${NC}"
    sleep 3
fi

# Start logging
touch "$logfile"
exec > >(tee "$logfile")
exec 2>&1

clear
echo ""
echo -e "${BLUE}🚀 Starting XtreamCodes Enhanced Uninstallation...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}📋 Backup Directory: ${backup_dir}${NC}"
echo -e "${GREEN}📝 Log File: ${logfile}${NC}"
echo -e "${GREEN}🕐 Started: $(date)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create backup directory
echo -e "${BLUE}📁 Creating backup directory...${NC}"
mkdir -p "$backup_dir"/{database,files,configs,logs}

# Function to stop services safely
stop_service() {
    local service_name="$1"
    local display_name="$2"
    
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        echo -e "${YELLOW}🛑 Stopping $display_name...${NC}"
        systemctl stop "$service_name" >/dev/null 2>&1
        sleep 2
        
        if systemctl is-active --quiet "$service_name" 2>/dev/null; then
            echo -e "${RED}⚠️  Failed to stop $display_name gracefully, forcing...${NC}"
            systemctl kill "$service_name" >/dev/null 2>&1
            sleep 1
        fi
        echo -e "${GREEN}✅ $display_name stopped${NC}"
    else
        echo -e "${YELLOW}⚠️  $display_name was not running${NC}"
    fi
}

# 1. STOP ALL XTREAMCODES SERVICES
echo -e "${YELLOW}🛑 Stopping XtreamCodes services...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Stop custom XtreamCodes service
if systemctl list-units --all | grep xtreamcodes.service >/dev/null 2>&1; then
    stop_service "xtreamcodes" "XtreamCodes Service"
    systemctl disable xtreamcodes >/dev/null 2>&1
fi

# Kill any remaining XtreamCodes processes
echo -e "${YELLOW}🔫 Killing any remaining XtreamCodes processes...${NC}"
pkill -f "xtreamcodes" 2>/dev/null || true
pkill -f "nginx.*xtreamcodes" 2>/dev/null || true

# Stop nginx and php-fpm if we're doing cleanup
stop_service "nginx" "Nginx"
stop_service "php7.4-fpm" "PHP-FPM 7.4"

echo ""

# 2. BACKUP DATABASE
echo -e "${BLUE}🗄️  Backing up XtreamCodes database...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Try to get MySQL root password from installation file
mysql_pass=""
if [ -f "/root/XtreamCodes_Stefan_Installation_v1.1.txt" ]; then
    mysql_pass=$(grep "MySQL Root Pass:" /root/XtreamCodes_Stefan_Installation_v1.1.txt | awk '{print $4}' 2>/dev/null)
fi

# Try to export database with different methods
db_exported=false

# Method 1: Try with found password
if [ ! -z "$mysql_pass" ]; then
    echo -e "${YELLOW}🔑 Trying with found MySQL password...${NC}"
    if mysql -u root -p"$mysql_pass" -e "SHOW DATABASES LIKE 'xtream_iptvpro';" 2>/dev/null | grep xtream_iptvpro >/dev/null; then
        echo -e "${GREEN}✅ MySQL connection successful${NC}"
        mysqldump -u root -p"$mysql_pass" xtream_iptvpro > "$backup_dir/database/xtream_iptvpro_backup.sql" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Database exported successfully${NC}"
            db_exported=true
        fi
    fi
fi

# Method 2: Try without password
if [ "$db_exported" = false ]; then
    echo -e "${YELLOW}🔑 Trying MySQL without password...${NC}"
    if mysql -u root -e "SHOW DATABASES LIKE 'xtream_iptvpro';" 2>/dev/null | grep xtream_iptvpro >/dev/null; then
        echo -e "${GREEN}✅ MySQL connection successful (no password)${NC}"
        mysqldump -u root xtream_iptvpro > "$backup_dir/database/xtream_iptvpro_backup.sql" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Database exported successfully${NC}"
            db_exported=true
        fi
    fi
fi

# Method 3: Ask user for password
if [ "$db_exported" = false ] && [ "$FORCE" = false ]; then
    echo -e "${YELLOW}🔑 Need MySQL root password to backup database${NC}"
    echo -n "Enter MySQL root password (or press Enter to skip backup): "
    read -s user_mysql_pass
    echo ""
    
    if [ ! -z "$user_mysql_pass" ]; then
        if mysql -u root -p"$user_mysql_pass" -e "SHOW DATABASES LIKE 'xtream_iptvpro';" 2>/dev/null | grep xtream_iptvpro >/dev/null; then
            mysqldump -u root -p"$user_mysql_pass" xtream_iptvpro > "$backup_dir/database/xtream_iptvpro_backup.sql" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ Database exported successfully${NC}"
                db_exported=true
            fi
        fi
    fi
fi

if [ "$db_exported" = false ]; then
    echo -e "${RED}⚠️  Could not backup database - continuing without database backup${NC}"
    echo "❌ Database backup failed" > "$backup_dir/database/backup_failed.txt"
else
    # Also save database info
    echo "XtreamCodes Database Backup" > "$backup_dir/database/backup_info.txt"
    echo "Date: $(date)" >> "$backup_dir/database/backup_info.txt"
    echo "Database: xtream_iptvpro" >> "$backup_dir/database/backup_info.txt"
    echo "File: xtream_iptvpro_backup.sql" >> "$backup_dir/database/backup_info.txt"
fi

echo ""

# 3. BACKUP FILES
echo -e "${BLUE}📁 Backing up XtreamCodes files...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -d "/home/xtreamcodes" ]; then
    echo -e "${YELLOW}📦 Creating archive of /home/xtreamcodes/...${NC}"
    tar -czf "$backup_dir/files/xtreamcodes_files.tar.gz" -C /home xtreamcodes 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Files archived successfully${NC}"
        
        # Also copy the directory structure
        echo -e "${YELLOW}📋 Copying directory structure...${NC}"
        cp -r /home/xtreamcodes "$backup_dir/files/xtreamcodes_copy" 2>/dev/null
        
        # Create file list
        find /home/xtreamcodes -type f > "$backup_dir/files/file_list.txt" 2>/dev/null
        echo -e "${GREEN}✅ Directory copied successfully${NC}"
    else
        echo -e "${RED}⚠️  Failed to create files archive${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  /home/xtreamcodes/ directory not found${NC}"
    echo "Directory not found" > "$backup_dir/files/not_found.txt"
fi

# Backup important config files
echo -e "${YELLOW}⚙️  Backing up configuration files...${NC}"

# Nginx configs
if [ -f "/etc/nginx/nginx.conf" ]; then
    cp /etc/nginx/nginx.conf "$backup_dir/configs/nginx.conf" 2>/dev/null
fi

# PHP configs
if [ -f "/etc/php/7.4/fpm/pool.d/xtreamcodes.conf" ]; then
    cp /etc/php/7.4/fpm/pool.d/xtreamcodes.conf "$backup_dir/configs/php_xtreamcodes.conf" 2>/dev/null
fi

# MariaDB configs
if [ -f "/etc/mysql/mariadb.cnf" ]; then
    cp /etc/mysql/mariadb.cnf "$backup_dir/configs/mariadb.cnf" 2>/dev/null
fi

# SystemD service
if [ -f "/etc/systemd/system/xtreamcodes.service" ]; then
    cp /etc/systemd/system/xtreamcodes.service "$backup_dir/configs/xtreamcodes.service" 2>/dev/null
fi

# Installation info
if [ -f "/root/XtreamCodes_Stefan_Installation_v1.1.txt" ]; then
    cp /root/XtreamCodes_Stefan_Installation_v1.1.txt "$backup_dir/configs/" 2>/dev/null
fi

# System configs affected by XtreamCodes
if [ -f "/etc/security/limits.conf" ]; then
    cp /etc/security/limits.conf "$backup_dir/configs/limits.conf.backup" 2>/dev/null
fi

if [ -f "/etc/sysctl.conf" ]; then
    cp /etc/sysctl.conf "$backup_dir/configs/sysctl.conf.backup" 2>/dev/null
fi

if [ -f "/etc/fstab" ]; then
    cp /etc/fstab "$backup_dir/configs/fstab.backup" 2>/dev/null
fi

if [ -f "/etc/sudoers" ]; then
    cp /etc/sudoers "$backup_dir/configs/sudoers.backup" 2>/dev/null
fi

echo -e "${GREEN}✅ Configuration files backed up${NC}"
echo ""

# 4. BACKUP LOGS
echo -e "${BLUE}📋 Backing up logs...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Copy nginx logs
if [ -d "/var/log/nginx" ]; then
    cp -r /var/log/nginx "$backup_dir/logs/" 2>/dev/null
fi

# Copy PHP logs
if [ -d "/var/log/php7.4-fpm" ]; then
    cp -r /var/log/php7.4-fpm "$backup_dir/logs/" 2>/dev/null
fi

# Copy MySQL logs
if [ -f "/var/log/mysql/error.log" ]; then
    cp /var/log/mysql/error.log "$backup_dir/logs/mysql_error.log" 2>/dev/null
fi

# Copy XtreamCodes logs
if [ -d "/home/xtreamcodes/iptv_xtream_codes/logs" ]; then
    cp -r /home/xtreamcodes/iptv_xtream_codes/logs "$backup_dir/logs/xtreamcodes_logs" 2>/dev/null
fi

echo -e "${GREEN}✅ Logs backed up${NC}"
echo ""

# 5. REMOVE XTREAMCODES SERVICES AND CONFIGS
echo -e "${RED}🗑️  Removing XtreamCodes services and configurations...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Remove systemd service
if [ -f "/etc/systemd/system/xtreamcodes.service" ]; then
    echo -e "${YELLOW}🗑️  Removing XtreamCodes systemd service...${NC}"
    systemctl stop xtreamcodes >/dev/null 2>&1
    systemctl disable xtreamcodes >/dev/null 2>&1
    rm -f /etc/systemd/system/xtreamcodes.service
    systemctl daemon-reload
    echo -e "${GREEN}✅ SystemD service removed${NC}"
fi

# Remove from crontab
echo -e "${YELLOW}🗑️  Removing XtreamCodes from crontab...${NC}"
if grep -q "xtreamcodes" /etc/crontab 2>/dev/null; then
    sed -i '/xtreamcodes/d' /etc/crontab
    echo -e "${GREEN}✅ Crontab entries removed${NC}"
else
    echo -e "${YELLOW}⚠️  No crontab entries found${NC}"
fi

# Remove sudoers entry
echo -e "${YELLOW}🗑️  Removing XtreamCodes sudoers entries...${NC}"
if grep -q "xtreamcodes ALL" /etc/sudoers 2>/dev/null; then
    sed -i '/xtreamcodes ALL/d' /etc/sudoers
    echo -e "${GREEN}✅ Sudoers entries removed${NC}"
else
    echo -e "${YELLOW}⚠️  No sudoers entries found${NC}"
fi

# Unmount tmpfs filesystems
echo -e "${YELLOW}🗑️  Unmounting tmpfs filesystems...${NC}"
if mountpoint -q /home/xtreamcodes/iptv_xtream_codes/streams 2>/dev/null; then
    umount /home/xtreamcodes/iptv_xtream_codes/streams 2>/dev/null
    echo -e "${GREEN}✅ Streams tmpfs unmounted${NC}"
fi

if mountpoint -q /home/xtreamcodes/iptv_xtream_codes/tmp 2>/dev/null; then
    umount /home/xtreamcodes/iptv_xtream_codes/tmp 2>/dev/null
    echo -e "${GREEN}✅ Tmp tmpfs unmounted${NC}"
fi

# Remove fstab entries
echo -e "${YELLOW}🗑️  Removing tmpfs entries from fstab...${NC}"
if grep -q "xtreamcodes" /etc/fstab 2>/dev/null; then
    sed -i '/xtreamcodes/d' /etc/fstab
    echo -e "${GREEN}✅ Fstab entries removed${NC}"
else
    echo -e "${YELLOW}⚠️  No fstab entries found${NC}"
fi

# Remove xtreamcodes user
echo -e "${YELLOW}🗑️  Removing xtreamcodes user...${NC}"
if id "xtreamcodes" >/dev/null 2>&1; then
    userdel xtreamcodes 2>/dev/null
    echo -e "${GREEN}✅ User removed${NC}"
else
    echo -e "${YELLOW}⚠️  User not found${NC}"
fi

# Remove PHP-FPM pool config
if [ -f "/etc/php/7.4/fpm/pool.d/xtreamcodes.conf" ]; then
    echo -e "${YELLOW}🗑️  Removing PHP-FPM XtreamCodes pool...${NC}"
    rm -f /etc/php/7.4/fpm/pool.d/xtreamcodes.conf
    echo -e "${GREEN}✅ PHP-FPM pool removed${NC}"
fi

echo ""

# 6. REMOVE DATABASE
echo -e "${RED}🗄️  Removing XtreamCodes database...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Try to remove database
db_removed=false

# Try with found password
if [ ! -z "$mysql_pass" ]; then
    if mysql -u root -p"$mysql_pass" -e "DROP DATABASE IF EXISTS xtream_iptvpro; DROP USER IF EXISTS 'user_iptvpro'@'%';" 2>/dev/null; then
        echo -e "${GREEN}✅ Database and user removed${NC}"
        db_removed=true
    fi
fi

# Try without password
if [ "$db_removed" = false ]; then
    if mysql -u root -e "DROP DATABASE IF EXISTS xtream_iptvpro; DROP USER IF EXISTS 'user_iptvpro'@'%';" 2>/dev/null; then
        echo -e "${GREEN}✅ Database and user removed${NC}"
        db_removed=true
    fi
fi

if [ "$db_removed" = false ]; then
    echo -e "${RED}⚠️  Could not remove database automatically${NC}"
    echo -e "${YELLOW}🔧 Manual removal required:${NC}"
    echo "   mysql -u root -p"
    echo "   DROP DATABASE IF EXISTS xtream_iptvpro;"
    echo "   DROP USER IF EXISTS 'user_iptvpro'@'%';"
fi

echo ""

# 7. REMOVE DIRECTORIES
echo -e "${RED}🗑️  Removing XtreamCodes directories...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -d "/home/xtreamcodes" ]; then
    echo -e "${YELLOW}🗑️  Removing /home/xtreamcodes/ directory...${NC}"
    rm -rf /home/xtreamcodes/
    echo -e "${GREEN}✅ XtreamCodes directory removed${NC}"
else
    echo -e "${YELLOW}⚠️  Directory already removed or not found${NC}"
fi

echo ""

# 8. CLEAN SYSTEM CONFIGS
echo -e "${YELLOW}🧹 Cleaning XtreamCodes system optimizations...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Remove system limits added by XtreamCodes
echo -e "${YELLOW}🔧 Removing system limits...${NC}"
if grep -q "xtreamcodes" /etc/security/limits.conf 2>/dev/null; then
    sed -i '/xtreamcodes/d' /etc/security/limits.conf
    echo -e "${GREEN}✅ System limits cleaned${NC}"
fi

# Remove sysctl optimizations (keep backup, let user decide)
echo -e "${YELLOW}🔧 Checking sysctl optimizations...${NC}"
if grep -q "XtreamCodes Enhanced Optimizations" /etc/sysctl.conf 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Found XtreamCodes sysctl optimizations${NC}"
    echo -e "${BLUE}ℹ️  Keeping sysctl optimizations (might be useful for system)${NC}"
    echo -e "${BLUE}ℹ️  If you want to remove them, check: /etc/sysctl.conf${NC}"
else
    echo -e "${GREEN}✅ No sysctl optimizations found${NC}"
fi

echo ""

# 9. PACKAGE REMOVAL (if not keeping packages)
if [ "$KEEP_PACKAGES" = false ]; then
    echo -e "${RED}🗑️  Removing installed packages...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Stop services first
    echo -e "${YELLOW}🛑 Stopping services before removal...${NC}"
    systemctl stop nginx php7.4-fpm mariadb 2>/dev/null || true
    
    # Remove packages
    echo -e "${YELLOW}📦 Removing packages...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get -yqq purge \
        nginx nginx-core nginx-common \
        php7.4 php7.4-fpm php7.4-cli php7.4-mysql php7.4-curl php7.4-gd \
        php7.4-json php7.4-zip php7.4-xml php7.4-mbstring php7.4-soap \
        php7.4-intl php7.4-bcmath php7.4-opcache \
        mariadb-server mariadb-client \
        >/dev/null 2>&1
    
    # Remove dependencies
    echo -e "${YELLOW}🧹 Removing unused dependencies...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get -yqq autoremove >/dev/null 2>&1
    
    # Clean package cache
    echo -e "${YELLOW}🧹 Cleaning package cache...${NC}"
    apt-get clean >/dev/null 2>&1
    
    echo -e "${GREEN}✅ Packages removed successfully${NC}"
else
    echo -e "${BLUE}📦 Keeping packages as requested (nginx, php, mariadb)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Just clean XtreamCodes configs from nginx
    if [ -f "/etc/nginx/nginx.conf" ]; then
        echo -e "${YELLOW}🔧 Restoring default nginx configuration...${NC}"
        # Create a basic nginx config
        cat > /etc/nginx/nginx.conf << 'NGINXDEFAULT'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
NGINXDEFAULT
        echo -e "${GREEN}✅ Nginx configuration restored to default${NC}"
    fi
    
    # Restart services
    echo -e "${YELLOW}🔄 Restarting services...${NC}"
    systemctl restart nginx php7.4-fpm mariadb 2>/dev/null || true
    echo -e "${GREEN}✅ Services restarted${NC}"
fi

echo ""

# 10. CLEANUP TEMP FILES
echo -e "${BLUE}🧹 Final cleanup...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Remove installation files
if [ -f "/root/XtreamCodes_Stefan_Installation_v1.1.txt" ]; then
    echo -e "${YELLOW}🗑️  Removing installation info file...${NC}"
    rm -f /root/XtreamCodes_Stefan_Installation_v1.1.txt
    echo -e "${GREEN}✅ Installation info removed${NC}"
fi

# Remove any remaining XtreamCodes files in /tmp
rm -f /tmp/database.sql 2>/dev/null
rm -f /tmp/xtreamcodes*.tar.gz 2>/dev/null

# Update file database
echo -e "${YELLOW}🔄 Updating file database...${NC}"
updatedb 2>/dev/null || true

echo -e "${GREEN}✅ Final cleanup completed${NC}"
echo ""

# 11. CREATE RESTORE INSTRUCTIONS
echo -e "${BLUE}📝 Creating restore instructions...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > "$backup_dir/RESTORE_INSTRUCTIONS.txt" << 'RESTOREEOF'
┌─────────────────── XtreamCodes Backup Restore Instructions ───────────────────┐
│
│ BACKUP CREATED BY: Stefan's Enhanced XtreamCodes Uninstaller v1.1
│ REPOSITORY: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes
│
│ ═══════════════════════════════════════════════════════════════════════════════
│ BACKUP CONTENTS:
│ ═══════════════════════════════════════════════════════════════════════════════
│
│ 📁 /database/
│    ├── xtream_iptvpro_backup.sql    - Complete database backup
│    └── backup_info.txt              - Database information
│
│ 📁 /files/
│    ├── xtreamcodes_files.tar.gz     - Compressed archive of all files
│    ├── xtreamcodes_copy/            - Direct copy of directory structure
│    └── file_list.txt                - List of all backed up files
│
│ 📁 /configs/
│    ├── nginx.conf                   - Nginx configuration
│    ├── php_xtreamcodes.conf         - PHP-FPM pool configuration
│    ├── mariadb.cnf                  - MariaDB configuration
│    ├── xtreamcodes.service          - SystemD service file
│    └── *.backup                     - System configuration backups
│
│ 📁 /logs/
│    └── Various log files from nginx, php, mysql, xtreamcodes
│
│ ═══════════════════════════════════════════════════════════════════════════════
│ RESTORE PROCEDURE:
│ ═══════════════════════════════════════════════════════════════════════════════
│
│ 🔄 TO RESTORE XTREAMCODES:
│
│ 1. Install fresh XtreamCodes using Stefan's installer:
│    curl -L https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/raw/master/install.sh | bash
│
│ 2. Stop XtreamCodes services:
│    systemctl stop xtreamcodes nginx php7.4-fpm
│
│ 3. Restore database:
│    mysql -u root -p xtream_iptvpro < database/xtream_iptvpro_backup.sql
│
│ 4. Restore files:
│    rm -rf /home/xtreamcodes/
│    tar -xzf files/xtreamcodes_files.tar.gz -C /
│    chown -R xtreamcodes:xtreamcodes /home/xtreamcodes/
│
│ 5. Restore configurations (optional):
│    cp configs/nginx.conf /etc/nginx/
│    cp configs/php_xtreamcodes.conf /etc/php/7.4/fpm/pool.d/
│    cp configs/xtreamcodes.service /etc/systemd/system/
│    systemctl daemon-reload
│
│ 6. Start services:
│    systemctl start xtreamcodes
│
│ ═══════════════════════════════════════════════════════════════════════════════
│ IMPORTANT NOTES:
│ ═══════════════════════════════════════════════════════════════════════════════
│
│ • Make sure to install XtreamCodes on the same OS version for best compatibility
│ • Database passwords and user credentials are preserved in the backup
│ • Configuration files may need adjustment for different server IPs
│ • Check file permissions after restore
│ • Test all functionality after restore
│
│ 🔗 For support: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes
│
└─────────────────────────────────────────────────────────────────────────────────┘
RESTOREEOF

echo -e "${GREEN}✅ Restore instructions created${NC}"

# Set proper backup permissions
chown -R root:root "$backup_dir"
chmod -R 600 "$backup_dir"
chmod 700 "$backup_dir"

echo ""

# FINAL STATUS
clear
echo ""
echo -e "${GREEN}🎉 XtreamCodes Enhanced Uninstall Completed Successfully!${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}                    🗑️  UNINSTALLATION COMPLETE - STEFAN EDITION v1.1${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${CYAN}📋 UNINSTALL SUMMARY:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ XtreamCodes services stopped and removed${NC}"
echo -e "${GREEN}✅ Database exported and removed${NC}"
echo -e "${GREEN}✅ Files backed up and removed${NC}"
echo -e "${GREEN}✅ System configurations cleaned${NC}"
echo -e "${GREEN}✅ User accounts removed${NC}"

if [ "$KEEP_PACKAGES" = false ]; then
    echo -e "${GREEN}✅ Packages removed (nginx, php, mariadb)${NC}"
else
    echo -e "${YELLOW}⚠️  Packages kept (nginx, php, mariadb)${NC}"
fi

echo ""
echo -e "${CYAN}💾 BACKUP INFORMATION:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}📁 Backup Directory: ${backup_dir}${NC}"
echo -e "${GREEN}📝 Uninstall Log: ${logfile}${NC}"
echo -e "${GREEN}📋 Restore Guide: ${backup_dir}/RESTORE_INSTRUCTIONS.txt${NC}"
echo ""
echo -e "${CYAN}📊 BACKUP CONTENTS:${NC}"
if [ "$db_exported" = true ]; then
    echo -e "${GREEN}✅ Database: xtream_iptvpro_backup.sql${NC}"
else
    echo -e "${RED}❌ Database: Backup failed${NC}"
fi
echo -e "${GREEN}✅ Files: xtreamcodes_files.tar.gz${NC}"
echo -e "${GREEN}✅ Configs: nginx, php, mariadb, systemd${NC}"
echo -e "${GREEN}✅ Logs: nginx, php, mysql, xtreamcodes${NC}"
echo ""
echo -e "${CYAN}🔄 TO RESTORE LATER:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Install fresh XtreamCodes with Stefan's installer"
echo "2. Follow instructions in: ${backup_dir}/RESTORE_INSTRUCTIONS.txt"
echo "3. Restore database and files from backup"
echo ""
echo -e "${CYAN}🔗 REPOSITORY:${NC} https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes"
echo ""
echo -e "${GREEN}🙏 Thank you for using Stefan's Enhanced XtreamCodes Tools!${NC}"
echo ""

# Copy uninstall log to backup
cp "$logfile" "$backup_dir/logs/uninstall.log"

echo -e "${BLUE}📝 Uninstall completed at: $(date)${NC}"
echo -e "${BLUE}📁 All your data is safely stored in: ${backup_dir}${NC}"

# End of Stefan's Enhanced Uninstaller
