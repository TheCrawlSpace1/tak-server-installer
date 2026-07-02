#!/bin/bash
# =============================================================================
#  TAK Server 5.7 — Single-shot Installer for Ubuntu 22.04 / 24.04
#
#  Fully self-contained — does NOT call Ubuntu_22.04_TAK_Server_install.sh.
#  (That file is kept in this folder only as the pristine upstream reference;
#  its cert-generation, firewall, and system-limits steps have been merged
#  in below, and its CoreConfig.xml patching has been replaced with a single
#  correct build instead of patch-then-overwrite.)
#
#  Place this file in the SAME folder as:
#    - takserver-core_5.7-RELEASE43_all.deb
#    - takserver-database_5.7-RELEASE43_all.deb
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()     { echo -e "${GREEN}  ✓ $*${RESET}"; }
info()   { echo -e "${CYAN}  → $*${RESET}"; }
warn()   { echo -e "${YELLOW}  ⚠ $*${RESET}"; }
fail()   { echo -e "${RED}  ✗ $*${RESET}"; exit 1; }
header() { echo -e "\n${BOLD}${CYAN}════════════════════════════════════════${RESET}";
           echo -e "${BOLD}${CYAN}  $*${RESET}";
           echo -e "${BOLD}${CYAN}════════════════════════════════════════${RESET}"; }

[[ $EUID -ne 0 ]] && echo -e "${RED}Run with: sudo bash $0${RESET}" && exit 1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_PASS="atakatak"
PG_VERSION=15
PG_CLUSTER=main
PG_PORT=5432
TAK_DIR=/opt/tak
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   TAK Server 5.7 — Single-Shot Installer             ║${RESET}"
echo -e "${BOLD}║   Ubuntu 22.04 / 24.04 Compatible                    ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""

# =============================================================================
# STEP 1 — Verify required files
# =============================================================================
header "Step 1: Checking required files"

CORE_DEB=$(find "$SCRIPT_DIR" -maxdepth 1 -name "takserver-core_*.deb" | head -1)
DB_DEB=$(find "$SCRIPT_DIR" -maxdepth 1 -name "takserver-database_*.deb" | head -1)

[[ -z "$CORE_DEB" ]] && fail "takserver-core_*.deb not found in $SCRIPT_DIR"
[[ -z "$DB_DEB" ]]   && fail "takserver-database_*.deb not found in $SCRIPT_DIR"

ok "Core package:       $(basename "$CORE_DEB")"
ok "Database package:   $(basename "$DB_DEB")"

# =============================================================================
# STEP 2 — Wait out any in-progress system upgrades
# =============================================================================
header "Step 2: Checking for system upgrades in progress"

if pgrep -f "/usr/bin/unattended-upgrade$" > /dev/null; then
    warn "unattended-upgrades is running — waiting for it to finish (apt lock)"
    SECONDS=0
    while pgrep -f "/usr/bin/unattended-upgrade$" > /dev/null; do
        printf "\r  Waiting... %02d:%02d elapsed" $((SECONDS/60)) $((SECONDS%60))
        sleep 2
    done
    echo ""
    ok "System updates complete"
else
    ok "No system upgrades in progress"
fi

# =============================================================================
# STEP 3 — System limits
# =============================================================================
header "Step 3: Increasing system limits"

if ! grep -q "^\* soft nofile 32768" /etc/security/limits.conf 2>/dev/null; then
    cat <<EOF | tee --append /etc/security/limits.conf > /dev/null
* soft nofile 32768
* hard nofile 32768
EOF
    ok "System limits configured"
else
    ok "System limits already configured"
fi

# =============================================================================
# STEP 4 — Java 17
# =============================================================================
header "Step 4: Installing Java 17"

apt-get update -qq

info "Installing required system packages..."
apt-get install -y openssh-server net-tools curl debsig-verify > /dev/null 2>&1 || true
ok "System packages installed"

apt-get install -y openjdk-17-jdk 2>&1 | grep -E "^E:|already|installed|upgraded" || true
# Fix any unmet dependencies that commonly occur on Ubuntu 24.04
apt-get install -f -y > /dev/null 2>&1 || true
apt-get install -y openjdk-17-jdk openjdk-17-jre openjdk-17-jdk-headless openjdk-17-jre-headless \
    2>&1 | grep -E "^E:|already|installed|upgraded" || true
apt-get install -f -y > /dev/null 2>&1 || true

java -version > /dev/null 2>&1 && ok "Java 17 ready" || fail "Java 17 failed to install"

# =============================================================================
# STEP 5 — PostgreSQL 15
# =============================================================================
header "Step 5: PostgreSQL 15 setup"

if ! dpkg -l postgresql-$PG_VERSION 2>/dev/null | grep -q "^ii"; then
    info "Installing PostgreSQL $PG_VERSION + PostGIS..."
    if ! apt-cache show postgresql-$PG_VERSION &>/dev/null; then
        apt-get install -y curl ca-certificates gnupg lsb-release > /dev/null 2>&1
        curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
            | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg 2>/dev/null
        echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] \
https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
            > /etc/apt/sources.list.d/pgdg.list
        apt-get update -qq
    fi
    apt-get install -y postgresql-$PG_VERSION postgresql-$PG_VERSION-postgis-3 > /dev/null 2>&1
fi
ok "PostgreSQL $PG_VERSION installed"

# Create cluster if missing (Ubuntu 24.04 doesn't always auto-create it)
if ! pg_lsclusters 2>/dev/null | grep -q "${PG_VERSION}.*${PG_CLUSTER}"; then
    info "Creating PostgreSQL cluster..."
    pg_createcluster $PG_VERSION $PG_CLUSTER
    ok "Cluster created"
else
    ok "Cluster $PG_VERSION/$PG_CLUSTER exists"
fi

PG_CONF="/etc/postgresql/$PG_VERSION/$PG_CLUSTER/postgresql.conf"

# Enable TCP listening
if grep -qE "^#listen_addresses|listen_addresses = ''" "$PG_CONF" 2>/dev/null; then
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" "$PG_CONF"
    sed -i "s/listen_addresses = ''/listen_addresses = 'localhost'/" "$PG_CONF"
    ok "TCP listening enabled"
fi

# Fix port if not 5432 (Ubuntu 24.04 assigns 5433 when PG18 was present)
CURRENT_PORT=$(grep "^port" "$PG_CONF" 2>/dev/null | awk '{print $3}' || echo "")
if [[ -n "$CURRENT_PORT" && "$CURRENT_PORT" != "$PG_PORT" ]]; then
    warn "PostgreSQL on port $CURRENT_PORT — fixing to $PG_PORT"
    sed -i "s/^port = $CURRENT_PORT/port = $PG_PORT/" "$PG_CONF"
fi

systemctl enable postgresql@${PG_VERSION}-${PG_CLUSTER} > /dev/null 2>&1
systemctl restart postgresql@${PG_VERSION}-${PG_CLUSTER}

info "Waiting for PostgreSQL..."
for i in $(seq 1 20); do
    sudo -u postgres psql -c "SELECT 1" > /dev/null 2>&1 && break
    sleep 2
    [[ $i -eq 20 ]] && fail "PostgreSQL failed to start"
done
ok "PostgreSQL running on port $PG_PORT"

# =============================================================================
# STEP 6 — TAK database user + database
# =============================================================================
header "Step 6: TAK database user & database"

sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='martiuser'" \
    | grep -q 1 \
    || sudo -u postgres psql -c "CREATE USER martiuser WITH PASSWORD '$DB_PASS';" > /dev/null
sudo -u postgres psql -c "ALTER USER martiuser WITH PASSWORD '$DB_PASS';" > /dev/null
sudo -u postgres psql -c "ALTER USER martiuser WITH SUPERUSER;" > /dev/null
ok "User 'martiuser' ready (superuser)"

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='cot'" \
    | grep -q 1 \
    || sudo -u postgres psql -c "CREATE DATABASE cot OWNER martiuser;" > /dev/null
ok "Database 'cot' ready"

# =============================================================================
# STEP 7 — Install core .deb + pre-populate CoreConfig.xml
# =============================================================================
header "Step 7: Installing TAK core + pre-configuring CoreConfig.xml"

info "Installing takserver-core..."
dpkg -i --force-overwrite "$CORE_DEB" 2>&1 | grep -E "error|Error|warning" | grep -v "^$" || true
apt-get install -f -y > /dev/null 2>&1 || true

for i in $(seq 1 10); do [[ -d "$TAK_DIR" ]] && break; sleep 2; done
[[ ! -d "$TAK_DIR" ]] && fail "/opt/tak not created — core package failed"

# Create CoreConfig.xml from example if needed
[[ ! -f "$TAK_DIR/CoreConfig.xml" ]] && \
    cp "$TAK_DIR/CoreConfig.example.xml" "$TAK_DIR/CoreConfig.xml"

# Inject password so the database postinst NEVER prompts interactively
for cfg in "$TAK_DIR/CoreConfig.xml" "$TAK_DIR/CoreConfig.example.xml"; do
    [[ -f "$cfg" ]] || continue
    sed -i "s/username=\"martiuser\" password=\"[^\"]*\"/username=\"martiuser\" password=\"$DB_PASS\"/g" "$cfg"
    sed -i "s/password=\"\"/password=\"$DB_PASS\"/g" "$cfg"
done
ok "CoreConfig.xml pre-populated with password"

# =============================================================================
# STEP 8 — Install database .deb non-interactively
# =============================================================================
header "Step 8: Installing TAK database package"

info "Installing takserver-database..."
DEBIAN_FRONTEND=noninteractive PGDATA=/var/lib/postgresql/$PG_VERSION/$PG_CLUSTER \
    dpkg -i --force-overwrite "$DB_DEB" 2>&1 | grep -E "error|Error|schema|Applied|up to date" || true
apt-get install -f -y > /dev/null 2>&1 || true
ok "Database package installed"

# =============================================================================
# STEP 9 — SchemaManager
# =============================================================================
header "Step 9: Running SchemaManager"

cd "$TAK_DIR"
info "Applying database schema..."
sudo -u tak java -jar "$TAK_DIR/db-utils/SchemaManager.jar" upgrade 2>&1 \
    | grep -E "Applied|up to date|ERROR" | tail -5 || true
ok "SchemaManager done"

# =============================================================================
# STEP 10 — Firewall
# =============================================================================
header "Step 10: Configuring firewall"

# 22 = SSH/SFTP, 8089 = TLS client traffic, 8443 = WebTAK/HTTPS, 8446 = certificate enrollment
ufw allow 22/tcp    > /dev/null 2>&1
ufw allow 8089/tcp  > /dev/null 2>&1
ufw allow 8443/tcp  > /dev/null 2>&1
ufw allow 8446/tcp  > /dev/null 2>&1
ufw --force enable  > /dev/null 2>&1
ok "Firewall configured (22, 8089, 8443, 8446)"

# =============================================================================
# STEP 11 — Generate certificates
# =============================================================================
header "Step 11: Generating certificates"

echo ""
warn "Enter ALL values in CAPITAL LETTERS with NO SPACES."
echo ""

CERT_INFO_CONFIRMED=false
while [ "$CERT_INFO_CONFIRMED" = false ]; do
    read -p 'Country (2 letters, e.g., US, CA, GB): ' CERT_COUNTRY
    read -p 'State/Province (e.g., TN, CA, ON): ' CERT_STATE
    read -p 'City (e.g., SODDYDAISY): ' CERT_CITY
    read -p 'Organization (e.g., MYORG): ' CERT_ORG
    read -p 'Organizational Unit (e.g., TAK): ' CERT_OU
    echo ""
    read -p 'Root CA name (e.g., ROOT-CA-01): ' ROOT_CA_NAME
    read -p 'Intermediate CA name (e.g., INTERMEDIATE-CA-01): ' INTERMEDIATE_CA_NAME

    echo ""
    echo "Certificate Summary:"
    echo "  Country: $CERT_COUNTRY | State: $CERT_STATE | City: $CERT_CITY"
    echo "  Organization: $CERT_ORG | Unit: $CERT_OU"
    echo "  Root CA: $ROOT_CA_NAME | Intermediate CA: $INTERMEDIATE_CA_NAME"
    echo ""
    read -p "Is this correct? (y/n): " CONFIRM
    [[ $CONFIRM =~ ^[Yy]$ ]] && CERT_INFO_CONFIRMED=true || echo "Let's try again..."
done

cd "$TAK_DIR/certs"
info "Cleaning up any existing certificates..."
rm -rf "$TAK_DIR/certs/files"

[[ ! -f cert-metadata.sh.original ]] && cp cert-metadata.sh cert-metadata.sh.original
cp cert-metadata.sh.original cert-metadata.sh

sed -i "s/COUNTRY=US/COUNTRY=$CERT_COUNTRY/g" cert-metadata.sh
sed -i "s/STATE=\${STATE}/STATE=$CERT_STATE/g" cert-metadata.sh
sed -i "s/CITY=\${CITY}/CITY=$CERT_CITY/g" cert-metadata.sh
sed -i "s/ORGANIZATION=\${ORGANIZATION:-TAK}/ORGANIZATION=$CERT_ORG/g" cert-metadata.sh
sed -i "s/ORGANIZATIONAL_UNIT=\${ORGANIZATIONAL_UNIT}/ORGANIZATIONAL_UNIT=$CERT_OU/g" cert-metadata.sh
chown -R tak:tak "$TAK_DIR/certs/"
ok "cert-metadata.sh updated"

info "Creating Root CA: $ROOT_CA_NAME"
echo "$ROOT_CA_NAME" | sudo -u tak ./makeRootCa.sh

info "Creating Intermediate CA: $INTERMEDIATE_CA_NAME"
echo -e "y\n" | sudo -u tak ./makeCert.sh ca "$INTERMEDIATE_CA_NAME"

info "Creating server certificate..."
sudo -u tak ./makeCert.sh server takserver

info "Creating admin certificate..."
sudo -u tak ./makeCert.sh client admin

info "Creating user certificate..."
sudo -u tak ./makeCert.sh client user

ok "All certificates created"

# =============================================================================
# STEP 12 — Build final CoreConfig.xml (single correct build — no re-patching)
# =============================================================================
header "Step 12: Configuring CoreConfig.xml"

CORECONFIG="$TAK_DIR/CoreConfig.xml"
SERVER_IP=$(hostname -I | awk '{print $1}')

# We already know the intermediate CA name from the prompt above, so use it
# directly. This is what broke on 2026-07-02: the old script re-derived this
# name by globbing for *-signing.jks, but an earlier version of that glob
# looked for a literal "intermediate-signing.jks" and silently produced an
# empty string when a custom CA name was used, corrupting every
# keystore/truststore/CRL path in CoreConfig.xml and breaking TLS on 8443.
INTERMEDIATE_NAME="$INTERMEDIATE_CA_NAME"
if [ -z "$INTERMEDIATE_NAME" ] || [ ! -f "$TAK_DIR/certs/files/${INTERMEDIATE_NAME}-signing.jks" ]; then
    INTERMEDIATE_SIGNING_JKS=$(ls "$TAK_DIR"/certs/files/*-signing.jks 2>/dev/null | head -1)
    if [ -n "$INTERMEDIATE_SIGNING_JKS" ]; then
        INTERMEDIATE_NAME=$(basename "$INTERMEDIATE_SIGNING_JKS" | sed 's/-signing\.jks$//')
    else
        fail "Could not determine intermediate CA name — no *-signing.jks file found in $TAK_DIR/certs/files/"
    fi
fi

SERVER_ID=$(grep -oP 'serverId="\K[^"]+' "$CORECONFIG" 2>/dev/null || cat /proc/sys/kernel/random/uuid | tr -d '-')

info "Building CoreConfig.xml (Org: $CERT_ORG / Unit: $CERT_OU)"
info "Intermediate CA: $INTERMEDIATE_NAME"

cat > "$CORECONFIG" << XMLEOF
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Configuration xmlns="http://bbn.com/marti/xml/config">
    <network multicastTTL="5" serverId="$SERVER_ID" version="5.7-RELEASE43">
        <input _name="stdssl" protocol="tls" port="8089" coreVersion="2" auth="x509"/>
        <connector port="8443" _name="https"/>
        <connector port="8444" useFederationTruststore="true" _name="fed_https"/>
        <connector port="8446" clientAuth="false" _name="cert_https"/>
        <announce/>
    </network>
    <auth x509groups="true" x509addAnonymous="false" x509useGroupCache="true" x509checkRevocation="true" x509tokenAuth="true">
        <File location="UserAuthenticationFile.xml"/>
    </auth>
    <submission ignoreStaleMessages="false" validateXml="false"/>
    <subscription reloadPersistent="false"/>
    <repository enable="true" numDbConnections="200" primaryKeyBatchSize="500" insertionBatchSize="500">
        <connection url="jdbc:postgresql://127.0.0.1:5432/cot" username="martiuser" password="$DB_PASS"/>
    </repository>
    <repeater enable="true" periodMillis="3000" staleDelayMillis="15000">
        <repeatableType initiate-test="/event/detail/emergency[@type='911 Alert']" cancel-test="/event/detail/emergency[@cancel='true']" _name="911"/>
        <repeatableType initiate-test="/event/detail/emergency[@type='Ring The Bell']" cancel-test="/event/detail/emergency[@cancel='true']" _name="RingTheBell"/>
        <repeatableType initiate-test="/event/detail/emergency[@type='Geo-fence Breached']" cancel-test="/event/detail/emergency[@cancel='true']" _name="GeoFenceBreach"/>
        <repeatableType initiate-test="/event/detail/emergency[@type='Troops In Contact']" cancel-test="/event/detail/emergency[@cancel='true']" _name="TroopsInContact"/>
    </repeater>
    <filter>
        <thumbnail/>
        <urladd host="http://$SERVER_IP:8080"/>
        <flowtag enable="true" text=""/>
        <streamingbroker enable="true"/>
        <scrubber enable="false" action="overwrite"/>
        <qos>
            <deliveryRateLimiter enabled="true">
                <rateLimitRule clientThresholdCount="500" reportingRateLimitSeconds="200"/>
                <rateLimitRule clientThresholdCount="1000" reportingRateLimitSeconds="300"/>
                <rateLimitRule clientThresholdCount="2000" reportingRateLimitSeconds="400"/>
                <rateLimitRule clientThresholdCount="5000" reportingRateLimitSeconds="800"/>
                <rateLimitRule clientThresholdCount="10000" reportingRateLimitSeconds="1200"/>
            </deliveryRateLimiter>
            <readRateLimiter enabled="false">
                <rateLimitRule clientThresholdCount="500" reportingRateLimitSeconds="200"/>
                <rateLimitRule clientThresholdCount="1000" reportingRateLimitSeconds="300"/>
                <rateLimitRule clientThresholdCount="2000" reportingRateLimitSeconds="400"/>
                <rateLimitRule clientThresholdCount="5000" reportingRateLimitSeconds="800"/>
                <rateLimitRule clientThresholdCount="10000" reportingRateLimitSeconds="1200"/>
            </readRateLimiter>
            <dosRateLimiter enabled="false" intervalSeconds="60">
                <dosLimitRule clientThresholdCount="1" messageLimitPerInterval="60"/>
            </dosRateLimiter>
        </qos>
    </filter>
    <buffer>
        <queue>
            <priority/>
        </queue>
        <latestSA enable="true"/>
    </buffer>
    <dissemination smartRetry="false"/>
    <certificateSigning CA="TAKServer">
        <certificateConfig>
            <nameEntries>
                <nameEntry name="O" value="$CERT_ORG"/>
                <nameEntry name="OU" value="$CERT_OU"/>
            </nameEntries>
        </certificateConfig>
        <TAKServerCAConfig
            keystore="JKS"
            keystoreFile="certs/files/${INTERMEDIATE_NAME}-signing.jks"
            keystorePass="atakatak"
            validityDays="30"
            signatureAlg="SHA256WithRSA"
            CAkey="/opt/tak/certs/files/${INTERMEDIATE_NAME}.key"
            CAcertificate="/opt/tak/certs/files/${INTERMEDIATE_NAME}.pem"/>
    </certificateSigning>
    <security>
        <tls keystore="JKS" keystoreFile="certs/files/takserver.jks" keystorePass="atakatak" truststore="JKS" truststoreFile="certs/files/truststore-${INTERMEDIATE_NAME}.jks" truststorePass="atakatak" context="TLSv1.2" keymanager="SunX509">
            <crl _name="TAKserver CA" crlFile="certs/files/${INTERMEDIATE_NAME}.crl"/>
        </tls>
    </security>
    <federation missionFederationDisruptionToleranceRecencySeconds="43200">
        <federation-server port="9000" v1enabled="false" v2port="9001" v2enabled="true" webBaseUrl="https://$SERVER_IP:8443/Marti">
            <tls keystore="JKS" keystoreFile="certs/files/takserver.jks" keystorePass="atakatak" truststore="JKS" truststoreFile="certs/files/fed-truststore.jks" truststorePass="atakatak" context="TLSv1.2" keymanager="SunX509"/>
            <v1Tls tlsVersion="TLSv1.2"/>
            <v1Tls tlsVersion="TLSv1.3"/>
        </federation-server>
        <fileFilter>
            <fileExtension>pref</fileExtension>
        </fileFilter>
    </federation>
    <plugins/>
    <cluster/>
    <vbm enabled="false"/>
</Configuration>
XMLEOF

chown tak:tak "$CORECONFIG" 2>/dev/null || true
ok "CoreConfig.xml fully configured"

# =============================================================================
# STEP 13 — Start TAK Server
# =============================================================================
header "Step 13: Starting TAK Server"

systemctl daemon-reload
systemctl enable takserver > /dev/null 2>&1
systemctl restart takserver

info "Waiting for TAK Server to come up (up to 90 seconds on low-RAM machines)..."
for i in $(seq 1 30); do
    ss -tlnp | grep -q ":8443" && break
    printf "."
    sleep 3
done
echo ""
if ss -tlnp | grep -q ":8443"; then
    ok "TAK Server is up on port 8443"
else
    warn "Port 8443 not open yet — TAK may still be initializing (wait 1-2 min)"
fi

# =============================================================================
# STEP 14 — Promote admin certificate
# =============================================================================
header "Step 14: Promoting admin certificate"

ADMIN_PROMOTED=false
for i in $(seq 1 5); do
    if java -jar "$TAK_DIR/utils/UserManager.jar" certmod -A "$TAK_DIR/certs/files/admin.pem" > /dev/null 2>&1; then
        ADMIN_PROMOTED=true
        break
    fi
    info "Admin promotion not ready yet, retrying in 15s ($i/5)..."
    sleep 15
done
if [ "$ADMIN_PROMOTED" = true ]; then
    ok "Admin certificate promoted"
else
    warn "Admin promotion failed after 5 attempts. Try manually once TAK is fully up:"
    warn "  sudo java -jar $TAK_DIR/utils/UserManager.jar certmod -A $TAK_DIR/certs/files/admin.pem"
fi

# =============================================================================
# STEP 15 — Copy admin.p12 to Documents
# =============================================================================
header "Step 15: Copying admin certificate"

if [[ -f "$TAK_DIR/certs/files/admin.p12" ]]; then
    mkdir -p "$REAL_HOME/Documents"
    cp "$TAK_DIR/certs/files/admin.p12" "$REAL_HOME/Documents/admin.p12"
    chown "$REAL_USER:$REAL_USER" "$REAL_HOME/Documents/admin.p12"
    ok "admin.p12 copied to $REAL_HOME/Documents/"
else
    warn "admin.p12 not found — certificates may not have generated correctly"
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${GREEN}║   TAK Server Installation Complete!                  ║${RESET}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${BOLD}Web Interface:${RESET}   https://$SERVER_IP:8443"
echo -e "  ${BOLD}Admin Cert:${RESET}      $REAL_HOME/Documents/admin.p12"
echo -e "  ${BOLD}Cert Password:${RESET}   atakatak"
echo ""
echo -e "${BOLD}Import admin.p12 into Firefox:${RESET}"
echo "  Settings → Privacy & Security → Certificates"
echo "  → View Certificates → Your Certificates → Import"
echo "  → Select admin.p12 → Password: atakatak"
echo ""
echo -e "${BOLD}Useful commands:${RESET}"
echo "  sudo systemctl status takserver"
echo "  sudo systemctl restart takserver"
echo "  sudo tail -f /opt/tak/logs/takserver-api.log"
echo "  ps aux | grep tak | grep java | grep -v grep"
echo ""
