# TAK Server Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![TAK Server](https://img.shields.io/badge/TAK%20Server-5.x-blue)](https://tak.gov)

**A single self-contained installer script for TAK Server on Ubuntu 22.04/24.04**, plus an optional **Docker** workflow using the official `takserver-docker-*.zip` from [TAK.gov](https://tak.gov).

---

## 🚀 Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/TheCrawlSpace1/tak-server-installer.git
cd tak-server-installer/ubuntu-22.04

# 2. Place your TAK Server .deb packages in this folder (from TAK.gov), then run:
sudo ./tak_auto_install.sh
```

**Docker (optional):** use the official Docker ZIP, then run `./docker/tak-docker-install.sh` (see [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md#docker-tak-server-using-official-docker-zip-optional)).

**That's it!** Your TAK Server is running at `https://YOUR-IP:8443`

📖 **[Read the complete deployment guide](DEPLOYMENT-GUIDE.md)** for detailed instructions.

---

## ✨ What the installer does

- ✅ Installs dependencies and PostgreSQL 15
- ✅ Custom Root CA and Intermediate CA naming
- ✅ Certificate creation with proper keystores (single-pass CoreConfig.xml build)
- ✅ Firewall configuration (ports 8089, 8443, 8446)
- ✅ Auto-start on boot
- ✅ All certificates use standard password: `atakatak`

This is a single, self-contained script — it doesn't shell out to a separate patch script or rebuild `CoreConfig.xml` multiple times, which is what caused TLS on 8443 to silently fall back to plain HTTP in the original upstream flow.

---

## 📋 What You Need

### Required
- Fresh VPS with Ubuntu 22.04 or 24.04 LTS
- 8GB RAM minimum (16GB recommended)
- 50GB storage minimum (100GB+ recommended)
- 4 CPU cores minimum
- Root/sudo access
- TAK Server `.deb` packages from [TAK.gov](https://tak.gov)

---

## 📂 Repository Structure

```
tak-server-installer/
├── ubuntu-22.04/
│   └── tak_auto_install.sh     # Self-contained installer (install, certs, firewall)
├── docker/
│   ├── tak-docker-install.sh   # Install from takserver-docker-*.zip
│   └── docker-compose.yml      # Optional stack after images are built
├── patches/
│   ├── fix-caddy-renewal.sh    # Standalone fix for TAK Servers already running Caddy
│   └── README.MD
├── docs/
│   └── TAK_Server_Configuration_Guide.pdf   # Official TAK Product Center reference
├── DEPLOYMENT-GUIDE.md          # Complete deployment guide
├── QUICK-START.md               # Fast deployment instructions
└── README.md                    # This file
```

---

## 🎯 Installation Overview

**Ubuntu 22.04 / 24.04:**
```bash
cd ubuntu-22.04
sudo ./tak_auto_install.sh
```

**What it does:**
- Installs all dependencies
- Sets up PostgreSQL 15
- Creates custom Root and Intermediate CAs
- Generates admin and user certificates
- Configures firewall (ports 8089, 8443, 8446)
- Starts TAK Server

**Access:** `https://YOUR-IP:8443` (certificate: `/opt/tak/certs/files/admin.p12`, password: `atakatak`)

**⚠️ Wait 5 minutes** after completion before accessing the web interface — TAK Server needs time to fully initialize.

---

## 📚 Documentation

- **[Complete Deployment Guide](DEPLOYMENT-GUIDE.md)** - Step-by-step instructions with troubleshooting (includes **Docker**)
- **[Quick Start Guide](QUICK-START.md)** - Fast deployment for experienced users
- **[TAK Server Configuration Guide (PDF)](docs/TAK_Server_Configuration_Guide.pdf)** - Official TAK Product Center reference (e.g. **§6** Docker install); confirm current revision on [TAK.gov](https://tak.gov)

---

## 🔐 Security Notes

### Default Certificate Password
All certificates use the standard TAK Server password: **`atakatak`**

This includes:
- `admin.p12` (administrator certificate)
- `user.p12` (standard user certificate)
- All keystores and truststores

**Important:** Change this in production if required by your security policy.

### Firewall Ports
The install script automatically configures these ports:
- **8089/tcp** - TLS client connections
- **8443/tcp** - Admin web interface
- **8446/tcp** - Certificate enrollment

There is no built-in SSL/Caddy setup or hardening/monitoring step in this repo. If you need Let's Encrypt SSL on top of TAK Server, see `patches/fix-caddy-renewal.sh` only if you already have Caddy configured elsewhere — it is a targeted renewal fix, not a setup script.

---

## 🎓 Support

Created by **[The TAK Syndicate](https://www.youtube.com/@thetaksyndicate6234)**

- 🌐 Website: [https://www.thetaksyndicate.org](https://www.thetaksyndicate.org)
- 📺 YouTube: [@TheTAKSyndicate](https://www.youtube.com/@thetaksyndicate6234)
- 📧 Email: thetaksyndicate@gmail.com

### Getting Help
1. Check the [Deployment Guide](DEPLOYMENT-GUIDE.md)
2. Review [Common Issues](DEPLOYMENT-GUIDE.md#troubleshooting)
3. Search existing [GitHub Issues](https://github.com/TheCrawlSpace1/tak-server-installer/issues)
4. Open a new issue if needed

---

## 📜 License

MIT License - See [LICENSE](LICENSE) file for details.

Free to use, modify, and distribute. Attribution appreciated!

---

## 🙏 Credits

- **TAK Server** by [TAK Product Center](https://tak.gov)
- **Scripts** by [The TAK Syndicate](https://www.thetaksyndicate.org)
- **Community contributions** welcome!

---

**Latest Update:** July 2026
**Compatible with:** TAK Server 5.x series
**Tested on:** Ubuntu 22.04 / 24.04 LTS; Docker path uses the official container bundle from TAK.gov
