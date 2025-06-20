#!/usr/bin/env bash
#
# ==============================================================================
# Xtream Codes "Proper Repairs" - Installer v1.1 Stefan2512 Edition
# ==============================================================================
# Created by: Stefan2512
# Date: 2025-06-20
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
readonly XC_HOME="/home/<span class="math-inline">\{XC\_USER\}"
readonly XC\_PANEL\_DIR\="</span>{XC_HOME}/iptv_xtream_codes"
readonly LOG_DIR="/var/log/xtreamcodes"

# --- Logging Functions ---
mkdir -p "$LOG_DIR"
readonly LOGFILE="<span class="math-inline">LOG\_DIR/install\_</span>(date +%Y-%m-%d_%H-%M-%S).log"
touch "$LOGFILE"

log() { local level=<span class="math-inline">1; shift; local message\="</span>@"; printf "[%s] %s: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message" | tee -a "$LOGFILE"; }
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

if [[ <span class="math-inline">EUID \-ne 0 \]\]; then
log\_error "This script must be run as root\. Try 'sudo \./install\.sh'"
fi
if \! ping \-c 1 \-W 2 google\.com &\>/dev/null; then
log\_warning "Could not detect an internet connection\. Installation may fail\."
sleep 3
fi
OS\_ID\=</span>(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
OS_VER=<span class="math-inline">\(grep \-oP '\(?<\=^VERSION\_ID\=\)\.\+' /etc/os\-release \| tr \-d '"'\)
ARCH\=</span>(uname -m)

log_info "Detected system: ${OS_ID^} $OS_VER ($ARCH)"

if [[ "$OS_ID" != "ubuntu" || ! "<span class="math-inline">OS\_VER" \=\~ ^\(18\\\.04\|20\\\.04\|22\\\.04\)</span> || "$ARCH" != "x86_64" ]]; then
    log_error "This script is only compatible with Ubuntu 18.04, 20.04, 22.04 (64-bit)."
fi

log_success "Initial checks
