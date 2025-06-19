# XtreamCodes Enhanced - Stefan Edition v1.1

## 🚀 Complete Fix Package for Ubuntu 18.04/20.04/22.04

### Enhanced XtreamCodes installation with ALL critical fixes + Official Nginx + GitHub Database!

This repository contains the **complete enhanced version** of XtreamCodes with all dependency fixes, performance optimizations, critical patches, and modern infrastructure integrated.

---

## ✅ **What's New in v1.1:**

### 🆕 **Major Enhancements:**
- ✅ **Official Ubuntu Nginx** - No more old bundled nginx!
- ✅ **GitHub Database Download** - Dynamic database.sql from repository
- ✅ **PHP 7.4 Optimized** - Complete FPM configuration for XtreamCodes
- ✅ **Basic Admin Panel** - Ready-to-use management interface
- ✅ **Advanced Management Scripts** - Status check, restart, monitoring
- ✅ **Safe Uninstaller** - Complete backup and removal tool

### 🔧 **Critical Fixes Included:**
- ✅ **libzip.so.4 compatibility** - Automatic symlink creation
- ✅ **PHP-FPM socket issues** - Enhanced error handling and retry logic  
- ✅ **Dependency management** - All required libraries included
- ✅ **Permission fixes** - Proper ownership and permissions set automatically
- ✅ **MySQL/MariaDB optimization** - Optimized configuration included

### ⚡ **Performance Enhancements:**
- ✅ **Enhanced nginx configuration** - Rate limiting and security headers
- ✅ **System optimizations** - Kernel parameters and limits optimized
- ✅ **tmpfs support** - High-performance temporary file storage
- ✅ **Load balancing** - Enhanced upstream configuration

### 🛠 **Management Tools:**
- ✅ **Status checker** - Monitor service health with colors
- ✅ **Quick restart** - Restart services safely  
- ✅ **Auto-start** - SystemD service + cron backup
- ✅ **Safe uninstaller** - Complete backup before removal

---

## 📦 **Quick Installation**

### **One-Line Install (Recommended):**
```bash
curl -L https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/raw/master/install.sh | bash
```

### **Silent Installation:**
```bash
curl -L https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/raw/master/install.sh | bash -s -- \
  -a admin \
  -t Europe/Paris \
  -p adminpass \
  -o 2086 \
  -c 5050 \
  -r 3672 \
  -e admin@example.com \
  -m mysqlpass \
  -s yes
```

### **Download & Run:**
```bash
wget https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/raw/master/install.sh -O /tmp/install.sh
bash /tmp/install.sh
```

---

## 🗑️ **Safe Uninstallation**

### **Interactive Uninstaller (Recommended):**
```bash
curl -L https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/raw/master/uninstall.sh | bash
```

### **Complete Removal (all packages):**
```bash
curl -L https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/raw/master/uninstall.sh | bash -s -- -f
```

### **Cleanup Only (keep nginx, php, mariadb):**
```bash
curl -L https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/raw/master/uninstall.sh | bash -s -- -f -k
```

**🛡️ Features:**
- 💾 **Complete backup** before removal (database + files)
- 📁 **Safe storage** in `/root/xtreamcodes_backup_YYYYMMDD/`
- 📋 **Restore instructions** included automatically
- 🔧 **Choose what to keep** (packages vs complete removal)

---

## 🎯 **Installation Options**

### **Command Line Parameters:**
- `-a` : Admin username
- `-t` : Timezone (e.g., Europe/Paris)  
- `-p` : Admin password
- `-o` : Admin panel port (default: 2086)
- `-c` : Client access port (default: 5050)
- `-r` : Apache access port (default: 3672)
- `-e` : Admin email
- `-m` : MySQL root password
- `-s yes` : Silent install (no prompts)
- `-h` : Show help

### **Example with custom ports:**
```bash
curl -L https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/raw/master/install.sh | bash -s -- \
  -a stefan \
  -p mypassword \
  -o 9091 \
  -c 8080 \
  -r 85 \
  -e stefan@example.com \
  -m mysqlpass123 \
  -s yes
```

### **Uninstaller Options:**
- `-f` : Force mode (no confirmations)
- `-k` : Keep packages (nginx, php, mariadb)
- `-h` : Show help

---

## 🔧 **Post-Installation Management**

### **Status Check:**
```bash
/home/xtreamcodes/iptv_xtream_codes/check_status.sh
```

### **Restart Services:**
```bash
/home/xtreamcodes/iptv_xtream_codes/restart_services.sh
```

### **Manual Service Control:**
```bash
# Start services
/home/xtreamcodes/iptv_xtream_codes/start_services.sh

# Check nginx configuration
nginx -t

# Reload nginx
systemctl reload nginx

# Check if services are running
ps aux | grep -E "(nginx|php7.4-fpm)" | grep -v grep
```

### **🆕 v1.1 Enhanced Scripts:**
- ✅ **Colored output** for better readability
- ✅ **Service health monitoring** with process counts
- ✅ **Port status checking** with netstat
- ✅ **Resource monitoring** (memory, disk, load)
- ✅ **Quick commands** reference built-in

---

## 📋 **System Requirements**

- **Operating System:** Ubuntu 18.04/20.04/22.04 LTS (64-bit)
- **RAM:** Minimum 2GB (4GB+ recommended)  
- **Storage:** 10GB+ free space
- **Network:** Internet connection for installation
- **Privileges:** Root access required
- **🆕 Clean server:** No existing control panels (cPanel, DirectAdmin)

---

## 🆘 **Troubleshooting**

### **Common Issues FIXED Automatically:**
- ❌ **502 Bad Gateway** → ✅ PHP-FPM socket creation fixed
- ❌ **libzip.so.4 missing** → ✅ Automatic symlink creation  
- ❌ **Permission denied** → ✅ Enhanced permission management
- ❌ **Services not starting** → ✅ Dependency verification and installation
- ❌ **Old nginx issues** → ✅ Official Ubuntu nginx with optimized config

### **If Issues Persist:**
1. **Check status:** `/home/xtreamcodes/iptv_xtream_codes/check_status.sh`
2. **Test nginx:** `nginx -t`
3. **View logs:** `tail -f /var/log/nginx/error.log`
4. **Restart services:** `/home/xtreamcodes/iptv_xtream_codes/restart_services.sh`
5. **Check PHP socket:** `ls -la /run/php/php7.4-fpm-xtreamcodes.sock`

### **🆕 Advanced Debugging:**
```bash
# Check all XtreamCodes processes
ps aux | grep -E "(nginx|php|mysql)" | grep -v grep

# Check listening ports
netstat -tlnp | grep -E "(2086|5050|7999)"

# Check tmpfs mounts
df -h | grep tmpfs

# View installation log
ls -la /root/*stefan_installer*.log
```

---

## 📂 **Repository Contents**

### **Main Files:**
- `install.sh` - 🆕 Enhanced installer v1.1 with official nginx
- `uninstall.sh` - 🆕 Safe uninstaller with complete backup
- `database.sql` - 🆕 Latest database schema
- `start_services.sh` - Service startup script  
- `balancer.php` - Load balancer script
- `balancer.sh` - Balancer helper script

### **🆕 Enhanced Management Scripts:**
- `check_status.sh` - Comprehensive status monitoring
- `restart_services.sh` - Safe service restart
- Multiple configuration templates
- Backup and restore utilities

### **Release Archives:**
- `xtreamcodes_enhanced_Ubuntu_18.04.tar.gz`
- `xtreamcodes_enhanced_Ubuntu_20.04.tar.gz`  
- `xtreamcodes_enhanced_Ubuntu_22.04.tar.gz`
- `xtreamcodes_enhanced_universal.tar.gz`
- `enhanced_updates.zip`
- `GeoLite2.mmdb`

---

## 📊 **What Makes This Enhanced?**

### **Compared to Original:**
| Feature | Original | Stefan Enhanced v1.1 |
|---------|----------|----------------------|
| Nginx | ❌ Old bundled version | ✅ Official Ubuntu nginx |
| Database | ❌ Hardcoded in script | ✅ Dynamic GitHub download |
| PHP-FPM | ❌ Often fails | ✅ Optimized 7.4 configuration |
| libzip.so.4 fix | ❌ Manual | ✅ Automatic |
| Dependencies | ❌ Missing packages | ✅ All included |
| Error handling | ❌ Basic | ✅ Advanced retry logic |
| Management tools | ❌ None | ✅ Advanced status & control |
| Performance | ❌ Default | ✅ Optimized config |
| Uninstaller | ❌ None | ✅ Safe backup & removal |
| Admin Panel | ❌ None | ✅ Basic functional interface |

---

## 🔄 **Updates & Support**

### **Getting Updates:**
This enhanced version includes automatic update mechanisms for:
- GeoIP database updates
- Security patches  
- Performance optimizations
- 🆕 Database schema updates from GitHub

### **Support:**
- **Issues:** [GitHub Issues](https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/issues)
- **Documentation:** Check this README and release notes
- **Community:** XtreamCodes community forums
- **🆕 Enhanced logging:** Detailed installation and error logs

---

## 📝 **Changelog**

### **v1.1 - Stefan Enhanced Release (Official Nginx + GitHub DB)**
- 🆕 **Official Ubuntu Nginx** instead of bundled version
- 🆕 **Database.sql download** from GitHub repository  
- 🆕 **PHP 7.4 optimized** configuration
- 🆕 **Safe uninstaller** with complete backup
- 🆕 **Basic admin panel** and API endpoints
- 🆕 **Advanced management scripts** with colored output
- 🆕 **Enhanced error handling** and recovery
- ✅ Comprehensive system optimization
- ✅ Rate limiting and security headers in nginx
- ✅ SystemD service integration

### **v1.0 - Stefan Enhanced Release**
- ✅ Complete rewrite of installation process
- ✅ All critical fixes integrated  
- ✅ Enhanced error handling and recovery
- ✅ Performance optimizations included
- ✅ Management tools added
- ✅ Comprehensive testing on Ubuntu 18.04/20.04/22.04

---

## ⚖️ **License**

This enhanced version maintains compatibility with original XtreamCodes licensing while adding critical fixes and improvements for the community.

---

## 👥 **Credits**

- **Stefan2512** - Enhanced integration, fixes, v1.1 improvements, and repository maintenance
- **Original XtreamCodes** - Base IPTV panel system  
- **dOC4eVER** - Initial fixes and patches foundation
- **Community** - Testing, feedback, and support
- **Ubuntu Team** - Official nginx packages
- **GitHub** - Dynamic database hosting

---

## 🌟 **Why Choose Stefan Enhanced v1.1?**

✅ **Modern Infrastructure:** Official Ubuntu nginx instead of old bundled version  
✅ **Dynamic Updates:** Database downloaded from GitHub repository  
✅ **Reliability:** All common issues fixed automatically  
✅ **Performance:** Optimized for high-load scenarios with rate limiting  
✅ **Maintenance:** Advanced management tools with colored output  
✅ **Safety:** Complete backup system before any changes  
✅ **Support:** Active community and enhanced documentation  
✅ **Updates:** Regular enhancements and security patches  

---

## 🛡️ **Security Features**

### **🆕 Enhanced Security in v1.1:**
- ✅ **Rate limiting** in nginx configuration
- ✅ **Security headers** (X-Frame-Options, X-XSS-Protection, etc.)
- ✅ **Process isolation** with dedicated PHP-FPM pools
- ✅ **Safe permissions** with proper user separation
- ✅ **Backup encryption** with restricted access (600/700)

---

## 🚀 **Quick Start Guide**

### **1. Fresh Installation:**
```bash
# One command install
curl -L https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/raw/master/install.sh | bash
```

### **2. Check Status:**
```bash
/home/xtreamcodes/iptv_xtream_codes/check_status.sh
```

### **3. Access Admin Panel:**
- URL: `http://YOUR_SERVER_IP:2086`
- Default credentials: admin/admin123 (or your custom settings)

### **4. If You Need to Remove:**
```bash
# Safe uninstall with backup
curl -L https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/raw/master/uninstall.sh | bash
```

---

**Built with ❤️ for the XtreamCodes community**

> **Note:** This is an enhanced community version with critical fixes and modern infrastructure. Always backup your data before installation. v1.1 includes official nginx and dynamic database updates for improved reliability and security.

---

## 📞 **Quick Support**

| Issue Type | Solution |
|------------|----------|
| 🔴 **Installation fails** | Check logs: `tail -f /root/*stefan_installer*.log` |
| 🔴 **Services not starting** | Run: `/home/xtreamcodes/iptv_xtream_codes/check_status.sh` |
| 🔴 **502 Bad Gateway** | Check: `nginx -t` and restart services |
| 🔴 **Permission errors** | Run installer again (it's safe to re-run) |
| 🔴 **Want to remove** | Use safe uninstaller with backup |

**📧 All issues should be reported on GitHub Issues for community support.**
