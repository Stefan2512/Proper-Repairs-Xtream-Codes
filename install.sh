#!/usr/bin/env bash
#
# ==============================================================================
# Xtream Codes "Proper Repairs" - Instalator modernizat și sigur v3.0
# ==============================================================================
# Creat de: Gemini AI (pe baza scriptului original de Stefan2512)
# Data: 2024-05-17
#
# ÎMBUNĂTĂȚIRI CHEIE:
# - Complet rescris pentru a fi sigur, robust și compatibil cu Ubuntu 18/20/22.
# - Cere confirmare explicită înainte de a șterge baze de date existente.
# - Folosește Python 3 (standard pe Ubuntu modern), eliminând eroarea de compatibilitate.
# - Descarcă arhiva direct din pagina de "Releases" a proiectului.
# - Verificări stricte pentru fiecare pas și gestionare îmbunătățită a erorilor.
# - Securitate sporită (permisiuni limitate pentru userul DB).
# ==============================================================================

# Oprește scriptul la orice eroare pentru a preveni instalări incomplete
set -euo pipefail

# --- Variabile și Constante ---
readonly RELEASE_URL="https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/releases/download/v1.0/main_panel.zip"
readonly PANEL_ZIP_NAME="main_panel.zip"
readonly XC_USER="xtreamcodes"
readonly XC_HOME="/home/${XC_USER}"
readonly XC_PANEL_DIR="${XC_HOME}/iptv_xtream_codes"
readonly LOG_DIR="/var/log/xtreamcodes"

# --- Funcții de Logging ---
# Asigură crearea directorului de log la început
mkdir -p "$LOG_DIR"
readonly LOGFILE="$LOG_DIR/install_$(date +%Y-%m-%d_%H-%M-%S).log"
touch "$LOGFILE"

log() { local level=$1; shift; local message="$@"; printf "[%s] %s: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message" | tee -a "$LOGFILE"; }
log_step() { echo; log "PAS" "================= $1 ================="; }
log_info() { log "INFO" "$1"; }
log_success() { log "SUCCES" "✅ $1"; }
log_error() { log "EROARE" "❌ $1"; exit 1; }
log_warning() { log "AVERTISMENT" "⚠️ $1"; }

# --- Funcția de Curățare la Ieșire ---
trap cleanup EXIT
cleanup() {
  rm -f "/tmp/${PANEL_ZIP_NAME}"
  log_info "Fișierele temporare au fost șterse."
}

# ==============================================================================
# STARTUL SCRIPTULUI
# ==============================================================================

clear
cat << "EOF"
┌───────────────────────────────────────────────────────────────────┐
│  Instalator modernizat și sigur pentru Xtream Codes "Proper Repairs"  │
│                           Versiunea 3.0                           │
└───────────────────────────────────────────────────────────────────┘
> Acest script va instala și configura panoul Xtream Codes, MariaDB,
> Nginx și PHP pe serverul dumneavoastră.
> Repository original: https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes
EOF
echo

# --- 1. Verificări Inițiale ---
log_step "Verificări inițiale de sistem"

if [[ $EUID -ne 0 ]]; then
   log_error "Acest script trebuie rulat cu privilegii de root. Încercați 'sudo ./install.sh'"
fi

if ! ping -c 1 -W 2 google.com &>/dev/null; then
    log_warning "Nu am putut detecta o conexiune la internet. Instalarea poate eșua."
    sleep 5
fi

OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
OS_VER=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')
ARCH=$(uname -m)

log_info "Sistem detectat: ${OS_ID^} $OS_VER ($ARCH)"

if [[ "$OS_ID" != "ubuntu" || ! "$OS_VER" =~ ^(18\.04|20\.04|22\.04)$ || "$ARCH" != "x86_64" ]]; then
    log_error "Acest script este compatibil doar cu Ubuntu 18.04, 20.04, 22.04 (64-bit)."
fi

log_success "Verificările inițiale au trecut."

# --- 2. Confirmarea Utilizatorului ---
log_step "Confirmare instalare"
cat << "CONFIRM_MSG"

AVERTISMENT IMPORTANT:
Acest script va instala pachete software și va configura sistemul.
Dacă detectează o instalare existentă de MySQL sau MariaDB, vă va întreba
dacă doriți să o ȘTERGEȚI COMPLET pentru a continua.

Asigurați-vă că rulați acest script pe un server nou sau că aveți backup la date!

CONFIRM_MSG

read -rp "Scrieți 'DA' pentru a continua: " response
if [[ "${response}" != "DA" ]]; then
    log_error "Instalare anulată de utilizator."
fi

# --- 3. Setarea Variabilelor ---
log_step "Setarea variabilelor de instalare"

# Generează parole sigure
PASSMYSQL=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
XPASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)

# Date de autentificare pentru panou
ADMIN_USER="admin"
ADMIN_PASS="admin$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)" # Parolă admin mai sigură
ADMIN_EMAIL="admin@example.com"
ACCESSPORT=2086

log_info "Variabilele au fost setate."

# --- 4. Pregătirea Sistemului și Dependențe ---
log_step "Instalare dependențe de sistem"
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq

log_info "Instalare pachete de bază..."
apt-get install -yqq curl wget unzip zip software-properties-common apt-transport-https ca-certificates gnupg python3 &>> "$LOGFILE"
log_success "Pachetele de bază au fost instalate."

log_info "Instalare PHP..."
# Pentru Ubuntu 22.04, adăugăm PPA pentru PHP 7.4
if [[ "$OS_VER" == "22.04" ]]; then
    log_info "Se adaugă PPA pentru PHP 7.4 pe Ubuntu 22.04..."
    add-apt-repository -y ppa:ondrej/php &>> "$LOGFILE"
    apt-get update -qq
fi

# Încercăm să instalăm PHP 7.4, dacă nu reușește, folosim PHP-ul default al sistemului
if apt-get install -yqq php7.4{,-fpm,-cli,-mysql,-curl,-gd,-json,-zip,-xml,-mbstring,-soap,-intl,-bcmath} &>> "$LOGFILE"; then
    PHP_VERSION="7.4"
    PHP_SOCK="/run/php/php7.4-fpm.sock"
else
    log_warning "PHP 7.4 nu a putut fi instalat. Se încearcă instalarea versiunii de PHP implicite a sistemului..."
    apt-get install -yqq php{,-fpm,-cli,-mysql,-curl,-gd,-json,-zip,-xml,-mbstring,-soap,-intl,-bcmath} &>> "$LOGFILE"
    # Detectează versiunea instalată
    PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    PHP_SOCK="/run/php/php${PHP_VERSION}-fpm.sock"
fi
log_success "PHP versiunea $PHP_VERSION a fost instalat."

log_info "Instalare Nginx și alte librării..."
apt-get install -yqq nginx libzip-dev libonig-dev &>> "$LOGFILE"
# Fix pentru libzip pe sisteme mai noi
if [ ! -f "/usr/lib/x86_64-linux-gnu/libzip.so.4" ] && [ -f "/usr/lib/x86_64-linux-gnu/libzip.so.5" ]; then
    ln -s /usr/lib/x86_64-linux-gnu/libzip.so.5 /usr/lib/x86_64-linux-gnu/libzip.so.4
    log_info "Creat symlink pentru compatibilitatea libzip."
fi
ldconfig
log_success "Dependențele au fost instalate."

# --- 5. Instalare și Configurare MariaDB ---
log_step "Instalare și configurare MariaDB"

# Verificare sigură pentru instalări existente
if systemctl list-units --type=service --state=active | grep -q 'mysql\|mariadb'; then
    log_warning "Am detectat un serviciu MySQL/MariaDB activ."
    read -rp "Pentru a continua, instalarea existentă va fi ȘTEARSĂ COMPLET. Scrieți 'DA' pentru a confirma: " db_confirm
    if [[ "$db_confirm" != "DA" ]]; then
        log_error "Instalare anulată. Baza de date existentă nu a fost atinsă."
    fi
    
    log_info "Se oprește și se șterge instalarea existentă de MySQL/MariaDB..."
    systemctl stop mariadb mysql || true
    systemctl disable mariadb mysql || true
    apt-get -y purge 'mysql-.*' 'mariadb-.*' &>> "$LOGFILE"
    apt-get -y autoremove &>> "$LOGFILE"
    apt-get -y autoclean &>> "$LOGFILE"
    rm -rf /etc/mysql /var/lib/mysql /var/log/mysql
    log_success "Curățarea a fost finalizată."
fi

log_info "Instalare MariaDB Server..."
debconf-set-selections <<< "mariadb-server mysql-server/root_password password $PASSMYSQL"
debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password $PASSMYSQL"
apt-get install -yqq mariadb-server &>> "$LOGFILE"

# Configurare bazică și sigură
cat > /etc/mysql/mariadb.conf.d/99-xtreamcodes.cnf <<EOF
[mysqld]
bind-address = 127.0.0.1
skip-name-resolve
EOF

systemctl restart mariadb
systemctl enable mariadb

if ! systemctl is-active --quiet mariadb; then
    log_error "Serviciul MariaDB nu a putut porni. Verificați logurile."
fi

log_info "Securizarea instalării MariaDB..."
mysql -u root -p"$PASSMYSQL" -e "UPDATE mysql.user SET Password=PASSWORD('$PASSMYSQL') WHERE User='root';"
mysql -u root -p"$PASSMYSQL" -e "DELETE FROM mysql.user WHERE User='';"
mysql -u root -p"$PASSMYSQL" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -u root -p"$PASSMYSQL" -e "DROP DATABASE IF EXISTS test;"
mysql -u root -p"$PASSMYSQL" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -u root -p"$PASSMYSQL" -e "FLUSH PRIVILEGES;"
log_success "MariaDB a fost instalat și securizat."

# --- 6. Creare User și Bază de Date ---
log_step "Creare utilizator de sistem și bază de date"

if id "$XC_USER" &>/dev/null; then
    log_info "Utilizatorul de sistem '$XC_USER' există deja."
else
    adduser --system --shell /bin/false --group --disabled-login "$XC_USER"
    log_success "Utilizatorul de sistem '$XC_USER' a fost creat."
fi

log_info "Se creează baza de date 'xtream_iptvpro'..."
mysql -u root -p"$PASSMYSQL" -e "CREATE DATABASE xtream_iptvpro;"
# Permisiuni sigure: doar pe baza de date necesară
mysql -u root -p"$PASSMYSQL" -e "GRANT ALL PRIVILEGES ON xtream_iptvpro.* TO 'user_iptvpro'@'localhost' IDENTIFIED BY '$XPASS';"
mysql -u root -p"$PASSMYSQL" -e "FLUSH PRIVILEGES;"
log_success "Baza de date și utilizatorul au fost create cu succes."

# --- 7. Descărcare și Instalare Panou ---
log_step "Descărcare și instalare fișiere panou"

log_info "Se descarcă arhiva panoului de pe GitHub Releases..."
wget -q -O "/tmp/${PANEL_ZIP_NAME}" "$RELEASE_URL"
if [[ $? -ne 0 ]]; then
    log_error "Descărcarea arhivei panoului a eșuat. Verificați URL-ul și conexiunea la internet."
fi

mkdir -p "$XC_PANEL_DIR"
log_info "Se dezarhivează panoul în $XC_PANEL_DIR..."
unzip -o -q "/tmp/${PANEL_ZIP_NAME}" -d "$XC_PANEL_DIR"

# Mută fișierele din subdirectorul `main_panel` în rădăcina directorului de instalare
if [ -d "${XC_PANEL_DIR}/main_panel" ]; then
    mv ${XC_PANEL_DIR}/main_panel/* ${XC_PANEL_DIR}/
    rm -rf "${XC_PANEL_DIR}/main_panel"
fi

log_info "Se importă baza de date din fișierul SQL..."
if [ -f "${XC_PANEL_DIR}/SQL/database.sql" ]; then
    mysql -u root -p"$PASSMYSQL" xtream_iptvpro < "${XC_PANEL_DIR}/SQL/database.sql"
else
    log_error "Fișierul database.sql nu a fost găsit în arhiva descărcată."
fi

# Actualizează datele în baza de date
log_info "Se actualizează setările în baza de date..."
Padmin=$(perl -e 'print crypt($ARGV[0], "$6$rounds=5000$xtreamcodes")' "$ADMIN_PASS")
mysql -u root -p"$PASSMYSQL" xtream_iptvpro -e "UPDATE reg_users SET username = '$ADMIN_USER', password = '$Padmin', email = '$ADMIN_EMAIL' WHERE id = 1;"
mysql -u root -p"$PASSMYSQL" xtream_iptvpro -e "UPDATE streaming_servers SET server_ip='127.0.0.1' WHERE id=1;"

log_success "Panoul a fost instalat și baza de date importată."

# --- 8. Generare Configurație și Setare Permisiuni ---
log_step "Generare fișier de configurare și setare permisiuni"

log_info "Se generează fișierul de configurare config (compatibil Python 3)..."
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
    log_error "Generarea fișierului config a eșuat."
fi

log_info "Se setează permisiunile corecte pentru fișiere..."
chown -R "$XC_USER":"$XC_USER" "$XC_HOME"
chmod -R 777 "${XC_PANEL_DIR}/streams" "${XC_PANEL_DIR}/tmp" "${XC_PANEL_DIR}/logs"

log_success "Configurația și permisiunile au fost setate."

# --- 9. Configurare Servicii (PHP-FPM & Nginx) ---
log_step "Configurare PHP-FPM și Nginx"

# Configurare PHP-FPM Pool
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

# Configurare Nginx
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

    # Blochează accesul la fișierele sensibile
    location ~ /\.ht {
        deny all;
    }
}
EOF

# Activare site Nginx
ln -s -f /etc/nginx/sites-available/xtreamcodes.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Verifică configurația Nginx înainte de a reporni
if ! nginx -t; then
    log_error "Configurația Nginx este invalidă. Vă rugăm verificați fișierul /etc/nginx/sites-available/xtreamcodes.conf"
fi

log_info "Se repornesc serviciile..."
systemctl restart "php${PHP_VERSION}-fpm"
systemctl enable "php${PHP_VERSION}-fpm"
systemctl restart nginx
systemctl enable nginx

log_success "PHP-FPM și Nginx au fost configurate și repornite."

# --- 10. Finalizare ---
log_step "Instalare finalizată!"

# Afișează adresa IP a serverului
IP_ADDR=$(hostname -I | awk '{print $1}')

cat << FINAL_MSG

Felicitări! Panoul Xtream Codes a fost instalat cu succes.

Puteți accesa panoul de administrare la adresa:
URL: http://${IP_ADDR}:${ACCESSPORT}

Date de autentificare:
Utilizator: ${ADMIN_USER}
Parola:     ${ADMIN_PASS}

AVERTISMENT DE SECURITATE:
- Salvați această parolă într-un loc sigur.
- Se recomandă să ștergeți istoricul comenzilor ('history -c') pentru a elimina urmele parolelor.

FINAL_MSG

exit 0
