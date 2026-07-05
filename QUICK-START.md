# Quick Start Guide

**Fast TAK Server deployment for experienced Linux users.**

For complete documentation, see [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)

---

## Prerequisites

- Fresh Ubuntu 22.04 or 24.04 LTS VPS
- 8GB+ RAM, 4+ CPU cores, 50GB+ storage
- Root access OR user account with sudo privileges
- TAK Server `.deb` packages from [TAK.gov](https://tak.gov)

**Docker path (different artifact):** the official **`takserver-docker-*.zip`** — not the `.deb`. See [DEPLOYMENT-GUIDE.md — Docker](DEPLOYMENT-GUIDE.md#docker-tak-server-using-official-docker-zip-optional) and the official [TAK Server Configuration Guide (PDF)](docs/TAK_Server_Configuration_Guide.pdf) **§6**.

---

## 1. Clone the Repo & Prepare

> **Note:** If not running as root, your user account must have sudo privileges. The install script requires root access.

```bash
git clone https://github.com/TheCrawlSpace1/tak-server-installer.git
cd tak-server-installer/ubuntu-22.04
```

**Upload your TAK Server `.deb` packages to this directory** (`takserver-core_*.deb` and `takserver-database_*.deb`, from [TAK.gov](https://tak.gov)):

```bash
scp takserver-core_*.deb takserver-database_*.deb root@YOUR-IP:~/tak-server-installer/ubuntu-22.04/
```

> **Important:** The `.deb` packages must be in the same directory as `tak_auto_install.sh`.

---

## 2. Install TAK Server

```bash
cd ~/tak-server-installer/ubuntu-22.04
sudo ./tak_auto_install.sh
```

**During install:**
- Enter certificate metadata (Country, State, City, Organization, OU)
- Enter Root CA name (or press Enter for default)
- Enter Intermediate CA name (or press Enter for default)

**Completion time:** ~15-25 minutes

> **⚠️ Wait 5 minutes** after installation completes before accessing the web interface!

**Access:** `https://YOUR-IP:8443`
**Certificate:** `/opt/tak/certs/files/admin.p12`
**Password:** `atakatak`

**Download the admin certificate to your computer:**

```bash
# From your local computer (not the server)
scp root@YOUR-IP:/opt/tak/certs/files/admin.p12 .
```

Or use an SFTP client like FileZilla, WinSCP, or Cyberduck.

**Import certificate to your browser:**

- **Firefox:** Settings → Privacy & Security → Certificates → View Certificates → Your Certificates → Import → Select `admin.p12` → Enter password: `atakatak`
- **Chrome/Edge:** Settings → Privacy and Security → Security → Manage Certificates → Personal → Import → Select `admin.p12` → Enter password: `atakatak`
- **Safari (macOS):** Double-click `admin.p12` → Enter password: `atakatak` → Add to Keychain

Now browse to `https://YOUR-IP:8443` and select the admin certificate when prompted.

---

## Verification Commands

**Check TAK Server status:**
```bash
systemctl status takserver
```

**Check all services running:**
```bash
ps -ef | grep takserver.war
```
Should show 5 processes: config, messaging, api, plugins, retention

---

## Quick Command Reference

### Service Management
```bash
# Restart TAK Server
systemctl restart takserver

# View logs
tail -f /opt/tak/logs/takserver-messaging.log

# Check database
systemctl status postgresql
```

### Certificate Management
```bash
# Download admin certificate
scp root@YOUR-IP:/opt/tak/certs/files/admin.p12 .

# List all certificates
ls -la /opt/tak/certs/files/
```

---

## File Locations

| Type | Location |
|------|----------|
| TAK Server config | `/opt/tak/CoreConfig.xml` |
| Certificates | `/opt/tak/certs/files/` |
| Logs | `/opt/tak/logs/` |

---

## Default Credentials

| Item | Value |
|------|-------|
| Admin certificate password | `atakatak` |
| User certificate password | `atakatak` |
| PostgreSQL user | `martiuser` |
| PostgreSQL database | `cot` |

---

## Troubleshooting

**TAK Server won't start:**
```bash
journalctl -u takserver -n 50
tail -100 /opt/tak/logs/takserver-messaging.log
```

**Can't access web interface:**
- Wait 5 minutes after installation
- Check firewall: `ufw status`
- Verify certificate imported in browser

For SSL/domain names or production monitoring, this repo doesn't include a bundled setup script — see [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) for what's actually supported.

---

## Support

- **Repository:** [github.com/TheCrawlSpace1/tak-server-installer](https://github.com/TheCrawlSpace1/tak-server-installer)
- **Issues:** [Report bugs/issues](https://github.com/TheCrawlSpace1/tak-server-installer/issues)
- **YouTube:** [The TAK Syndicate](https://www.youtube.com/@thetaksyndicate6234)
- **Website:** [https://www.thetaksyndicate.org/](https://www.thetaksyndicate.org/)

---

**Created by:** [The TAK Syndicate](https://www.youtube.com/@thetaksyndicate6234) | [https://www.thetaksyndicate.org/](https://www.thetaksyndicate.org/)
