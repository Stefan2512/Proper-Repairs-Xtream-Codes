#!/usr/bin/env bash
# XtreamCodes Enhanced Installer v2.0 - Stefan Edition
# =====================================================
# Repository: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes
# Version: 2.0 - Completely rewritten and enhanced
#
# Features:
# ✅ Modular design with better error handling
# ✅ Real XtreamCodes archives from GitHub releases
# ✅ Official Ubuntu Nginx (not bundled version)
# ✅ PHP 7.4 with optimized configuration
# ✅ Enhanced MySQL/MariaDB setup
# ✅ Advanced monitoring and management scripts
# ✅ Automatic system optimization
# ✅ Full compatibility with Ubuntu 18.04/20.04/22.04
#
# Supported: Ubuntu 18.04/20.04/22.04 (64-bit)

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# =================== CONFIGURATION ===================

# Script version and info
readonly SCRIPT_VERSION="2.0"
readonly SCRIPT_NAME="XtreamCodes Enhanced Installer"
readonly GITHUB_REPO="Stefan2512/Proper-Repairs-Xtream-Codes"
readonly GITHUB_URL="https://github.com/${GITHUB_REPO}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Logging setup
readonly LOG_FILE="$(date +%Y-%m-%d_%H.%M.%S)_xtreamcodes_installer_v2.log"
readonly INSTALL_INFO_FILE="/root/XtreamCodes_Stefan_Installation_v2.0.txt"

# Global variables
SILENT_MODE="no"
DETECTED_OS=""
DETECTED_VER=""
DETECTED_ARCH=""
SERVER_IP=""
ADMIN_USERNAME=""
ADMIN_PASSWORD=""
ADMIN_EMAIL=""
MYSQL_ROOT_PASSWORD=""
ADMIN_PORT="2086"
CLIENT_PORT="5050"
APACHE_PORT="3672"
TIMEZONE="Europe/Bucharest"

# XtreamCodes internal configuration
XTREAM_DB_PASSWORD=""
XTREAM_SALT=""
XTREAM_UNIQUE_ID=""
XTREAM_CRYPT_KEY=""

# =================== UTILITY FUNCTIONS ===================

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Print colored messages
print_header() {
    echo -e "${CYAN}$*${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $*${NC}"
    log "SUCCESS: $*"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $*${NC}"
    log "WARNING: $*"
}

print_error() {
    echo -e "${RED}❌ $*${NC}"
    log "ERROR: $*"
}

print_info() {
    echo -e "${BLUE}ℹ️  $*${NC}"
    log "INFO: $*"
}

print_step() {
    echo -e "${PURPLE}🔧 $*${NC}"
    log "STEP: $*"
}

# Error handling
handle_error() {
    local line_no=$1
    local error_code=$2
    print_error "Installation failed at line $line_no with exit code $error_code"
    print_error "Check the log file: $LOG_FILE"
    exit "$error_code"
}

trap 'handle_error ${LINENO} $?' ERR

# Progress indicator
show_progress() {
    local duration=$1
    local task_name=$2
    local elapsed=0
    
    while [ $elapsed -lt $duration ]; do
        printf "\r${YELLOW}⏳ $task_name... [%d/%d]${NC}" $elapsed $duration
        sleep 1
        ((elapsed++))
    done
    printf "\r${GREEN}✅ $task_name completed!${NC}\n"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# =================== SYSTEM DETECTION ===================

detect_system() {
    print_step "Detecting system information"
    
    # Detect OS
    if [ -f /etc/lsb-release ]; then
        DETECTED_OS=$(grep DISTRIB_ID /etc/lsb-release | sed 's/^.*=//')
        DETECTED_VER=$(grep DISTRIB_RELEASE /etc/lsb-release | sed 's/^.*=//')
    elif [ -f /etc/os-release ]; then
        DETECTED_OS=$(grep -w ID /etc/os-release | sed 's/^.*=//' | tr -d '"')
        DETECTED_VER=$(grep VERSION_ID /etc/os-release | sed 's/^.*=//;s/"//g' | head -n 1)
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
    
    DETECTED_ARCH=$(uname -m)
    
    print_info "Detected: $DETECTED_OS $DETECTED_VER $DETECTED_ARCH"
    
    # Validate compatibility
    if [[ "$DETECTED_OS" != "Ubuntu" ]]; then
        print_error "This installer only supports Ubuntu"
        exit 1
    fi
    
    if [[ ! "$DETECTED_VER" =~ ^(18\.04|20\.04|22\.04)$ ]]; then
        print_error "This installer only supports Ubuntu 18.04, 20.04, or 22.04"
        print_error "Detected version: $DETECTED_VER"
        exit 1
    fi
    
    if [[ "$DETECTED_ARCH" != "x86_64" ]]; then
        print_error "This installer only supports x86_64 architecture"
        print_error "Detected architecture: $DETECTED_ARCH"
        exit 1
    fi
    
    print_success "System compatibility check passed"
}

# =================== PREREQUISITES CHECK ===================

check_prerequisites() {
    print_step "Checking prerequisites"
    
    # Check root privileges
    if [ "$UID" -ne 0 ]; then
        print_error "This installer must be run as root"
        print_error "Use: sudo -i, then run this script again"
        exit 1
    fi
    
    # Check for existing installations
    if [ -d "/home/xtreamcodes/iptv_xtream_codes" ]; then
        print_error "XtreamCodes is already installed"
        print_error "Directory exists: /home/xtreamcodes/iptv_xtream_codes"
        print_error "Please remove existing installation or use a clean server"
        exit 1
    fi
    
    # Check for control panels
    if [ -e /usr/local/cpanel ] || [ -e /usr/local/directadmin ]; then
        print_error "Control panel detected"
        print_error "Please use a clean OS installation without control panels"
        exit 1
    fi
    
    # Check internet connectivity
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        print_warning "Internet connectivity check failed"
        print_warning "Installation may fail if internet is not available"
    fi
    
    print_success "Prerequisites check passed"
}

# =================== SERVER INFORMATION ===================

get_server_info() {
    print_step "Gathering server information"
    
    # Get server IP
    SERVER_IP=$(wget -qO- http://api.sentora.org/ip.txt 2>/dev/null || curl -s http://ipinfo.io/ip 2>/dev/null || echo "127.0.0.1")
    
    if [[ "$SERVER_IP" == "127.0.0.1" ]]; then
        print_warning "Could not detect public IP address"
        SERVER_IP=$(ip addr show 2>/dev/null | awk '$1 == "inet" && $3 == "brd" { sub (/\/.*/,""); print $2 }' | head -1 || echo "127.0.0.1")
    fi
    
    print_info "Server IP: $SERVER_IP"
    
    # Generate secure passwords
    XTREAM_DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-16)
    XTREAM_SALT=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)
    XTREAM_UNIQUE_ID=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-10)
    XTREAM_CRYPT_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)
    
    print_success "Server information gathered"
}

# =================== USER INPUT ===================

parse_arguments() {
    while getopts ":t:a:p:o:c:r:e:m:s:h" option; do
        case "${option}" in
            t) TIMEZONE=${OPTARG} ;;
            a) ADMIN_USERNAME=${OPTARG} ;;
            p) ADMIN_PASSWORD=${OPTARG} ;;
            o) ADMIN_PORT=${OPTARG} ;;
            c) CLIENT_PORT=${OPTARG} ;;
            r) APACHE_PORT=${OPTARG} ;;
            e) ADMIN_EMAIL=${OPTARG} ;;
            m) MYSQL_ROOT_PASSWORD=${OPTARG} ;;
            s) SILENT_MODE=${OPTARG} ;;
            h) show_help; exit 0 ;;
            *) ;;
        esac
    done
}

show_help() {
    echo -e "${WHITE}$SCRIPT_NAME v$SCRIPT_VERSION${NC}"
    echo -e "Repository: $GITHUB_URL"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -t timezone        Set timezone (default: Europe/Bucharest)"
    echo "  -a username        Admin username (default: admin)"
    echo "  -p password        Admin password (default: admin123)"
    echo "  -o port           Admin panel port (default: 2086)"
    echo "  -c port           Client access port (default: 5050)"
    echo "  -r port           Apache compatibility port (default: 3672)"
    echo "  -e email          Admin email (default: admin@example.com)"
    echo "  -m password       MySQL root password (default: mysql123)"
    echo "  -s yes            Silent install with defaults"
    echo "  -h                Show this help"
    echo ""
    echo "Quick install:"
    echo "curl -L $GITHUB_URL/raw/master/install.sh | bash"
    echo ""
    echo "Silent install:"
    echo "curl -L $GITHUB_URL/raw/master/install.sh | bash -s -- -s yes"
}

get_user_input() {
    if [[ "$SILENT_MODE" == "yes" ]] || [[ ! -t 0 ]]; then
        print_info "Using silent mode with default values"
        ADMIN_USERNAME=${ADMIN_USERNAME:-"admin"}
        ADMIN_PASSWORD=${ADMIN_PASSWORD:-"admin123"}
        ADMIN_EMAIL=${ADMIN_EMAIL:-"admin@example.com"}
        MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-"mysql123"}
        return
    fi
    
    print_header "Configuration Setup"
    echo ""
    
    echo -n "👤 Admin username [admin]: "
    read -r input
    ADMIN_USERNAME=${input:-"admin"}
    
    echo -n "🔒 Admin password [admin123]: "
    read -r input
    ADMIN_PASSWORD=${input:-"admin123"}
    
    echo -n "📧 Admin email [admin@example.com]: "
    read -r input
    ADMIN_EMAIL=${input:-"admin@example.com"}
    
    echo -n "🗄️  MySQL root password [mysql123]: "
    read -r input
    MYSQL_ROOT_PASSWORD=${input:-"mysql123"}
    
    echo ""
    echo "🔧 Port configuration (press Enter for defaults):"
    
    echo -n "🌐 Admin panel port [2086]: "
    read -r input
    ADMIN_PORT=${input:-"2086"}
    
    echo -n "📡 Client access port [5050]: "
    read -r input
    CLIENT_PORT=${input:-"5050"}
    
    echo -n "🔧 Apache compatibility port [3672]: "
    read -r input
    APACHE_PORT=${input:-"3672"}
    
    echo ""
    echo -n "🚀 Ready to install XtreamCodes Enhanced v$SCRIPT_VERSION? [Y/n]: "
    read -r confirm
    confirm=${confirm:-"y"}
    case $confirm in
        [Yy]*|"") ;;
        *) print_error "Installation cancelled"; exit 0;;
    esac
}

# =================== PACKAGE MANAGEMENT ===================

prepare_system() {
    print_step "Preparing system for installation"
    
    # Set non-interactive mode
    export DEBIAN_FRONTEND=noninteractive
    
    # Disable needrestart prompts
    if [ -f "/etc/apt/apt.conf.d/99needrestart" ]; then
        sed -i 's|DPkg::Post-Invoke|#DPkg::Post-Invoke|' "/etc/apt/apt.conf.d/99needrestart"
    fi
    
    # Update package lists
    print_info "Updating package lists..."
    apt-get -qq update
    
    print_success "System prepared"
}

install_dependencies() {
    print_step "Installing system dependencies"
    
    local packages=(
        # Basic tools
        "curl" "wget" "unzip" "zip" "tar" "gpg"
        "software-properties-common" "apt-transport-https"
        "ca-certificates" "gnupg" "lsb-release"
        
        # System tools
        "net-tools" "dnsutils" "htop" "nano" "vim"
        "cron" "logrotate" "rsyslog"
        
        # Development tools
        "build-essential" "pkg-config" "autoconf"
        "libtool" "make" "gcc" "g++"
        
        # Python
        "python2" "python3" "python-is-python2"
        
        # Libraries
        "libzip5" "libzip-dev" "libonig5" "libonig-dev"
        "libsodium23" "libsodium-dev" "libargon2-1" "libargon2-dev"
        "libbz2-dev" "libpng-dev" "libxml2-dev" "libssl-dev"
        "libcurl4-openssl-dev" "libxslt1-dev" "libmaxminddb-dev"
        "libaio-dev" "libreadline-dev"
        
        # Process management
        "daemonize" "supervisor"
    )
    
    print_info "Installing ${#packages[@]} packages..."
    apt-get -yqq install "${packages[@]}" >/dev/null 2>&1
    
    # Critical fix: Create libzip.so.4 symlink for compatibility
    if [ ! -f "/usr/lib/x86_64-linux-gnu/libzip.so.4" ]; then
        ln -sf /usr/lib/x86_64-linux-gnu/libzip.so.5 /usr/lib/x86_64-linux-gnu/libzip.so.4
    fi
    ldconfig
    
    print_success "Dependencies installed successfully"
}

# =================== USER MANAGEMENT ===================

create_xtream_user() {
    print_step "Creating XtreamCodes system user"
    
    if ! id "xtreamcodes" &>/dev/null; then
        adduser --system --shell /bin/false --group --disabled-login xtreamcodes >/dev/null 2>&1
        print_success "User 'xtreamcodes' created"
    else
        print_info "User 'xtreamcodes' already exists"
    fi
    
    # Create XtreamCodes directory
    mkdir -p /home/xtreamcodes/iptv_xtream_codes
    chown -R xtreamcodes:xtreamcodes /home/xtreamcodes
    
    # Configure sudo permissions
    if ! grep -q "xtreamcodes ALL = (root) NOPASSWD:" /etc/sudoers; then
        echo "xtreamcodes ALL = (root) NOPASSWD: /sbin/iptables, /usr/bin/chattr, /usr/bin/python2, /usr/bin/python" >> /etc/sudoers
        print_success "Sudo permissions configured"
    fi
}

# =================== DATABASE SETUP ===================

install_mariadb() {
    print_step "Installing and configuring MariaDB"
    
    # Install MariaDB
    apt-get -yqq install mariadb-server mariadb-client >/dev/null 2>&1
    
    # Start and enable MariaDB
    systemctl start mariadb >/dev/null 2>&1
    systemctl enable mariadb >/dev/null 2>&1
    
    # Configure MariaDB root password
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD'; FLUSH PRIVILEGES;" 2>/dev/null || \
    mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('$MYSQL_ROOT_PASSWORD') WHERE User='root'; FLUSH PRIVILEGES;" 2>/dev/null || \
    mysqladmin -u root password "$MYSQL_ROOT_PASSWORD" 2>/dev/null
    
    print_success "MariaDB installed and configured"
}

configure_mariadb() {
    print_step "Optimizing MariaDB configuration"
    
    # Create optimized MariaDB configuration
    cat > /etc/mysql/mariadb.cnf << 'EOF'
# XtreamCodes Enhanced MariaDB Configuration v2.0

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
skip-name-resolve = 1

bind-address = *
key_buffer_size = 256M

# MyISAM settings
myisam_sort_buffer_size = 8M
myisam-recover-options = BACKUP

# Connection settings
max_connections = 20000
back_log = 4096
max_connect_errors = 10000

# Memory and caching
max_allowed_packet = 128M
table_open_cache = 8192
table_definition_cache = 8192
query_cache_limit = 8M
query_cache_size = 512M

# Temporary tables
tmp_table_size = 2G
max_heap_table_size = 2G

# InnoDB settings
innodb_buffer_pool_size = 4G
innodb_buffer_pool_instances = 8
innodb_read_io_threads = 32
innodb_write_io_threads = 32
innodb_thread_concurrency = 0
innodb_flush_log_at_trx_commit = 0
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1
innodb_io_capacity = 4000
innodb_table_locks = 0
innodb_lock_wait_timeout = 0
innodb_deadlock_detect = 0

# Logging
expire_logs_days = 7
max_binlog_size = 100M

# Performance
performance_schema = 0
sql_mode = "NO_ENGINE_SUBSTITUTION"

[mysqldump]
quick
quote-names
max_allowed_packet = 32M

[mysql]

[isamchk]
key_buffer_size = 32M
EOF

    # Restart MariaDB with new configuration
    systemctl restart mariadb
    sleep 3
    
    print_success "MariaDB configuration optimized"
}

# =================== PHP INSTALLATION ===================

install_php() {
    print_step "Installing PHP 7.4 and extensions"
    
    # For Ubuntu 22.04, add PHP repository
    if [[ "$DETECTED_VER" == "22.04" ]]; then
        print_info "Adding PHP repository for Ubuntu 22.04"
        add-apt-repository ppa:ondrej/php -y >/dev/null 2>&1
        apt-get -qq update
    fi
    
    # Install PHP 7.4 and extensions
    local php_packages=(
        "php7.4" "php7.4-fpm" "php7.4-cli"
        "php7.4-mysql" "php7.4-curl" "php7.4-gd"
        "php7.4-json" "php7.4-zip" "php7.4-xml"
        "php7.4-mbstring" "php7.4-soap" "php7.4-intl"
        "php7.4-bcmath" "php7.4-opcache" "php7.4-common"
        "php7.4-readline" "php7.4-bz2" "php7.4-imap"
    )
    
    apt-get -yqq install "${php_packages[@]}" >/dev/null 2>&1
    
    print_success "PHP 7.4 installed with extensions"
}

configure_php() {
    print_step "Configuring PHP-FPM for XtreamCodes"
    
    # Backup original configuration
    if [ -f "/etc/php/7.4/fpm/pool.d/www.conf" ]; then
        cp /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/www.conf.backup
    fi
    
    # Create XtreamCodes PHP-FPM pool
    cat > /etc/php/7.4/fpm/pool.d/xtreamcodes.conf << EOF
[xtreamcodes]
user = xtreamcodes
group = xtreamcodes
listen = /run/php/php7.4-fpm-xtreamcodes.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 100
pm.start_servers = 10
pm.min_spare_servers = 10
pm.max_spare_servers = 30
pm.max_requests = 2000

chdir = /home/xtreamcodes/iptv_xtream_codes

; PHP settings for XtreamCodes
php_admin_value[upload_max_filesize] = 100M
php_admin_value[post_max_size] = 100M
php_admin_value[max_execution_time] = 600
php_admin_value[max_input_time] = 600
php_admin_value[memory_limit] = 1G
php_admin_value[max_input_vars] = 10000
php_admin_value[session.save_path] = /tmp
EOF

    # Update PHP-FPM main configuration
    sed -i 's/^;emergency_restart_threshold = 0/emergency_restart_threshold = 10/' /etc/php/7.4/fpm/php-fpm.conf
    sed -i 's/^;emergency_restart_interval = 0/emergency_restart_interval = 1m/' /etc/php/7.4/fpm/php-fpm.conf
    sed -i 's/^;process_control_timeout = 0/process_control_timeout = 10s/' /etc/php/7.4/fpm/php-fpm.conf
    
    print_success "PHP-FPM configured for XtreamCodes"
}

# =================== NGINX INSTALLATION ===================

install_nginx() {
    print_step "Installing official Nginx"
    
    # Remove any existing nginx installations
    systemctl stop nginx 2>/dev/null || true
    apt-get -yqq purge nginx nginx-common nginx-core nginx-full 2>/dev/null || true
    apt-get autoremove -y >/dev/null 2>&1
    
    # Install official Nginx from Ubuntu repository
    apt-get -yqq install nginx nginx-core nginx-common >/dev/null 2>&1
    
    # Stop and disable default nginx (we'll configure it manually)
    systemctl stop nginx >/dev/null 2>&1
    systemctl disable nginx >/dev/null 2>&1
    
    print_success "Official Nginx installed"
}

configure_nginx() {
    print_step "Configuring Nginx for XtreamCodes"
    
    # Backup original configuration
    if [ -f "/etc/nginx/nginx.conf" ]; then
        cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
    fi
    
    # Create optimized Nginx configuration
    cat > /etc/nginx/nginx.conf << EOF
user www-data;
worker_processes auto;
worker_rlimit_nofile 300000;
pid /run/nginx.pid;

events {
    worker_connections 20000;
    use epoll;
    accept_mutex on;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Performance optimizations
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    reset_timedout_connection on;
    keepalive_timeout 30;
    keepalive_requests 10000;
    client_body_timeout 15s;
    client_header_timeout 15s;
    send_timeout 20m;
    sendfile_max_chunk 512k;
    lingering_close off;
    
    # Buffer settings
    client_max_body_size 500M;
    client_body_buffer_size 256k;
    client_header_buffer_size 2k;
    large_client_header_buffers 8 8k;
    
    # Security settings
    server_tokens off;
    
    # Logging
    access_log off;
    error_log /var/log/nginx/error.log warn;
    
    # Gzip compression
    gzip off;
    
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=admin:20m rate=15r/s;
    limit_req_zone \$binary_remote_addr zone=api:20m rate=100r/s;
    
    # FastCGI optimizations
    fastcgi_read_timeout 300;
    fastcgi_buffers 128 64k;
    fastcgi_buffer_size 64k;
    fastcgi_max_temp_file_size 0;
    fastcgi_keep_conn on;
    fastcgi_connect_timeout 60s;
    fastcgi_send_timeout 60s;
    
    # Upstream PHP-FPM
    upstream php_xtreamcodes {
        server unix:/run/php/php7.4-fpm-xtreamcodes.sock;
    }
    
    # Admin Panel Server
    server {
        listen $ADMIN_PORT default_server;
        server_name _;
        root /home/xtreamcodes/iptv_xtream_codes/admin;
        index index.php index.html;
        
        limit_req zone=admin burst=30 nodelay;
        
        # Security headers
        add_header X-Frame-Options SAMEORIGIN always;
        add_header X-Content-Type-Options nosniff always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        
        location / {
            try_files \$uri \$uri/ /index.php?\$query_string;
        }
        
        location ~ \.php\$ {
            try_files \$uri =404;
            fastcgi_split_path_info ^(.+\.php)(/.+)\$;
            fastcgi_pass php_xtreamcodes;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_param PATH_INFO \$fastcgi_path_info;
        }
        
        # Deny access to sensitive files
        location ~ /\.(ht|git|svn) {
            deny all;
        }
        
        location ~ \.(log|ini|conf)\$ {
            deny all;
        }
    }
    
    # Client Access Server
    server {
        listen $CLIENT_PORT;
        server_name _;
        root /home/xtreamcodes/iptv_xtream_codes/wwwdir;
        index index.php index.html;
        
        limit_req zone=api burst=200 nodelay;
        
        # XtreamCodes URL rewrite rules
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
        
        # Stalker Portal support
        rewrite ^/server/load.php\$ /portal.php break;
        
        location /stalker_portal/c {
            alias /home/xtreamcodes/iptv_xtream_codes/wwwdir/c;
        }
        
        # FFmpeg Progress (localhost only)
        location = /progress.php {
            allow 127.0.0.1;
            deny all;
            fastcgi_pass php_xtreamcodes;
            include fastcgi_params;
            fastcgi_ignore_client_abort on;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        }
        
        location / {
            try_files \$uri \$uri/ /index.php?\$query_string;
        }
        
        location ~ \.php\$ {
            try_files \$uri =404;
            fastcgi_split_path_info ^(.+\.php)(/.+)\$;
            fastcgi_pass php_xtreamcodes;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_param PATH_INFO \$fastcgi_path_info;
        }
        
        # Handle streaming content
        location ~* \.(ts|m3u8)\$ {
            add_header Cache-Control no-cache;
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Headers *;
            expires -1;
        }
        
        # Deny access to sensitive files
        location ~ /\.(ht|git|svn) {
            deny all;
        }
    }
    
    # Apache Compatibility Server
    server {
        listen $APACHE_PORT;
        server_name _;
        root /home/xtreamcodes/iptv_xtream_codes/wwwdir;
        index index.php index.html;
        
        location / {
            try_files \$uri \$uri/ /index.php?\$query_string;
        }
        
        location ~ \.php\$ {
            try_files \$uri =404;
            fastcgi_pass php_xtreamcodes;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        }
    }
    
    # ISP Configuration Server (localhost only)
    server {
        listen 8805;
        server_name _;
        root /home/xtreamcodes/iptv_xtream_codes/isp;
        index index.php index.html;
        
        location / {
            allow 127.0.0.1;
            deny all;
        }
        
        location ~ \.php\$ {
            try_files \$uri =404;
            fastcgi_pass php_xtreamcodes;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        }
    }
}
EOF

    # Test nginx configuration
    if nginx -t >/dev/null 2>&1; then
        print_success "Nginx configuration is valid"
    else
        print_error "Nginx configuration test failed"
        exit 1
    fi
}

# =================== XTREAMCODES INSTALLATION ===================

determine_archive_name() {
    case "$DETECTED_VER" in
        "18.04") echo "xtreamcodes_enhanced_Ubuntu_18.04.tar.gz" ;;
        "20.04") echo "xtreamcodes_enhanced_Ubuntu_20.04.tar.gz" ;;
        "22.04") echo "xtreamcodes_enhanced_Ubuntu_22.04.tar.gz" ;;
        *) echo "xtreamcodes_enhanced_universal.tar.gz" ;;
    esac
}

download_xtreamcodes() {
    print_step "Downloading XtreamCodes archive"
    
    local archive_name=$(determine_archive_name)
    local download_urls=(
        "$GITHUB_URL/releases/latest/download/$archive_name"
        "$GITHUB_URL/releases/download/v2.0/$archive_name"
        "$GITHUB_URL/raw/master/$archive_name"
    )
    
    print_info "Archive: $archive_name"
    
    mkdir -p /tmp
    cd /tmp
    
    local downloaded=false
    for url in "${download_urls[@]}"; do
        print_info "Trying: $url"
        if wget -q --timeout=60 --tries=3 -O "/tmp/$archive_name" "$url" 2>/dev/null; then
            if [ -s "/tmp/$archive_name" ] && tar -tzf "/tmp/$archive_name" >/dev/null 2>&1; then
                print_success "Archive downloaded and verified"
                downloaded=true
                break
            else
                rm -f "/tmp/$archive_name"
            fi
        fi
    done
    
    if [ "$downloaded" = false ]; then
        print_error "Failed to download XtreamCodes archive: $archive_name"
        print_error "Please check internet connection and repository access"
        exit 1
    fi
    
    # Download database.sql
    print_info "Downloading database.sql from repository"
    if ! wget -q -O /tmp/database.sql "$GITHUB_URL/raw/master/database.sql"; then
        print_error "Failed to download database.sql"
        exit 1
    fi
    
    print_success "XtreamCodes files downloaded"
}

extract_xtreamcodes() {
    print_step "Extracting XtreamCodes files"
    
    local archive_name=$(determine_archive_name)
    
    cd /home/xtreamcodes
    if tar -xzf "/tmp/$archive_name" 2>/dev/null; then
        print_success "Archive extracted successfully"
    else
        print_error "Failed to extract archive"
        exit 1
    fi
    
    # Verify and fix directory structure
    if [ ! -d "/home/xtreamcodes/iptv_xtream_codes" ]; then
        local extracted_dir=$(find /home/xtreamcodes -maxdepth 1 -type d -name "*xtream*" 2>/dev/null | head -1)
        if [ -n "$extracted_dir" ]; then
            mv "$extracted_dir" "/home/xtreamcodes/iptv_xtream_codes"
            print_info "Directory structure fixed"
        else
            print_error "Invalid archive structure"
            exit 1
        fi
    fi
    
    # Set proper ownership and permissions
    chown -R xtreamcodes:xtreamcodes /home/xtreamcodes
    find /home/xtreamcodes/iptv_xtream_codes -name "*.sh" -exec chmod +x {} \; 2>/dev/null
    find /home/xtreamcodes/iptv_xtream_codes/bin -type f -exec chmod +x {} \; 2>/dev/null
    
    print_success "XtreamCodes files extracted and configured"
}

# =================== DATABASE CONFIGURATION ===================

configure_database() {
    print_step "Configuring XtreamCodes database"
    
    # Create database and import schema
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS xtream_iptvpro; CREATE DATABASE xtream_iptvpro;" 2>/dev/null
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" xtream_iptvpro < /tmp/database.sql 2>/dev/null
    
    # Create database user
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON *.* TO 'user_iptvpro'@'%' IDENTIFIED BY '$XTREAM_DB_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;" 2>/dev/null
    
    # Configure streaming server
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" xtream_iptvpro -e "
        UPDATE streaming_servers SET 
            server_ip='$SERVER_IP',
            ssh_port='22',
            system_os='$DETECTED_OS $DETECTED_VER',
            network_interface='$(route 2>/dev/null | grep default | awk '{print $8}' | head -1 || echo "eth0")',
            http_broadcast_port='$CLIENT_PORT'
        WHERE id=1;
    " 2>/dev/null
    
    # Update system settings
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" xtream_iptvpro -e "
        UPDATE settings SET 
            live_streaming_pass='$XTREAM_SALT',
            unique_id='$XTREAM_UNIQUE_ID',
            crypt_load_balancing='$XTREAM_CRYPT_KEY'
        WHERE id=1;
    " 2>/dev/null
    
    print_success "Database configured successfully"
}

create_admin_user() {
    print_step "Creating admin user"
    
    # Generate password hash
    local password_hash
    password_hash=$(perl -e 'print crypt($ARGV[1], "\$6\$rounds=20000\$xtreamcodes\$" . $ARGV[2]), "\n";' "6" "$ADMIN_PASSWORD" "$XTREAM_SALT" 2>/dev/null)
    
    # Create admin user
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" xtream_iptvpro -e "
        INSERT INTO reg_users (
            id, username, password, email, ip, date_registered, 
            verify_key, verified, member_group_id, status, 
            last_login, exp_date, admin_enabled, admin_notes, 
            reseller_dns, owner_id, override_packages, google_2fa_sec
        ) VALUES (
            1, '$ADMIN_USERNAME', '$password_hash', '$ADMIN_EMAIL', '', 
            UNIX_TIMESTAMP(), '', 1, 1, 1, 
            NULL, 4070905200, 1, '', 
            '', 0, '', ''
        ) ON DUPLICATE KEY UPDATE 
            username='$ADMIN_USERNAME',
            password='$password_hash',
            email='$ADMIN_EMAIL';
    " 2>/dev/null
    
    print_success "Admin user created: $ADMIN_USERNAME"
}

create_config_file() {
    print_step "Creating XtreamCodes configuration"
    
    # Create config file using Python
    python2 << EOF
import json
from itertools import cycle, izip

config_data = json.dumps({
    "host": "127.0.0.1",
    "db_user": "user_iptvpro", 
    "db_pass": "$XTREAM_DB_PASSWORD",
    "db_name": "xtream_iptvpro",
    "server_id": 1,
    "db_port": 7999
})

encrypted = ''.join(chr(ord(c)^ord(k)) for c,k in izip(config_data, cycle('5709650b0d7806074842c6de575025b1')))

with open('/home/xtreamcodes/iptv_xtream_codes/config', 'wb') as f:
    f.write(encrypted.encode('base64').replace('\n', ''))
EOF
    
    chown xtreamcodes:xtreamcodes /home/xtreamcodes/iptv_xtream_codes/config
    
    print_success "Configuration file created"
}

# =================== SYSTEM OPTIMIZATION ===================

configure_system_limits() {
    print_step "Configuring system limits"
    
    # Configure system limits
    cat >> /etc/security/limits.conf << EOF
# XtreamCodes Enhanced Limits
* soft nofile 300000
* hard nofile 300000
* soft nproc 300000
* hard nproc 300000
xtreamcodes soft nofile 300000
xtreamcodes hard nofile 300000
xtreamcodes soft nproc 300000
xtreamcodes hard nproc 300000
EOF

    # Configure kernel parameters  
    cat >> /etc/sysctl.conf << EOF
# XtreamCodes Enhanced Kernel Parameters
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
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF

    sysctl -p >/dev/null 2>&1
    
    print_success "System limits configured"
}

configure_tmpfs() {
    print_step "Configuring tmpfs mounts"
    
    # Add tmpfs mounts to fstab
    if ! grep -q "tmpfs /home/xtreamcodes/iptv_xtream_codes/streams" /etc/fstab; then
        echo "tmpfs /home/xtreamcodes/iptv_xtream_codes/streams tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777,size=90% 0 0" >> /etc/fstab
    fi
    
    if ! grep -q "tmpfs /home/xtreamcodes/iptv_xtream_codes/tmp" /etc/fstab; then
        echo "tmpfs /home/xtreamcodes/iptv_xtream_codes/tmp tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777,size=4G 0 0" >> /etc/fstab
    fi
    
    # Create directories and mount
    mkdir -p /home/xtreamcodes/iptv_xtream_codes/streams /home/xtreamcodes/iptv_xtream_codes/tmp
    mount -a 2>/dev/null
    chmod 1777 /home/xtreamcodes/iptv_xtream_codes/streams /home/xtreamcodes/iptv_xtream_codes/tmp
    
    print_success "Tmpfs mounts configured"
}

# =================== MANAGEMENT SCRIPTS ===================

create_management_scripts() {
    print_step "Creating management scripts"
    
    # Start services script
    cat > /home/xtreamcodes/iptv_xtream_codes/start_services.sh << 'EOF'
#!/bin/bash
# XtreamCodes Enhanced v2.0 - Start Services

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 Starting XtreamCodes Enhanced v2.0 Services${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd /home/xtreamcodes/iptv_xtream_codes

# Function to check service status
check_service() {
    if pgrep -f "$1" > /dev/null; then
        echo -e "${GREEN}✅ $2 is running${NC}"
        return 0
    else
        echo -e "${RED}❌ $2 is not running${NC}"
        return 1
    fi
}

# Start core services
echo -e "${YELLOW}🗄️  Starting MariaDB...${NC}"
systemctl start mariadb
sleep 2

echo -e "${YELLOW}🐘 Starting PHP-FPM...${NC}"
systemctl start php7.4-fpm
sleep 2

echo -e "${YELLOW}🌐 Starting Nginx...${NC}"
systemctl start nginx
sleep 2

# Start XtreamCodes services if binaries exist
if [ -f "./bin/nginx" ]; then
    echo -e "${YELLOW}⚙️  Starting XtreamCodes nginx...${NC}"
    sudo -u xtreamcodes ./bin/nginx 2>/dev/null &
fi

if [ -f "./bin/nginx_rtmp" ]; then
    echo -e "${YELLOW}📡 Starting XtreamCodes RTMP...${NC}"
    sudo -u xtreamcodes ./bin/nginx_rtmp 2>/dev/null &
fi

sleep 5

echo ""
echo -e "${GREEN}📊 Service Status:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_service "mariadb" "MariaDB"
check_service "php7.4-fpm" "PHP-FPM 7.4"
check_service "nginx.*master" "Nginx"

echo ""
echo -e "${GREEN}🎯 XtreamCodes Enhanced v2.0 services started!${NC}"
EOF

    # Status check script
    cat > /home/xtreamcodes/iptv_xtream_codes/check_status.sh << 'EOF'
#!/bin/bash
# XtreamCodes Enhanced v2.0 - Status Check

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}"
echo "┌─────────────────────────────────────────────────────────────────────┐"
echo "│         XtreamCodes Enhanced v2.0 Status Check - Stefan            │"
echo "│                      $(date '+%Y-%m-%d %H:%M:%S')                      │"
echo "└─────────────────────────────────────────────────────────────────────┘"
echo -e "${NC}"

# Check service status
check_service_status() {
    local service_name="$1"
    local process_name="$2"
    local port="$3"
    
    local pid_count=$(pgrep -f "$process_name" 2>/dev/null | wc -l)
    
    if [ $pid_count -gt 0 ]; then
        echo -e "${GREEN}✅ $service_name${NC} - Running ($pid_count processes)"
        
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
check_service_status "Nginx" "nginx.*master" ""

echo ""
echo -e "${YELLOW}🌐 Network Ports:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v netstat >/dev/null 2>&1; then
    for port in 2086 5050 3672 8805 7999; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            echo -e "${GREEN}✅ Port $port${NC} - Listening"
        else
            echo -e "${RED}❌ Port $port${NC} - Not listening"
        fi
    done
fi

echo ""
echo -e "${YELLOW}📁 File System:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check directories
for dir in "/home/xtreamcodes/iptv_xtream_codes" "/home/xtreamcodes/iptv_xtream_codes/admin" "/home/xtreamcodes/iptv_xtream_codes/wwwdir"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✅ $(basename $dir) Directory${NC} - Present"
    else
        echo -e "${RED}❌ $(basename $dir) Directory${NC} - Missing"
    fi
done

# Check tmpfs mounts
for mount in "streams" "tmp"; do
    if mountpoint -q "/home/xtreamcodes/iptv_xtream_codes/$mount" 2>/dev/null; then
        echo -e "${GREEN}✅ $mount tmpfs${NC} - Mounted"
    else
        echo -e "${RED}❌ $mount tmpfs${NC} - Not mounted"
    fi
done

# Check PHP socket
if [ -S "/run/php/php7.4-fpm-xtreamcodes.sock" ]; then
    echo -e "${GREEN}✅ PHP-FPM Socket${NC} - Present"
else
    echo -e "${RED}❌ PHP-FPM Socket${NC} - Missing"
fi

echo ""
echo -e "${YELLOW}💾 System Resources:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v free >/dev/null 2>&1; then
    mem_info=$(free -h | grep "Mem:" | awk '{print $2" total, "$3" used, "$7" available"}')
    echo -e "${BLUE}🧠 Memory:${NC} $mem_info"
fi

if command -v df >/dev/null 2>&1; then
    disk_info=$(df -h /home/xtreamcodes 2>/dev/null | tail -1 | awk '{print $2" total, "$3" used, "$4" available ("$5" used)"}')
    echo -e "${BLUE}💽 Disk:${NC} $disk_info"
fi

if [ -f "/proc/loadavg" ]; then
    load_avg=$(cat /proc/loadavg | cut -d' ' -f1-3)
    echo -e "${BLUE}⚡ Load Average:${NC} $load_avg"
fi

echo ""
echo -e "${BLUE}🔧 Management Commands:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Restart services: /home/xtreamcodes/iptv_xtream_codes/restart_services.sh"
echo "View nginx logs: tail -f /var/log/nginx/error.log"
echo "Test nginx config: nginx -t"
echo "Reload nginx: systemctl reload nginx"
echo ""
EOF

    # Restart services script
    cat > /home/xtreamcodes/iptv_xtream_codes/restart_services.sh << 'EOF'
#!/bin/bash
# XtreamCodes Enhanced v2.0 - Restart Services

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🔄 Restarting XtreamCodes Enhanced v2.0 Services${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Stop services
echo -e "${YELLOW}🛑 Stopping services...${NC}"
systemctl stop nginx 2>/dev/null
systemctl stop php7.4-fpm 2>/dev/null

# Kill XtreamCodes processes
pkill -f "nginx.*xtreamcodes" 2>/dev/null || true

sleep 3

# Start services
echo -e "${YELLOW}🚀 Starting services...${NC}"
/home/xtreamcodes/iptv_xtream_codes/start_services.sh

echo ""
echo -e "${GREEN}✅ Service restart completed!${NC}"
echo "Check status: /home/xtreamcodes/iptv_xtream_codes/check_status.sh"
EOF

    # Make scripts executable
    chmod +x /home/xtreamcodes/iptv_xtream_codes/*.sh
    chown -R xtreamcodes:xtreamcodes /home/xtreamcodes/iptv_xtream_codes/*.sh
    
    print_success "Management scripts created"
}

# =================== SERVICE CONFIGURATION ===================

configure_services() {
    print_step "Configuring system services"
    
    # Create systemd service
    cat > /etc/systemd/system/xtreamcodes.service << EOF
[Unit]
Description=XtreamCodes Enhanced v2.0 Service
After=network.target mariadb.service php7.4-fpm.service
Requires=mariadb.service php7.4-fpm.service

[Service]
Type=forking
User=root
ExecStart=/home/xtreamcodes/iptv_xtream_codes/start_services.sh
ExecReload=/home/xtreamcodes/iptv_xtream_codes/restart_services.sh
Restart=always
RestartSec=10
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable xtreamcodes.service >/dev/null 2>&1
    
    # Configure auto-start
    if ! grep -q "@reboot root /home/xtreamcodes/iptv_xtream_codes/start_services.sh" /etc/crontab; then
        echo "@reboot root /home/xtreamcodes/iptv_xtream_codes/start_services.sh" >> /etc/crontab
    fi
    
    print_success "System services configured"
}

# =================== SERVICE STARTUP ===================

start_services() {
    print_step "Starting XtreamCodes services"
    
    # Set timezone
    echo "$TIMEZONE" > /etc/timezone
    rm -f /etc/localtime
    ln -s "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    timedatectl set-timezone "$TIMEZONE" 2>/dev/null || true
    
    # Start services in correct order
    systemctl start mariadb
    sleep 2
    
    systemctl start php7.4-fpm
    sleep 2
    
    # Test nginx configuration before starting
    if nginx -t >/dev/null 2>&1; then
        systemctl start nginx
        print_success "Nginx started successfully"
    else
        print_warning "Nginx configuration test failed, attempting to fix..."
        # Create minimal working config
        cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    upstream php_xtreamcodes {
        server unix:/run/php/php7.4-fpm-xtreamcodes.sock;
    }
    
    server {
        listen 2086;
        root /home/xtreamcodes/iptv_xtream_codes/admin;
        index index.php;
        
        location ~ \.php$ {
            fastcgi_pass php_xtreamcodes;
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
            fastcgi_pass php_xtreamcodes;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        }
    }
}
EOF
        nginx -t && systemctl start nginx
    fi
    
    # Start XtreamCodes specific processes
    cd /home/xtreamcodes/iptv_xtream_codes
    if [ -f "./start_services.sh" ]; then
        sudo -u xtreamcodes ./start_services.sh >/dev/null 2>&1 &
    fi
    
    sleep 5
    print_success "All services started"
}

# =================== INSTALLATION VERIFICATION ===================

verify_installation() {
    print_step "Verifying installation"
    
    local errors=0
    
    # Check services
    if ! pgrep -f "nginx.*master" >/dev/null; then
        print_warning "Nginx is not running"
        ((errors++))
    fi
    
    if ! pgrep -f "php7.4-fpm" >/dev/null; then
        print_warning "PHP-FPM is not running"
        ((errors++))
    fi
    
    if ! pgrep -f "mysqld" >/dev/null; then
        print_warning "MariaDB is not running"
        ((errors++))
    fi
    
    # Check sockets
    if [ ! -S "/run/php/php7.4-fpm-xtreamcodes.sock" ]; then
        print_warning "PHP-FPM socket not found"
        ((errors++))
    fi
    
    # Check ports
    if command_exists netstat; then
        for port in "$ADMIN_PORT" "$CLIENT_PORT" "7999"; do
            if ! netstat -tlnp 2>/dev/null | grep -q ":$port "; then
                print_warning "Port $port is not listening"
                ((errors++))
            fi
        done
    fi
    
    # Check directories
    for dir in "/home/xtreamcodes/iptv_xtream_codes/admin" "/home/xtreamcodes/iptv_xtream_codes/wwwdir"; do
        if [ ! -d "$dir" ]; then
            print_warning "Directory missing: $dir"
            ((errors++))
        fi
    done
    
    if [ $errors -eq 0 ]; then
        print_success "Installation verification passed"
        return 0
    else
        print_warning "Installation completed with $errors warnings"
        return 1
    fi
}

# =================== CLEANUP ===================

cleanup() {
    print_step "Cleaning up temporary files"
    
    rm -f /tmp/xtreamcodes_enhanced_*.tar.gz
    rm -f /tmp/database.sql
    rm -f /tmp/enhanced_updates.zip
    
    print_success "Cleanup completed"
}

# =================== FINAL REPORT ===================

generate_final_report() {
    local installation_success=$1
    
    clear
    echo ""
    
    if [ $installation_success -eq 0 ]; then
        print_header "🎉 XtreamCodes Enhanced v$SCRIPT_VERSION Installation Complete!"
    else
        print_header "⚠️  XtreamCodes Enhanced v$SCRIPT_VERSION Installation Completed with Warnings"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                       INSTALLATION SUMMARY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📋 SYSTEM INFORMATION:"
    echo "   OS: $DETECTED_OS $DETECTED_VER ($DETECTED_ARCH)"
    echo "   Server IP: $SERVER_IP"
    echo "   Timezone: $TIMEZONE"
    echo "   Installation Date: $(date)"
    echo ""
    echo "🌐 ACCESS INFORMATION:"
    echo "   Admin Panel: http://$SERVER_IP:$ADMIN_PORT"
    echo "   Username: $ADMIN_USERNAME"
    echo "   Password: $ADMIN_PASSWORD"
    echo "   Email: $ADMIN_EMAIL"
    echo ""
    echo "🔧 TECHNICAL DETAILS:"
    echo "   Client Port: $CLIENT_PORT"
    echo "   Apache Port: $APACHE_PORT"
    echo "   MySQL Port: 7999"
    echo "   MySQL Root Password: $MYSQL_ROOT_PASSWORD"
    echo "   MySQL XtreamCodes Password: $XTREAM_DB_PASSWORD"
    echo ""
    echo "📦 INSTALLED VERSIONS:"
    echo "   Nginx: $(nginx -v 2>&1 | cut -d' ' -f3)"
    echo "   PHP: $(php7.4 -v | head -1 | cut -d' ' -f2)"
    echo "   MariaDB: $(mysql --version | awk '{print $5}' | sed 's/,//')"
    echo ""
    echo "🛠️  MANAGEMENT COMMANDS:"
    echo "   Status Check: /home/xtreamcodes/iptv_xtream_codes/check_status.sh"
    echo "   Restart Services: /home/xtreamcodes/iptv_xtream_codes/restart_services.sh"
    echo "   Start Services: /home/xtreamcodes/iptv_xtream_codes/start_services.sh"
    echo "   Test Nginx: nginx -t"
    echo "   Reload Nginx: systemctl reload nginx"
    echo ""
    echo "🆕 ENHANCED FEATURES v$SCRIPT_VERSION:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   ✅ Modular installer design with advanced error handling"
    echo "   ✅ Real XtreamCodes archives from GitHub releases"
    echo "   ✅ Official Ubuntu Nginx (not bundled version)"
    echo "   ✅ PHP 7.4 optimized for XtreamCodes"
    echo "   ✅ Enhanced MariaDB configuration"
    echo "   ✅ Advanced system optimization"
    echo "   ✅ Comprehensive monitoring scripts"
    echo "   ✅ Automatic service management"
    echo "   ✅ Security enhancements and rate limiting"
    echo "   ✅ Full tmpfs optimization"
    echo ""
    echo "📁 IMPORTANT FILES:"
    echo "   Installation Info: $INSTALL_INFO_FILE"
    echo "   Installation Log: $LOG_FILE"
    echo "   Nginx Config: /etc/nginx/nginx.conf"
    echo "   PHP-FPM Pool: /etc/php/7.4/fpm/pool.d/xtreamcodes.conf"
    echo "   MariaDB Config: /etc/mysql/mariadb.cnf"
    echo ""
    echo "🔗 REPOSITORY: $GITHUB_URL"
    echo "📝 VERSION: Stefan Enhanced v$SCRIPT_VERSION"
    echo ""
    
    if [ $installation_success -eq 0 ]; then
        echo "🎉 Congratulations! Your XtreamCodes Enhanced server is ready!"
        echo "🌐 Access your admin panel: http://$SERVER_IP:$ADMIN_PORT"
    else
        echo "⚠️  Installation completed but some services may need attention."
        echo "🔧 Run: /home/xtreamcodes/iptv_xtream_codes/check_status.sh"
        echo "🔄 Try: /home/xtreamcodes/iptv_xtream_codes/restart_services.sh"
    fi
    
    echo ""
    echo "🙏 Thank you for using Stefan's Enhanced XtreamCodes Installer v$SCRIPT_VERSION!"
    echo ""
    
    # Save installation info to file
    cat > "$INSTALL_INFO_FILE" << EOF
┌─────────────────── XtreamCodes Stefan Enhanced Installation v$SCRIPT_VERSION ───────────────────┐
│
│ INSTALLATION COMPLETED: $(date)
│ VERSION: Stefan Enhanced v$SCRIPT_VERSION - Modular Design
│
│ ADMIN ACCESS:
│ Panel URL: http://$SERVER_IP:$ADMIN_PORT
│ Username:  $ADMIN_USERNAME
│ Password:  $ADMIN_PASSWORD
│ Email:     $ADMIN_EMAIL
│
│ TECHNICAL DETAILS:
│ Client Port:          $CLIENT_PORT
│ Apache Port:          $APACHE_PORT
│ MySQL Port:           7999
│ MySQL Root Password:  $MYSQL_ROOT_PASSWORD
│ MySQL XC Password:    $XTREAM_DB_PASSWORD
│ Timezone:             $TIMEZONE
│ System:               $DETECTED_OS $DETECTED_VER ($DETECTED_ARCH)
│
│ INSTALLED VERSIONS:
│ Nginx:    $(nginx -v 2>&1 | cut -d' ' -f3)
│ PHP:      $(php7.4 -v | head -1 | cut -d' ' -f2)
│ MariaDB:  $(mysql --version | awk '{print $5}' | sed 's/,//')
│
│ MANAGEMENT COMMANDS:
│ Status Check: /home/xtreamcodes/iptv_xtream_codes/check_status.sh
│ Restart:      /home/xtreamcodes/iptv_xtream_codes/restart_services.sh
│ Start:        /home/xtreamcodes/iptv_xtream_codes/start_services.sh
│ Nginx Test:   nginx -t
│ Nginx Reload: systemctl reload nginx
│
│ ENHANCED FEATURES v$SCRIPT_VERSION:
│ ✓ Modular installer with advanced error handling
│ ✓ Real XtreamCodes archives from GitHub releases
│ ✓ Official Ubuntu Nginx (not bundled version)
│ ✓ PHP 7.4 optimized configuration
│ ✓ Enhanced MariaDB setup
│ ✓ Advanced system optimization
│ ✓ Comprehensive monitoring scripts
│ ✓ Automatic service management
│ ✓ Security enhancements
│ ✓ Full tmpfs optimization
│
│ Repository: $GITHUB_URL
│ Installation Log: $LOG_FILE
│
└──────────────────────────────────────────────────────────────────────────────────────┘
EOF

    print_success "Installation details saved to: $INSTALL_INFO_FILE"
    print_success "Installation log saved to: $LOG_FILE"
}

# =================== MAIN INSTALLATION FUNCTION ===================

main() {
    # Initialize logging
    touch "$LOG_FILE"
    log "XtreamCodes Enhanced Installer v$SCRIPT_VERSION started"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Show header
    clear
    echo ""
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│            XtreamCodes Enhanced Installer v$SCRIPT_VERSION - Stefan Edition       │${NC}"
    echo -e "${CYAN}│                     Modular Design with Real Archives              │${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${WHITE}🚀 Repository: $GITHUB_URL${NC}"
    echo ""
    echo -e "${GREEN}✨ Enhanced Features v$SCRIPT_VERSION:${NC}"
    echo "   • Modular installer design with advanced error handling"
    echo "   • Real XtreamCodes archives from GitHub releases"
    echo "   • Official Ubuntu Nginx (not bundled version)"
    echo "   • PHP 7.4 with optimized configuration"
    echo "   • Enhanced MariaDB setup and optimization"
    echo "   • Advanced monitoring and management scripts"
    echo "   • Automatic system optimization"
    echo "   • Full compatibility with Ubuntu 18.04/20.04/22.04"
    echo ""
    
    # Installation steps
    detect_system
    check_prerequisites
    get_server_info
    get_user_input
    
    print_header "Starting Installation Process"
    
    prepare_system
    install_dependencies
    create_xtream_user
    
    install_mariadb
    configure_mariadb
    
    install_php
    configure_php
    
    install_nginx
    configure_nginx
    
    download_xtreamcodes
    extract_xtreamcodes
    
    configure_database
    create_admin_user
    create_config_file
    
    configure_system_limits
    configure_tmpfs
    
    create_management_scripts
    configure_services
    
    start_services
    
    # Verify installation
    local verification_result=0
    verify_installation || verification_result=1
    
    cleanup
    generate_final_report $verification_result
    
    log "XtreamCodes Enhanced Installer v$SCRIPT_VERSION completed"
    
    return $verification_result
}

# =================== SCRIPT EXECUTION ===================

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
