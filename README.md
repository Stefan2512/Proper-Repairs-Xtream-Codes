# XtreamCodes Enhanced - Stefan Edition

## 🚀 Complete Fix Package for Ubuntu 18.04/20.04/22.04

### Enhanced XtreamCodes installation with ALL critical fixes included automatically!

This repository contains the **complete enhanced version** of XtreamCodes with all dependency fixes, performance optimizations, and critical patches integrated.

---

## ✅ **What's Fixed & Enhanced:**

### 🔧 **Critical Fixes Included:**
- ✅ **libzip.so.4 compatibility** - Automatic symlink creation
- ✅ **PHP-FPM socket issues** - Enhanced error handling and retry logic  
- ✅ **Dependency management** - All required libraries included
- ✅ **Permission fixes** - Proper ownership and permissions set automatically
- ✅ **MySQL/MariaDB optimization** - Optimized configuration included

### ⚡ **Performance Enhancements:**
- ✅ **Enhanced nginx configuration** - Optimized for high performance
- ✅ **System optimizations** - Kernel parameters and limits optimized
- ✅ **tmpfs support** - High-performance temporary file storage
- ✅ **Load balancing** - Enhanced upstream configuration

### 🛠 **Management Tools:**
- ✅ **Status checker** - Monitor service health
- ✅ **Quick restart** - Restart services safely  
- ✅ **Auto-start** - SystemD service + cron backup

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

# Check if services are running
ps aux | grep -E "(nginx|php-fpm)" | grep xtreamcodes
```

---

## 📋 **System Requirements**

- **Operating System:** Ubuntu 18.04/20.04/22.04 LTS (64-bit)
- **RAM:** Minimum 2GB (4GB+ recommended)  
- **Storage:** 10GB+ free space
- **Network:** Internet connection for installation
- **Privileges:** Root access required

---

## 🆘 **Troubleshooting**

### **Common Issues FIXED Automatically:**
- ❌ **502 Bad Gateway** → ✅ PHP-FPM socket creation fixed
- ❌ **libzip.so.4 missing** → ✅ Automatic symlink creation  
- ❌ **Permission denied** → ✅ Enhanced permission management
- ❌ **Services not starting** → ✅ Dependency verification and installation

### **If Issues Persist:**
1. **Check status:** `/home/xtreamcodes/iptv_xtream_codes/check_status.sh`
2. **View logs:** `tail -f /home/xtreamcodes/iptv_xtream_codes/logs/error.log`
3. **Restart services:** `/home/xtreamcodes/iptv_xtream_codes/restart_services.sh`

---

## 📂 **Repository Contents**

### **Main Files:**
- `install.sh` - Enhanced installer with all fixes
- `start_services.sh` - Service startup script  
- `balancer.php` - Load balancer script
- `balancer.sh` - Balancer helper script

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
| Feature | Original | Stefan Enhanced |
|---------|----------|-----------------|
| libzip.so.4 fix | ❌ Manual | ✅ Automatic |
| PHP-FPM sockets | ❌ Often fails | ✅ Reliable creation |
| Dependencies | ❌ Missing packages | ✅ All included |
| Error handling | ❌ Basic | ✅ Advanced retry logic |
| Management tools | ❌ None | ✅ Status & restart scripts |
| Performance | ❌ Default | ✅ Optimized config |

---

## 🔄 **Updates & Support**

### **Getting Updates:**
This enhanced version includes automatic update mechanisms for:
- GeoIP database updates
- Security patches  
- Performance optimizations

### **Support:**
- **Issues:** [GitHub Issues](https://github.com/Stefan2512/Proper-Repairs-Xtream-Codes/issues)
- **Documentation:** Check this README and release notes
- **Community:** XtreamCodes community forums

---

## 📝 **Changelog**

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

- **Stefan2512** - Enhanced integration, fixes, and repository maintenance
- **Original XtreamCodes** - Base IPTV panel system  
- **dOC4eVER** - Initial fixes and patches foundation
- **Community** - Testing, feedback, and support

---

## 🌟 **Why Choose Stefan Enhanced?**

✅ **Reliability:** All common issues fixed automatically  
✅ **Performance:** Optimized for high-load scenarios  
✅ **Maintenance:** Easy management tools included  
✅ **Support:** Active community and documentation  
✅ **Updates:** Regular enhancements and security patches  

---

**Built with ❤️ for the XtreamCodes community**

> **Note:** This is an enhanced community version with critical fixes. Always backup your data before installation.
