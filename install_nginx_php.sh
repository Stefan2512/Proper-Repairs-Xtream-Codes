#!/bin/bash
# Nginx + PHP 7.4 Installer pentru XtreamCodes
# Extras din scriptul dOC4eVER și optimizat pentru Ubuntu 20.04/22.04

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🚀 Nginx + PHP 7.4 Installer pentru XtreamCodes${NC}"
echo ""

# Root check
if [ $UID -ne 0 ]; then
    echo -e "${RED}❌ Trebuie să rulezi ca root: sudo -i${NC}"
    exit 1
fi

# Detect OS
if [ -f /etc/lsb-release ]; then
    OS=$(grep DISTRIB_ID /etc/lsb-release | sed 's/^.*=//')
    VER=$(grep DISTRIB_RELEASE /etc/lsb-release | sed 's/^.*=//')
elif [ -f /etc/os-release ]; then
    OS=$(grep -w ID /etc/os-release | sed 's/^.*=//')
    VER=$(grep VERSION_ID /etc/os-release | sed 's/^.*"\(.*\)"/\1/' | head -n 1)
else
    echo -e "${RED}❌ Nu pot detecta OS-ul${NC}"
    exit 1
fi

ARCH=$(uname -m)
echo -e "${BLUE}📋 Detectat: $OS $VER $ARCH${NC}"

# Check OS compatibility
if [[ "$OS" = "Ubuntu" && ("$VER" = "18.04" || "$VER" = "20.04" || "$VER" = "22.04") && "$ARCH" == "x86_64" ]]; then
    echo -e "${GREEN}✅ OS compatibil${NC}"
else
    echo -e "${RED}❌ Acest script suportă doar Ubuntu 18.04/20.04/22.04 x86_64${NC}"
    exit 1
fi

# Set package manager for Ubuntu/Debian
PACKAGE_INSTALLER="apt-get -yqq install"
PACKAGE_REMOVER="apt-get -yqq purge"

# Prepare system
echo -e "${YELLOW}🔧 Pregătind sistemul...${NC}"
DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND=noninteractive

# Disable needrestart prompts
if [ -f "/etc/apt/apt.conf.d/99needrestart" ]; then
    sed -i 's|DPkg::Post-Invoke|#DPkg::Post-Invoke|' "/etc/apt/apt.conf.d/99needrestart"
fi

# Update package lists
echo -e "${YELLOW}📦 Actualizez lista de pachete...${NC}"
apt-get -qq update

# Install basic tools
echo -e "${YELLOW}📦 Instalez utilitare de bază...${NC}"
$PACKAGE_INSTALLER curl wget unzip software-properties-common dnsutils net-tools

# Create xtreamcodes user if doesn't exist
echo -e "${YELLOW}👤 Creez utilizatorul xtreamcodes...${NC}"
if ! id "xtreamcodes" &>/dev/null; then
    adduser --system --shell /bin/false --group --disabled-login xtreamcodes
    mkdir -p /home/xtreamcodes/iptv_xtream_codes
    echo -e "${GREEN}✅ Utilizator xtreamcodes creat${NC}"
else
    echo -e "${GREEN}✅ Utilizatorul xtreamcodes există deja${NC}"
fi

# Remove existing nginx installations
echo -e "${YELLOW}🗑️  Înlătur instalările nginx existente...${NC}"
systemctl stop nginx 2>/dev/null || true
$PACKAGE_REMOVER nginx nginx-common nginx-core nginx-full 2>/dev/null || true
apt-get autoremove -y >/dev/null 2>&1

# Install official Nginx from Ubuntu repository
echo -e "${YELLOW}🌐 Instalez Nginx oficial din repository Ubuntu...${NC}"
$PACKAGE_INSTALLER nginx nginx-core nginx-common

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Nginx instalat cu succes${NC}"
    nginx -v
else
    echo -e "${RED}❌ Eșec la instalarea Nginx${NC}"
    exit 1
fi

# Stop and disable default nginx (we'll configure it manually)
systemctl stop nginx >/dev/null 2>&1
systemctl disable nginx >/dev/null 2>&1

# Install PHP 7.4 and required extensions for XtreamCodes
echo -e "${YELLOW}🐘 Instalez PHP 7.4 și extensiile necesare...${NC}"

# For Ubuntu 22.04, we might need to add PHP 7.4 repository
if [[ "$VER" = "22.04" ]]; then
    echo -e "${YELLOW}📦 Adaug repository PHP pentru Ubuntu 22.04...${NC}"
    add-apt-repository ppa:ondrej/php -y >/dev/null 2>&1
    apt-get -qq update
fi

# Install PHP 7.4 and extensions
$PACKAGE_INSTALLER \
    php7.4 \
    php7.4-fpm \
    php7.4-cli \
    php7.4-mysql \
    php7.4-curl \
    php7.4-gd \
    php7.4-json \
    php7.4-zip \
    php7.4-xml \
    php7.4-mbstring \
    php7.4-soap \
    php7.4-intl \
    php7.4-bcmath \
    php7.4-opcache \
    php7.4-common \
    php7.4-readline

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ PHP 7.4 instalat cu succes${NC}"
    php7.4 -v | head -1
else
    echo -e "${RED}❌ Eșec la instalarea PHP 7.4${NC}"
    exit 1
fi

# Configure PHP-FPM for XtreamCodes
echo -e "${YELLOW}🔧 Configurez PHP-FPM pentru XtreamCodes...${NC}"

# Backup original www.conf
if [ -f "/etc/php/7.4/fpm/pool.d/www.conf" ]; then
    cp /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/www.conf.backup
fi

# Create XtreamCodes PHP-FPM pool
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

; XtreamCodes specific settings
chdir = /home/xtreamcodes/iptv_xtream_codes
php_admin_value[upload_max_filesize] = 50M
php_admin_value[post_max_size] = 50M
php_admin_value[max_execution_time] = 300
php_admin_value[max_input_time] = 300
php_admin_value[memory_limit] = 512M
EOL

echo -e "${GREEN}✅ PHP-FPM pool XtreamCodes configurat${NC}"

# Configure PHP settings for XtreamCodes
echo -e "${YELLOW}🔧 Configurez setările PHP pentru XtreamCodes...${NC}"

# Update PHP-FPM main configuration
sed -i 's/^;emergency_restart_threshold = 0/emergency_restart_threshold = 10/' /etc/php/7.4/fpm/php-fpm.conf
sed -i 's/^;emergency_restart_interval = 0/emergency_restart_interval = 1m/' /etc/php/7.4/fpm/php-fpm.conf
sed -i 's/^;process_control_timeout = 0/process_control_timeout = 10s/' /etc/php/7.4/fpm/php-fpm.conf

# Create optimized nginx configuration for XtreamCodes
echo -e "${YELLOW}🌐 Configurez Nginx pentru XtreamCodes...${NC}"

# Backup original nginx config
if [ -f "/etc/nginx/nginx.conf" ]; then
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
fi

# Create XtreamCodes optimized nginx configuration
cat > /etc/nginx/nginx.conf << 'EOL'
user www-data;
worker_processes auto;
worker_rlimit_nofile 300000;
pid /run/nginx.pid;

events {
    worker_connections 16000;
    use epoll;
    accept_mutex on;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Performance settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    reset_timedout_connection on;
    keepalive_timeout 10;
    client_body_timeout 13s;
    client_header_timeout 13s;
    send_timeout 20m;
    sendfile_max_chunk 512k;
    lingering_close off;
    
    # Buffer settings
    client_max_body_size 3m;
    client_body_buffer_size 128k;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 4k;
    
    # Gzip settings
    gzip off;
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=one:30m rate=20r/s;
    
    # Hide nginx version
    server_tokens off;
    
    # Access log off for performance
    access_log off;
    
    # FastCGI settings
    fastcgi_read_timeout 200;
    fastcgi_buffers 96 32k;
    fastcgi_buffer_size 32k;
    fastcgi_max_temp_file_size 0;
    fastcgi_keep_conn on;
    
    # Upstream PHP-FPM
    upstream php {
        server unix:/run/php/php7.4-fpm-xtreamcodes.sock;
    }
    
    # Default server for XtreamCodes client access (port 5050)
    server {
        listen 5050 default_server;
        index index.php index.html index.htm;
        root /home/xtreamcodes/iptv_xtream_codes/wwwdir/;
        server_tokens off;
        chunked_transfer_encoding off;
        
        # Only allow GET and POST methods
        if ( $request_method !~ ^(GET|POST)$ ) {
            return 200;
        }
        
        # XtreamCodes URL rewrite rules
        rewrite ^/live/(.*)/(.*)/(.*)\.(.*)\$ /streaming/clients_live.php?username=$1&password=$2&stream=$3&extension=$4 break;
        rewrite ^/movie/(.*)/(.*)/(.*)\$ /streaming/clients_movie.php?username=$1&password=$2&stream=$3&type=movie break;
        rewrite ^/series/(.*)/(.*)/(.*)\$ /streaming/clients_movie.php?username=$1&password=$2&stream=$3&type=series break;
        rewrite ^/(.*)/(.*)/(.*).ch\$ /streaming/clients_live.php?username=$1&password=$2&stream=$3&extension=ts break;
        rewrite ^/(.*)\.ch\$ /streaming/clients_live.php?extension=ts&stream=$1&qs=$query_string break;
        rewrite ^/ch(.*)\.m3u8\$ /streaming/clients_live.php?extension=m3u8&stream=$1&qs=$query_string break;
        rewrite ^/hls/(.*)/(.*)/(.*)/(.*)/(.*)\$ /streaming/clients_live.php?extension=m3u8&username=$1&password=$2&stream=$3&type=hls&segment=$5&token=$4 break;
        rewrite ^/hlsr/(.*)/(.*)/(.*)/(.*)/(.*)/(.*)\$ /streaming/clients_live.php?token=$1&username=$2&password=$3&segment=$6&stream=$4&key_seg=$5 break;
        rewrite ^/timeshift/(.*)/(.*)/(.*)/(.*)/(.*)\.(.*)\$ /streaming/timeshift.php?username=$1&password=$2&stream=$5&extension=$6&duration=$3&start=$4 break;
        rewrite ^/timeshifts/(.*)/(.*)/(.*)/(.*)/(.*)\.(.*)\$ /streaming/timeshift.php?username=$1&password=$2&stream=$4&extension=$6&duration=$3&start=$5 break;
        rewrite ^/(.*)/(.*)/(\d+)\$ /streaming/clients_live.php?username=$1&password=$2&stream=$3&extension=ts break;
        
        # Stalker Portal support
        rewrite ^/server/load.php\$ /portal.php break;
        
        location /stalker_portal/c {
            alias /home/xtreamcodes/iptv_xtream_codes/wwwdir/c;
        }
        
        # FFmpeg Progress (localhost only)
        location = /progress.php {
            allow 127.0.0.1;
            deny all;
            fastcgi_pass php;
            include fastcgi_params;
            fastcgi_ignore_client_abort on;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param SCRIPT_NAME $fastcgi_script_name;
        }
        
        # PHP handler
        location ~ \.php$ {
            limit_req zone=one burst=8;
            try_files $uri =404;
            fastcgi_index index.php;
            fastcgi_pass php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param SCRIPT_NAME $fastcgi_script_name;
        }
    }
    
    # Admin Panel server (port 2086)
    server {
        listen 2086;
        index index.php index.html index.htm;
        root /home/xtreamcodes/iptv_xtream_codes/admin/;
        
        location ~ \.php$ {
            limit_req zone=one burst=8;
            try_files $uri =404;
            fastcgi_index index.php;
            fastcgi_pass php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param SCRIPT_NAME $fastcgi_script_name;
        }
    }
    
    # ISP Configuration (localhost only)
    server {
        listen 8805;
        root /home/xtreamcodes/iptv_xtream_codes/isp/;
        
        location / {
            allow 127.0.0.1;
            deny all;
        }
        
        location ~ \.php$ {
            limit_req zone=one burst=8;
            try_files $uri =404;
            fastcgi_index index.php;
            fastcgi_pass php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param SCRIPT_NAME $fastcgi_script_name;
        }
    }
}
EOL

echo -e "${GREEN}✅ Nginx configurat pentru XtreamCodes${NC}"

# Test nginx configuration
echo -e "${YELLOW}🔧 Testez configurația Nginx...${NC}"
nginx -t
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Configurația Nginx este validă${NC}"
else
    echo -e "${RED}❌ Eroare în configurația Nginx${NC}"
    exit 1
fi

# Set proper permissions for XtreamCodes
echo -e "${YELLOW}🔧 Configurez permisiunile...${NC}"
chown -R xtreamcodes:xtreamcodes /home/xtreamcodes/
chmod -R 755 /home/xtreamcodes/iptv_xtream_codes/

# Add xtreamcodes to sudoers for required commands
if ! grep -q "xtreamcodes ALL = (root) NOPASSWD: /sbin/iptables, /usr/bin/chattr, /usr/bin/python2, /usr/bin/python" /etc/sudoers; then
    echo "xtreamcodes ALL = (root) NOPASSWD: /sbin/iptables, /usr/bin/chattr, /usr/bin/python2, /usr/bin/python" >> /etc/sudoers
    echo -e "${GREEN}✅ Permisiuni sudo configurate pentru xtreamcodes${NC}"
fi

# Start and enable services
echo -e "${YELLOW}🚀 Pornesc serviciile...${NC}"

# Start PHP-FPM
systemctl start php7.4-fpm
systemctl enable php7.4-fpm
if systemctl is-active --quiet php7.4-fpm; then
    echo -e "${GREEN}✅ PHP-FPM pornit și activat${NC}"
else
    echo -e "${RED}❌ Eroare la pornirea PHP-FPM${NC}"
fi

# Start Nginx
systemctl start nginx
systemctl enable nginx
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ Nginx pornit și activat${NC}"
else
    echo -e "${RED}❌ Eroare la pornirea Nginx${NC}"
fi

# Check if PHP socket was created
if [ -S "/run/php/php7.4-fpm-xtreamcodes.sock" ]; then
    echo -e "${GREEN}✅ Socket PHP-FPM pentru XtreamCodes creat${NC}"
else
    echo -e "${RED}❌ Socket PHP-FPM pentru XtreamCodes nu a fost creat${NC}"
fi

# Create status check script
cat > /home/xtreamcodes/check_nginx_php.sh << 'STATUSEOF'
#!/bin/bash
# XtreamCodes Nginx + PHP Status Check

echo "=== XtreamCodes Nginx + PHP Status ==="
echo ""

# Check services
echo "Services Status:"
systemctl is-active nginx && echo "✅ Nginx: Running" || echo "❌ Nginx: Stopped"
systemctl is-active php7.4-fpm && echo "✅ PHP-FPM: Running" || echo "❌ PHP-FPM: Stopped"

echo ""

# Check sockets
echo "Sockets:"
[ -S "/run/php/php7.4-fpm-xtreamcodes.sock" ] && echo "✅ XtreamCodes PHP Socket: Present" || echo "❌ XtreamCodes PHP Socket: Missing"

echo ""

# Check ports
echo "Listening Ports:"
netstat -tlnp 2>/dev/null | grep ":2086 " >/dev/null && echo "✅ Admin Panel (2086): Listening" || echo "❌ Admin Panel (2086): Not listening"
netstat -tlnp 2>/dev/null | grep ":5050 " >/dev/null && echo "✅ Client Access (5050): Listening" || echo "❌ Client Access (5050): Not listening"
netstat -tlnp 2>/dev/null | grep ":8805 " >/dev/null && echo "✅ ISP Config (8805): Listening" || echo "❌ ISP Config (8805): Not listening"

echo ""

# Check PHP version
echo "PHP Version:"
php7.4 -v | head -1

echo ""

# Check Nginx version
echo "Nginx Version:"
nginx -v

echo ""
echo "Configuration files:"
echo "Nginx config: /etc/nginx/nginx.conf"
echo "PHP-FPM XtreamCodes pool: /etc/php/7.4/fpm/pool.d/xtreamcodes.conf"
STATUSEOF

chmod +x /home/xtreamcodes/check_nginx_php.sh

# Create service restart script
cat > /home/xtreamcodes/restart_nginx_php.sh << 'RESTARTEOF'
#!/bin/bash
# XtreamCodes Nginx + PHP Restart Script

echo "🔄 Restarting XtreamCodes Nginx + PHP services..."

# Stop services
echo "Stopping services..."
systemctl stop nginx
systemctl stop php7.4-fpm

sleep 2

# Start services
echo "Starting services..."
systemctl start php7.4-fpm
sleep 1
systemctl start nginx

sleep 2

# Check status
echo ""
echo "Service status:"
systemctl is-active php7.4-fpm && echo "✅ PHP-FPM: Running" || echo "❌ PHP-FPM: Failed"
systemctl is-active nginx && echo "✅ Nginx: Running" || echo "❌ Nginx: Failed"

echo ""
echo "✅ Restart completed!"
RESTARTEOF

chmod +x /home/xtreamcodes/restart_nginx_php.sh

# Final status check
echo ""
echo -e "${GREEN}🎉 Instalarea Nginx + PHP 7.4 pentru XtreamCodes completă!${NC}"
echo ""
echo -e "${YELLOW}📋 Sumar instalare:${NC}"
echo -e "OS: $OS $VER $ARCH"
echo -e "Nginx: $(nginx -v 2>&1 | cut -d' ' -f3)"
echo -e "PHP: $(php7.4 -v | head -1 | cut -d' ' -f2)"
echo ""
echo -e "${YELLOW}🔧 Configurări:${NC}"
echo -e "Admin Panel Port: 2086"
echo -e "Client Access Port: 5050"
echo -e "ISP Config Port: 8805"
echo -e "PHP-FPM Socket: /run/php/php7.4-fpm-xtreamcodes.sock"
echo ""
echo -e "${YELLOW}🛠️  Script-uri utile:${NC}"
echo -e "Status check: /home/xtreamcodes/check_nginx_php.sh"
echo -e "Restart services: /home/xtreamcodes/restart_nginx_php.sh"
echo ""
echo -e "${YELLOW}📁 Directoare:${NC}"
echo -e "XtreamCodes root: /home/xtreamcodes/iptv_xtream_codes/"
echo -e "Admin files: /home/xtreamcodes/iptv_xtream_codes/admin/"
echo -e "WWW files: /home/xtreamcodes/iptv_xtream_codes/wwwdir/"
echo ""
echo -e "${GREEN}✅ Nginx și PHP 7.4 sunt gata pentru XtreamCodes!${NC}"

# Run status check
echo ""
echo -e "${BLUE}📊 Status final:${NC}"
/home/xtreamcodes/check_nginx_php.sh
