# TAK Server Complete Deployment Guide

**Version:** 3.0
**Date:** July 2026
**Compatible with:** TAK Server 5.x series
**Operating System:** Ubuntu 22.04 / 24.04 LTS

This guide covers deployment of TAK Server on Ubuntu via the single self-contained installer script in this repo, plus the optional Docker path using the official Docker ZIP from TAK.gov.

**Created by:** [The TAK Syndicate](https://www.youtube.com/@thetaksyndicate6234) | [https://www.thetaksyndicate.org/](https://www.thetaksyndicate.org/)

---

## Table of Contents

- [SECTION 1: Prerequisites](#section-1-prerequisites)
- [SECTION 2: TAK Server Installation](#section-2-tak-server-installation)
- [DOCKER: TAK Server using official Docker ZIP (optional)](#docker-tak-server-using-official-docker-zip-optional)
- [SECTION 3: Post-Installation](#section-3-post-installation)
- [SECTION 4: Troubleshooting](#section-4-troubleshooting)
- [APPENDIX A: Command Reference](#appendix-a-command-reference)
- [APPENDIX B: Log Locations](#appendix-b-log-locations)
- [APPENDIX C: Common Issues & Solutions](#appendix-c-common-issues--solutions)

---

## SECTION 1: PREREQUISITES

### 1.1 VPS REQUIREMENTS

- Operating System: Ubuntu 22.04 or 24.04 LTS (fresh install)
- RAM: 8GB minimum, 16GB recommended
- Storage: 50GB minimum, 100GB+ recommended
- CPU: 4 cores minimum
- Network: Public IP address
- Root access via SSH OR user account with sudo privileges

This repo does not include a domain/SSL setup step or a hardening/monitoring step — it's a single install script. If you want SSL, put TAK Server behind your own reverse proxy or Caddy instance; if you already have Caddy configured from an older version of this repo, see `patches/fix-caddy-renewal.sh`.

### 1.2 REQUIRED FILES

Download from [TAK.gov](https://tak.gov):

1. `takserver-core_X.X-RELEASEX_all.deb`
2. `takserver-database_X.X-RELEASEX_all.deb`

OPTIONAL - Package Signature Verification:

3. `takserver-public-gpg.key`
4. `deb_policy.pol`

If you include these verification files in the same directory as the install script, it will verify the `.deb` signature using the GPG key and policy file. If they're not present, the script skips verification and proceeds with installation (acceptable for most users).

Note: Any 5.x version will work with this script.

### 1.3 INITIAL VPS SETUP

**Step 1: SSH into your VPS**

> **Note:** If not logging in as root, your user account must have sudo privileges. The install script requires root access to install system packages, configure services, and modify system settings.

```bash
ssh root@YOUR-VPS-IP
```

**Step 2: Clone the repository**

```bash
git clone https://github.com/TheCrawlSpace1/tak-server-installer.git
cd tak-server-installer/ubuntu-22.04
```

**Step 3: Upload your TAK Server `.deb` packages to this directory**

```bash
scp takserver-core_*.deb takserver-database_*.deb root@YOUR-VPS-IP:~/tak-server-installer/ubuntu-22.04/
```

**OPTIONAL:** Also upload signature verification files (`takserver-public-gpg.key`, `deb_policy.pol`) to the same directory.

> **Important:** The `.deb` packages, `tak_auto_install.sh`, and optional verification files must all be in the same directory!

> **Note:** The install script will create the 'tak' user automatically.

---

## SECTION 2: TAK SERVER INSTALLATION

As root, from the `ubuntu-22.04/` directory:

```bash
cd ~/tak-server-installer/ubuntu-22.04
sudo ./tak_auto_install.sh
```

The script will prompt you for:

**STEP 1: Certificate Metadata**
- Country (2 letters): e.g., US, CA, GB
- State (caps, no spaces): e.g., CA, ON
- City (caps, no spaces): e.g., SACRAMENTO
- Organization (caps, no spaces): e.g., MYCOMPANY
- Organizational Unit (caps, no spaces): e.g., IT

**STEP 2: Certificate Authority Names**
- Root CA name: e.g., ROOT-CA-01 (no spaces, make it unique)
- Intermediate CA name: e.g., INTERMEDIATE-CA-01 (no spaces, make it unique)

**What the script does:**
1. Updates system packages
2. Installs dependencies (Java, PostgreSQL 15, etc.)
3. Configures PostgreSQL database
4. Installs TAK Server from the local `.deb` packages
5. Creates all certificates in a single pass: Root CA, Intermediate CA, server certificate (`takserver.jks`), admin certificate (`admin.p12`), user certificate (`user.p12`)
6. Builds `CoreConfig.xml` once for X.509 authentication (not patched-then-overwritten)
7. Enables certificate enrollment on port 8446
8. Configures the firewall (ufw) for ports 8089, 8443, 8446
9. Restarts TAK Server (with proper wait times)
10. Promotes the admin certificate to administrator role

**Total time:** 15-25 minutes
- System updates: 5-10 minutes
- TAK installation: 3-5 minutes
- Certificate creation: 2-3 minutes
- Service initialization: 5-7 minutes

⚠️ **IMPORTANT:** Wait 5 minutes before accessing the web interface! TAK Server needs time to fully initialize all services after installation.

All certificates (`.p12` files) use the password: `atakatak`

This is the TAK Server default and is used for:
- `admin.p12` (administrator certificate)
- `user.p12` (standard user certificate)

⚠️ **IMPORTANT:** Save this password — you'll need it to import certificates!

The admin certificate is located at:
```
/opt/tak/certs/files/admin.p12
```
Password: `atakatak`

Download this file to your computer using:
- SCP: `scp root@YOUR-IP:/opt/tak/certs/files/admin.p12 .`
- SFTP client (FileZilla, WinSCP, Cyberduck, etc.)

**Firefox:**
1. Settings → Privacy & Security → Certificates → View Certificates
2. Your Certificates → Import
3. Select `admin.p12`
4. Enter password: `atakatak`

**Chrome/Edge:**
1. Settings → Privacy and Security → Security → Manage Certificates
2. Personal → Import
3. Select `admin.p12`
4. Enter password: `atakatak`

**Safari (macOS):**
1. Double-click `admin.p12`
2. Enter password: `atakatak`
3. Add to Keychain

After the 5 minute wait:
```
https://YOUR-VPS-IP:8443
```
Your browser will prompt you to select the admin certificate.

**Check TAK Server status:**
```bash
systemctl status takserver
```
You should see: `Active: active (exited)` — this is an LSB init script that launches the Java processes in the background and then exits itself; `active (exited)` is the expected healthy state, not a failure.

**Check all services are running:**
```bash
pgrep -af 'Dspring.profiles.active=(config|messaging|api)|takserver-pm.jar|takserver-retention.jar'
```
You should see 5 Java processes: `config` (`-jar takserver.war -Dspring.profiles.active=config`), `messaging` and `api` (run `tak.server.ServerConfiguration` off the classpath, identified by `-Dspring.profiles.active=messaging`/`=api` — neither actually runs `-jar takserver.war`), plus `plugins` (`-jar takserver-pm.jar`) and `retention` (`-jar takserver-retention.jar`). A plain `grep takserver.war` both misses plugins/retention and, because the unescaped `.` matches any character, falsely matches messaging/api's `takserver-war-5.7-RELEASE-43.jar` classpath entry.

**Check logs for errors:**
```bash
tail -100 /opt/tak/logs/takserver-messaging.log
```
Look for "Started ServerConfiguration" messages.

---

## DOCKER: TAK Server using official Docker ZIP (optional)

This path is **separate** from the Ubuntu `.deb` install above. Use it when you deploy from the official **`takserver-docker-*.zip`** package from [TAK.gov](https://tak.gov).

**Authoritative reference (bundled in this repo):** [docs/TAK_Server_Configuration_Guide.pdf](docs/TAK_Server_Configuration_Guide.pdf) — *TAK Server Configuration Guide*, Version **5.6**, December **2025**, **Section 6** *Containerized Installation (Docker)*. The detailed command sequence is **§6.2** *Building and Installing Container Images Using Docker* (standard bundle). **§6.1** covers Iron Bank; **§6.2** also references the hardened ZIP (`takserver-docker-hardened-<version>.zip`) with extra CA/container steps. Appendix **B** in that PDF covers certificate tooling (`cert-metadata.sh`, `makeRootCa.sh`, `makeCert.sh`).

What the guide expects at a high level (matches `docker/tak-docker-install.sh`):

1. Copy `tak/CoreConfig.example.xml` → `CoreConfig.xml` and set the **database password** before building images.
2. `docker build` for **`takserver-db`** using `docker/Dockerfile.takserver-db` (or hardened Dockerfile when using the hardened bundle).
3. `docker network create takserver-"$(cat tak/version.txt)"`.
4. `docker run` the DB container with **`--network-alias tak-database`** (Compose in this repo uses the same alias on a user-defined network).
5. `docker build` for **`takserver`** using `docker/Dockerfile.takserver`.
6. `docker run` the TAK Server container with the published ports (8089, 8443, 8444, 8446, 9000, 9001 by default).
7. Configure **`tak/certs/cert-metadata.sh`**, generate CA and certs inside the container, then **`./configureInDocker.sh`**, tail **`tak/logs/`** from the host, and run **UserManager** to authorize the admin client PEM.

For the newest PDF, always check [TAK.gov](https://tak.gov) in case the bundled copy is behind your deployment.

### When to use Docker

- You want TAK Server and PostgreSQL in containers (no native `takserver` systemd service on the host).
- You have the Docker ZIP, not the `.deb`.

### Requirements

- Linux host with Docker (Ubuntu 22.04/24.04, etc.)
- Same rough VPS sizing as native install (8GB+ RAM, 4+ cores, 50GB+ disk)
- Place `takserver-docker-*.zip` in `~/tak-docker/` (or set `INSTALL_DIR` in the script)

### Automated install (recommended)

From this repository:

```bash
git clone https://github.com/TheCrawlSpace1/tak-server-installer.git
# Copy the Docker ZIP into ~/tak-docker/ (see script header for INSTALL_DIR)
cp /path/to/takserver-docker-5.x-RELEASE-x.zip ~/tak-docker/
chmod +x ~/tak-server-installer/docker/tak-docker-install.sh
~/tak-server-installer/docker/tak-docker-install.sh
```

The script installs Docker if missing (apt), configures `CoreConfig.xml` and `cert-metadata.sh`, builds `takserver-db` and `takserver` images, runs containers, generates certificates, and promotes the admin client.

Edit variables at the top of `docker/tak-docker-install.sh` (CA name, org fields, cert password, etc.) before running.

### Compose (optional)

After the ZIP is extracted and **both images are built** (`takserver-db:${VERSION}` and `takserver:${VERSION}`), you can run the stack with Compose from the **extracted** directory (where `tak/` and `docker/` exist):

```bash
export VERSION="$(cat tak/version.txt)"
cp /path/to/tak-server-installer/docker/docker-compose.yml .
docker compose up -d
```

`docker/docker-compose.yml` in this repo defines a shared network and DB alias **`tak-database`** so hostnames match the usual Docker guide expectations. Database data can persist in the named volume `tak-db-data`.

### Differences from the native Ubuntu install

- Uses the **Docker ZIP**, not the `.deb`.
- No SSL setup or hardening/monitoring is applied automatically to Docker. Use container logs, host monitoring, or your orchestrator for health checks.
- Default client cert password remains **`atakatak`** unless you change it in the script.

### Verify

```bash
docker ps
docker logs -f takserver-$(cat tak/version.txt)
```

Web UI: `https://YOUR-IP:8443` (import `admin.p12` as with the native install).

For exact commands and hardened-image differences, use **§6** in [docs/TAK_Server_Configuration_Guide.pdf](docs/TAK_Server_Configuration_Guide.pdf) or the latest guide from [TAK.gov](https://tak.gov).

---

## SECTION 3: POST-INSTALLATION

### 3.1 Configure Data Retention

⚠️ **DO THIS IMMEDIATELY after installation!** Without data retention, TAK Server will fill your disk with CoT data.

1. Log into web interface: `https://YOUR-IP:8443`
2. Click hamburger menu (☰) → Administrative
3. Select "Data Retention"
4. Configure retention policies:

Recommended settings:
- CoT (non-chat): 1 day
- GeoChat (chat CoT messages): 1 day
- Mission Packages: No time to live (leave blank)
- Mission: No time to live (leave blank)
- Files: No time to live (leave blank)

Adjust based on available disk space, operational requirements, and compliance needs.

### 3.2 User & Group Management

Create users through the web administration interface:

1. Login to admin interface: `https://YOUR-IP:8443`
2. Click hamburger menu (☰) → Administrative → Manage User
3. Click "Add User" button
4. Enter username and password
5. Click "Create New User"

Managing Groups (in same area):
- Click "Add Group" to create new groups
- Select a user and edit which groups they have access to
- Groups control data sharing between users

**User enrollment on TAK clients:** Users do NOT need to download certificates (`.p12` files). Instead:
1. In ATAK/WinTAK/iTAK, go to Settings → Server Connection
2. Enter Server: your-domain-or-IP, Port: 8089, SSL/TLS: Enabled
3. Use Certificate Enrollment: Enrollment URL `https://your-domain-or-IP:8446`, with the username/password created above
4. The TAK client will auto-enroll and download certificates

**For users who need `.p12` certificate files (advanced use):**

```bash
cd /opt/tak/certs
sudo -u tak ./makeCert.sh client USERNAME
```

Download certificate: `/opt/tak/certs/files/USERNAME.p12` (password: `atakatak`)

Promote user to administrator:
```bash
java -jar /opt/tak/utils/UserManager.jar certmod -A /opt/tak/certs/files/USERNAME.pem
```

Add user to group:
```bash
java -jar /opt/tak/utils/UserManager.jar certmod -g GROUPNAME /opt/tak/certs/files/USERNAME.pem
```

List all users:
```bash
java -jar /opt/tak/utils/UserManager.jar userlist
```

Best practices: create separate groups for different teams/operations, use `__ANON__` for anonymous users if needed. Users only see other users in their shared groups.

### 3.3 Firewall

Ports opened by the install script (ufw):
```
22/tcp   - SSH
8089/tcp - TAK client connections (TLS)
8443/tcp - Web UI (HTTPS)
8446/tcp - Certificate enrollment
```

View current firewall rules:
```bash
ufw status verbose
```

### 3.4 Backups

Critical files to back up regularly:

**TAK Server Configuration:**
```
/opt/tak/CoreConfig.xml
/opt/tak/CoreConfig.xml.backup (if exists)
```

**Certificates:**
```
/opt/tak/certs/files/  (entire directory - all .p12, .jks, .pem files)
```

**Database:**
```bash
# Backup
sudo -u postgres pg_dump takserver > takserver-backup.sql

# Restore
sudo -u postgres psql takserver < takserver-backup.sql
```

Suggested schedule: daily PostgreSQL backups, weekly certificate/config backups, full system backup before updates.

### 3.5 Additional Security Measures

Beyond what the install script configures:

**SSH:**
- Consider changing the default SSH port to reduce automated brute-force noise
- Disable root login: create a sudo user, then set `PermitRootLogin no` in `/etc/ssh/sshd_config`, restart `sshd`
- Use SSH keys instead of passwords: `ssh-keygen -t ed25519`, `ssh-copy-id`, then `PasswordAuthentication no`
- Consider `fail2ban`: `apt install fail2ban`

**Firewall:** only open required ports, use IP allowlisting where possible.

**PostgreSQL:** change default passwords, restrict network access, enable SSL connections if exposed beyond localhost.

**TAK Server:** use strong certificate passwords if you change from the default, regularly review user access, enable audit logging, monitor for suspicious activity.

**VPS Provider:** enable DDoS protection where available, use private networking, configure snapshots/backups.

---

## SECTION 4: TROUBLESHOOTING

### TAK Server won't start

```bash
systemctl status takserver
```

Common causes: Java not installed, PostgreSQL not running, port already in use, certificate/keystore issues, insufficient memory.

Solutions:
```bash
java -version                                    # 1. Verify Java 17 installed
systemctl status postgresql                      # 2. Check PostgreSQL
ss -tlnp | grep -E "8089|8443"                    # 3. Check if ports in use
tail -100 /opt/tak/logs/takserver-messaging.log   # 4. Review logs
free -h                                           # 5. Check memory
```

### Can't access web interface (port 8443)

Symptoms: connection refused, connection timeout, certificate error, blank page.

```bash
systemctl status takserver          # 1. Verify TAK Server running
ss -tlnp | grep 8443                # 2. Check port listening
ufw status                          # 3. Check firewall
# 4. Check certificate imported in browser (Settings → Certificates → Your Certificates)
# 5. Try a different browser
tail -100 /opt/tak/logs/takserver-api.log   # 6. Check logs
```

### Can't connect on port 8089 (TAK clients)

Symptoms: connection refused, timeout, authentication failures.

```bash
ss -tlnp | grep 8089                              # 1. Verify port listening
ufw status                                        # 2. Check firewall
grep 'auth="x509"' /opt/tak/CoreConfig.xml        # 3. Verify X.509 auth enabled
# 4. Check client certificate: not expired, correct CA, user in correct group
tail -f /opt/tak/logs/takserver-messaging.log     # 5. Watch logs while client connects
openssl s_client -connect YOUR-IP:8089            # 6. Test connectivity
```

### PostgreSQL issues

```bash
systemctl status postgresql               # Check status
sudo -u postgres psql -l | grep takserver # Verify database exists
sudo -u postgres psql takserver           # Test connection
cat /etc/postgresql/15/main/pg_hba.conf   # Check auth config
```

**Too many connections:** increase `max_connections` in `postgresql.conf` (`/etc/postgresql/15/main/postgresql.conf`), then `systemctl restart postgresql`, and tune the connection pool in `CoreConfig.xml`.

### TAK Server using high CPU

```bash
grep "connect" /opt/tak/logs/takserver-messaging.log | sort | uniq -c
```
Look for reconnect loops (a single client connecting repeatedly), a misbehaving plugin, or slow database queries. Consider rate limiting in `CoreConfig.xml`.

### Running out of memory / OOM errors

```bash
jstat -gc $(pgrep -f takserver.war) 1000
```
Increase heap size in `/opt/tak/setenv.sh`, check for memory leaks in custom plugins, review data retention settings, or add more RAM to the VPS.

### Disk space > 90%

```bash
du -h /opt/tak | sort -h | tail -20
```
Review data retention settings (Section 3.1), clean old data via the web UI (Admin → Data Management → Delete Old Data), or clean old logs: `find /opt/tak/logs -mtime +30 -delete`.

### Certificate issues

```bash
keytool -list -v -keystore /opt/tak/certs/files/takserver.jks   # Check expiry / contents
grep "keystoreFile" /opt/tak/CoreConfig.xml                      # Check which keystore is in use
```

If clients don't trust the certificate, distribute the intermediate CA `.p12` to clients, or verify the chain with:
```bash
openssl s_client -connect YOUR-IP:8089 -showcerts
```

---

## APPENDIX A: COMMAND REFERENCE

### TAK Server commands
```bash
systemctl start takserver
systemctl stop takserver
systemctl restart takserver
systemctl status takserver
systemctl enable takserver     # auto-start on boot
systemctl disable takserver
tail -f /opt/tak/logs/takserver-messaging.log
tail -f /opt/tak/logs/takserver-api.log
pgrep -af 'Dspring.profiles.active=(config|messaging|api)|takserver-pm.jar|takserver-retention.jar'   # check all 5 TAK processes
pkill -9 -f 'Dspring.profiles.active=(config|messaging|api)|takserver-pm.jar|takserver-retention.jar' && systemctl start takserver   # kill hung processes, restart
```

### Certificate commands
```bash
cd /opt/tak/certs
sudo -u tak ./makeCert.sh client USERNAME
sudo -u tak ./makeCert.sh server SERVERNAME

java -jar /opt/tak/utils/UserManager.jar certmod -A /opt/tak/certs/files/USERNAME.pem   # promote to admin
java -jar /opt/tak/utils/UserManager.jar certmod -g GROUPNAME /opt/tak/certs/files/USERNAME.pem   # add to group
java -jar /opt/tak/utils/UserManager.jar userlist   # list all users

keytool -list -v -keystore /opt/tak/certs/files/KEYSTORE.jks
```

### PostgreSQL commands
```bash
systemctl start postgresql
systemctl stop postgresql
systemctl status postgresql

sudo -u postgres psql takserver          # connect
sudo -u postgres psql -l                 # list databases
sudo -u postgres pg_dump takserver > backup.sql     # backup
sudo -u postgres psql takserver < backup.sql        # restore
sudo -u postgres vacuumdb --all --analyze
```

### Firewall commands (ufw)
```bash
ufw status verbose
ufw allow 8089/tcp
ufw delete allow 8089/tcp
ufw enable
ufw disable
```

### System monitoring
```bash
free -h            # Memory
df -h              # Disk
uptime             # Load
top / htop         # Processes
ss -tlnp           # Listening ports
ss -tan            # All connections
journalctl -u takserver -n 50
journalctl -u takserver -f
journalctl -xe     # Recent system errors
```

---

## APPENDIX B: LOG LOCATIONS

**TAK Server logs** — main directory: `/opt/tak/logs/`

| File | Contents |
|------|----------|
| `takserver-messaging.log` | Client connections, CoT (most useful for connection issues) |
| `takserver-api.log` | Web UI, REST API (most useful for web UI issues) |
| `takserver-config.log` | Configuration service |
| `takserver-plugins.log` | Plugin manager |
| `takserver-retention.log` | Data retention |

**PostgreSQL logs:** `/var/log/postgresql/postgresql-15-main.log`

**System auth log:** `/var/log/auth.log`

**Viewing logs:**
```bash
tail -100 /opt/tak/logs/takserver-messaging.log      # last 100 lines
tail -f /opt/tak/logs/takserver-messaging.log        # follow live
grep -i error /opt/tak/logs/takserver-messaging.log  # search for errors
grep "username" /opt/tak/logs/takserver-messaging.log
```

---

## APPENDIX C: COMMON ISSUES & SOLUTIONS

**ISSUE:** "Failed to find deployed service: distributed-user-file-manager"
Cause: Ignite distributed services not yet initialized.
Solution: Wait 5-10 minutes after TAK Server restart. This is normal during startup, not an error.

**ISSUE:** TAK Server using 100% CPU
Causes: client reconnect loop, database query performance, too many concurrent connections, misbehaving plugin.
Solution: `grep "connect" /opt/tak/logs/takserver-messaging.log | sort | uniq -c`, review database indexes, implement connection rate limiting in `CoreConfig.xml`, disable suspect plugins.

**ISSUE:** Disk fills up quickly
Cause: no Data Retention configured.
Solution: configure Data Retention in the web UI immediately (Section 3.1); clean old data via Admin → Data Management → Delete Old Data.

**ISSUE:** Client connects but no data flows
Causes: certificate not in correct group, firewall blocking traffic, client/server clock skew, network issues.
Solution: check user groups in the web UI, verify firewall rules, `timedatectl set-ntp true`, test network connectivity, check TAK Server logs during the connection attempt.

**ISSUE:** `SSL_ERROR_RX_RECORD_TOO_LONG`
Cause: port 8443 running as HTTP instead of HTTPS.
Solution: verify `CoreConfig.xml` has the correct keystore configuration (`grep "truststoreFile" /opt/tak/CoreConfig.xml`), ensure certificate files exist with correct permissions, restart TAK Server.

**ISSUE:** "Connection refused" to port 8089
Causes: TAK Server not running, port not listening, firewall blocking, wrong port configured.
Solution: `systemctl start takserver`, `ss -tlnp | grep 8089`, `ufw status`, verify `CoreConfig.xml` port configuration.

**ISSUE:** PostgreSQL "too many connections"
Cause: connection pool exhausted.
Solution: increase `max_connections` in `/etc/postgresql/15/main/postgresql.conf`, `systemctl restart postgresql`, tune `CoreConfig.xml` connection pool to match.

**ISSUE:** Java `OutOfMemoryError`
Cause: insufficient heap space.
Solution: edit `/opt/tak/setenv.sh`, increase `MESSAGING_MAX_HEAP` and `API_MAX_HEAP`, restart TAK Server, add more RAM if errors persist.

**ISSUE:** Certificate enrollment fails
Causes: port 8446 not accessible, certificate signing not configured, enrollment not enabled, wrong CA certificate.
Solution: `ufw allow 8446/tcp`, verify `CoreConfig.xml` has a `certificateSigning` section, check enrollment settings in the web UI, ensure clients have the correct CA certificate.

**ISSUE:** Can't delete old missions/data
Cause: Data Retention not running or configured.
Solution: verify retention configuration in `CoreConfig.xml`, manual cleanup via Admin → Data Management → Delete Old Data, check `takserver-retention.log`.

**ISSUE:** Users can't access certain features
Cause: insufficient permissions or wrong group.
Solution: check the user's role and group membership in the web UI; promote to admin if needed via `UserManager.jar certmod -A`.

**ISSUE:** Slow web UI performance
Causes: large number of active users/data, slow database queries, insufficient system resources, network latency.
Solution: check system resources (`top`, `free -h`, `df -h`), review PostgreSQL performance, clear old data, increase API heap size in `/opt/tak/setenv.sh`, add more RAM/CPU.

**ISSUE:** Federation not working
Cause: not covered by this installer.
Solution: federation requires additional configuration beyond this repo's scope — see TAK Server's own documentation for `fed-truststore.jks` setup.

**ISSUE:** Plugin won't load
Causes: incompatible plugin version, missing dependencies, incorrect installation, plugin conflicts.
Solution: verify plugin compatibility with the installed TAK version, check `/opt/tak/logs/takserver-plugins.log`, ensure the plugin is in `/opt/tak/plugins`, restart TAK Server after installing a plugin.

---

END OF GUIDE

For the latest updates and support:
- TAK.gov: https://tak.gov

This guide is maintained by The TAK Syndicate
YouTube: @TheTAKSyndicate

Last updated: July 2026
Guide version: 3.0 (Ubuntu-only)
