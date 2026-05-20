#!/usr/bin/env bash
# ============================================================
#  Shibboleth Identity Provider 5 - Automated Installer
#  Manual reference: LEARN-LK/IAM (version_v5_shobboleth_step_by_step.md)
#
#  Usage:
#    sudo bash install_idp.sh /path/to/idp.env
#
#  Must be run as root or with sudo.
#
#  PREREQUISITES (do these BEFORE running the script):
#  -------------------------------------------------------
#  1. Fill in idp.env with your institution's values.
#
#  2. If LDAP_MODE is 'starttls' or 'tls', copy your LDAP
#     server certificate to this IdP server first:
#
#     On the LDAP server:
#       openssl x509 -outform der \
#         -in /etc/ssl/certs/ldap_server.pem \
#         -out /etc/ssl/certs/ldap_server.crt
#
#     Then from the LDAP server (or from this IdP server):
#       scp <ldap-user>@<ldap-fqdn>:/etc/ssl/certs/ldap_server.crt \
#           /tmp/ldap_server.crt
#
#     The script will validate the file exists, copy it into
#     /opt/shibboleth-idp/credentials/ at the right step,
#     and remove the /tmp staging copy afterwards.
#
#  3. Ensure DNS resolves ${IDP_FQDN} to this server's public IP
#     (required for Certbot to obtain an SSL certificate).
# ============================================================

set -euo pipefail

# ---------- Load environment file ----------
if [[ $# -lt 1 ]]; then
  echo "Usage: sudo bash $0 /path/to/idp.env"
  exit 1
fi

ENV_FILE="$1"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: env file not found: $ENV_FILE"
  exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

# ---------- Derived variables ----------
BASE_DN="dc=${DOMAIN_DC1},dc=${DOMAIN_DC2},dc=${DOMAIN_DC3}"
IDP_HOME="/opt/shibboleth-idp"
JETTY_BASE="/opt/jetty-base"
JETTY_HOME="/opt/jetty-home"

# LDAP URL depends on mode
case "$LDAP_MODE" in
  starttls) LDAP_URL="ldap://${LDAP_FQDN}:389" ;;
  tls)      LDAP_URL="ldaps://${LDAP_FQDN}:636" ;;
  plain)    LDAP_URL="ldap://${LDAP_FQDN}:389" ;;
  *) echo "ERROR: LDAP_MODE must be starttls, tls, or plain"; exit 1 ;;
esac

# ============================================================
log() { echo -e "\n\033[1;34m>>> $*\033[0m"; }
warn() { echo -e "\033[1;33mWARN: $*\033[0m"; }
die() { echo -e "\033[1;31mERROR: $*\033[0m"; exit 1; }

[[ $EUID -eq 0 ]] || die "Run this script as root or with sudo."

# ============================================================
# PRE-FLIGHT CHECKS
# ============================================================
log "PRE-FLIGHT: Checking prerequisites"

# LDAP cert check — skip for plain mode (no cert needed)
LDAP_CERT_TMP="/tmp/ldap_server.crt"
if [[ "$LDAP_MODE" != "plain" ]]; then
  if [[ ! -f "$LDAP_CERT_TMP" ]]; then
    echo ""
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║  PREREQUISITE: LDAP Server Certificate Missing               ║"
    echo "  ╠══════════════════════════════════════════════════════════════╣"
    echo "  ║  LDAP mode is set to: ${LDAP_MODE}"
    echo "  ║  A certificate file is required at: ${LDAP_CERT_TMP}"
    echo "  ║                                                              ║"
    echo "  ║  On your LDAP server, run:                                   ║"
    echo "  ║    openssl x509 -outform der \\                               ║"
    echo "  ║      -in /etc/ssl/certs/ldap_server.pem \\                    ║"
    echo "  ║      -out /etc/ssl/certs/ldap_server.crt                     ║"
    echo "  ║                                                              ║"
    echo "  ║  Then copy it to THIS server:                                ║"
    echo "  ║    scp user@${LDAP_FQDN}:/etc/ssl/certs/ldap_server.crt \\"
    echo "  ║        ${LDAP_CERT_TMP}"
    echo "  ║                                                              ║"
    echo "  ║  Then re-run this script.                                    ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""
    die "Aborting — LDAP certificate not found at ${LDAP_CERT_TMP}"
  fi
  echo "  [OK] LDAP certificate found at ${LDAP_CERT_TMP}"
else
  echo "  [SKIP] LDAP mode is 'plain' — no certificate required."
fi

echo "  [OK] Running as root."
echo "  [OK] Environment file loaded: ${ENV_FILE}"
echo "  [OK] IdP FQDN: ${IDP_FQDN}"
echo "  [OK] LDAP mode: ${LDAP_MODE}"
echo ""

# ============================================================
# STEP 1 — System Preparation
# ============================================================
log "STEP 1: Updating system packages"
apt update && apt upgrade -y

log "STEP 1: Installing required dependencies"
apt install -y curl wget unzip gnupg2 apt-transport-https \
  ca-certificates software-properties-common ntp apache2

log "STEP 1: Setting hostname to ${IDP_FQDN}"
hostnamectl set-hostname "${IDP_FQDN}"

# Add to /etc/hosts only if not already present
grep -q "127.0.1.1  ${IDP_FQDN}" /etc/hosts || \
  echo "127.0.1.1  ${IDP_FQDN}" >> /etc/hosts

# ============================================================
# STEP 2 — Java 17
# ============================================================
log "STEP 2: Installing OpenJDK 17"
apt install -y openjdk-17-jdk-headless

log "STEP 2: Setting JAVA_HOME"
grep -q "JAVA_HOME" /etc/environment || \
  echo 'JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> /etc/environment

cat > /etc/profile.d/java.sh << 'JEOF'
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
JEOF
# shellcheck source=/dev/null
source /etc/profile.d/java.sh

java -version

# ============================================================
# STEP 3 — Jetty 12
# ============================================================
log "STEP 3: Creating jetty system user"
id jetty &>/dev/null || useradd -r -m -U -d /opt/jetty -s /bin/false jetty

log "STEP 3: Downloading Jetty ${JETTY_VER}"
cd /opt
if [[ ! -d "jetty-home-${JETTY_VER}" ]]; then
  wget -q "https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/${JETTY_VER}/jetty-home-${JETTY_VER}.tar.gz"
  tar -xzf "jetty-home-${JETTY_VER}.tar.gz"
  rm "jetty-home-${JETTY_VER}.tar.gz"
fi
[[ -L jetty-home ]] || ln -s "jetty-home-${JETTY_VER}" jetty-home

log "STEP 3: Creating Jetty base and enabling modules"
mkdir -p "${JETTY_BASE}"
cd "${JETTY_BASE}"
java -jar "${JETTY_HOME}/start.jar" \
  --add-modules=server,http,https,ee10-deploy,ee10-annotations,ee10-cdi,requestlog,rewrite,ssl,console-capture \
  || true   # idempotent — already-added modules print a warning but exit 0

log "STEP 3: Setting Jetty ownership"
chown -R jetty:jetty "${JETTY_HOME}" "${JETTY_BASE}"

# ============================================================
# STEP 4 — Shibboleth IdP 5
# ============================================================
log "STEP 4: Downloading Shibboleth IdP ${IDP_VER}"
cd /opt
if [[ ! -d "shibboleth-identity-provider-${IDP_VER}" ]]; then
  wget -q "https://shibboleth.net/downloads/identity-provider/${IDP_VER}/shibboleth-identity-provider-${IDP_VER}.tar.gz"
  tar -xzf "shibboleth-identity-provider-${IDP_VER}.tar.gz"
  rm "shibboleth-identity-provider-${IDP_VER}.tar.gz"
fi

log "STEP 4: Running Shibboleth IdP installer (non-interactive)"
cd "/opt/shibboleth-identity-provider-${IDP_VER}"
if [[ ! -d "${IDP_HOME}" ]]; then
  # Provide answers via heredoc — installer reads stdin
  bin/install.sh \
    -Didp.target.dir="${IDP_HOME}" \
    -Didp.host.name="${IDP_FQDN}" \
    -Didp.entityID="https://${IDP_FQDN}/idp/shibboleth" \
    -Didp.merge.properties=/dev/null \
    -Didp.noprompt=true
fi

log "STEP 4: Setting IdP permissions"
chown -R jetty:jetty "${IDP_HOME}"
chmod -R 750 "${IDP_HOME}"

# ============================================================
# STEP 5 — SSL Certificate (Certbot / Let's Encrypt)
# ============================================================
log "STEP 5: Installing Certbot"
apt install -y certbot python3-certbot-apache

log "STEP 5: Obtaining Let's Encrypt certificate for ${IDP_FQDN}"
certbot --apache \
  -d "${IDP_FQDN}" \
  --agree-tos \
  --email "${ADMIN_EMAIL}" \
  --no-eff-email \
  --non-interactive \
  || warn "Certbot may have already obtained a cert. Continuing..."

log "STEP 5: Converting cert to PKCS12 for Jetty"
openssl pkcs12 -export \
  -in "/etc/letsencrypt/live/${IDP_FQDN}/fullchain.pem" \
  -inkey "/etc/letsencrypt/live/${IDP_FQDN}/privkey.pem" \
  -out "${IDP_HOME}/credentials/idp.p12" \
  -name idp \
  -passout "pass:${SSL_KEYSTORE_PASSWORD}"

chown jetty:jetty "${IDP_HOME}/credentials/idp.p12"
chmod 640 "${IDP_HOME}/credentials/idp.p12"

log "STEP 5: Creating Certbot deploy hook for auto-renewal"
cat > /etc/letsencrypt/renewal-hooks/deploy/jetty-idp.sh << HOOK
#!/bin/bash
openssl pkcs12 -export \\
  -in /etc/letsencrypt/live/${IDP_FQDN}/fullchain.pem \\
  -inkey /etc/letsencrypt/live/${IDP_FQDN}/privkey.pem \\
  -out ${IDP_HOME}/credentials/idp.p12 \\
  -name idp \\
  -passout pass:${SSL_KEYSTORE_PASSWORD}

chown jetty:jetty ${IDP_HOME}/credentials/idp.p12
chmod 640 ${IDP_HOME}/credentials/idp.p12
systemctl restart jetty
HOOK
chmod +x /etc/letsencrypt/renewal-hooks/deploy/jetty-idp.sh

# ============================================================
# STEP 6 — Configure Jetty (using sed / cat for all files)
# ============================================================
log "STEP 6: Writing Jetty configuration files"

# 6.1 idp.ini
cat > "${JETTY_BASE}/start.d/idp.ini" << 'EOF'
jetty.deploy.scanInterval=0
EOF

# 6.2 http.ini
cat > "${JETTY_BASE}/start.d/http.ini" << 'EOF'
--module=http
jetty.http.port=80
jetty.http.host=0.0.0.0
EOF

# 6.3 ssl.ini  — inject password via sed after writing template
cat > "${JETTY_BASE}/start.d/ssl.ini" << 'EOF'
--module=ssl
jetty.ssl.port=443
jetty.ssl.host=0.0.0.0
jetty.sslContext.keyStorePath=KEYSTORE_PATH
jetty.sslContext.keyStorePassword=KEYSTORE_PASS
jetty.sslContext.keyStoreType=PKCS12
jetty.sslContext.trustStorePath=KEYSTORE_PATH
jetty.sslContext.trustStorePassword=KEYSTORE_PASS
jetty.sslContext.trustStoreType=PKCS12
EOF
sed -i "s|KEYSTORE_PATH|${IDP_HOME}/credentials/idp.p12|g" \
        "${JETTY_BASE}/start.d/ssl.ini"
sed -i "s|KEYSTORE_PASS|${SSL_KEYSTORE_PASSWORD}|g" \
        "${JETTY_BASE}/start.d/ssl.ini"
chown jetty:jetty "${JETTY_BASE}/start.d/ssl.ini"

# 6.4 https.ini
cat > "${JETTY_BASE}/start.d/https.ini" << 'EOF'
--module=https
jetty.https.port=443
EOF

# 6.5 idp.xml webapp context
mkdir -p "${JETTY_BASE}/webapps"
cat > "${JETTY_BASE}/webapps/idp.xml" << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE Configure PUBLIC "-//Jetty//Configure//EN"
  "https://www.eclipse.org/jetty/configure_10_0.dtd">

<Configure class="org.eclipse.jetty.ee10.webapp.WebAppContext">
  <Set name="war">/opt/shibboleth-idp/war/idp.war</Set>
  <Set name="contextPath">/idp</Set>
  <Set name="extractWAR">false</Set>
  <Set name="copyWebDir">false</Set>
  <Set name="copyWebInf">true</Set>
  <Set name="tempDirectory">/opt/shibboleth-idp/jetty-tmp</Set>
  <Set name="parentLoaderPriority">false</Set>
</Configure>
EOF
chown jetty:jetty "${JETTY_BASE}/webapps/idp.xml"

# 6.6 Temp dir
mkdir -p "${IDP_HOME}/jetty-tmp"
chown jetty:jetty "${IDP_HOME}/jetty-tmp"

# 6.7 Logging
cat > "${JETTY_BASE}/start.d/console-capture.ini" << 'EOF'
--module=console-capture
jetty.console-capture.dir=/var/log/jetty
jetty.console-capture.retain=90
jetty.console-capture.append=true
EOF
mkdir -p /var/log/jetty
chown jetty:jetty /var/log/jetty

chown -R jetty:jetty "${JETTY_BASE}/"

# ============================================================
# STEP 7 — JSTL / JSP Support
# ============================================================
log "STEP 7: Adding JSTL jars to IdP webapp"
mkdir -p "${IDP_HOME}/edit-webapp/WEB-INF/lib"

wget -q -O "${IDP_HOME}/edit-webapp/WEB-INF/lib/jakarta.servlet.jsp.jstl-api-3.0.0.jar" \
  "https://repo1.maven.org/maven2/jakarta/servlet/jsp/jstl/jakarta.servlet.jsp.jstl-api/3.0.0/jakarta.servlet.jsp.jstl-api-3.0.0.jar"

wget -q -O "${IDP_HOME}/edit-webapp/WEB-INF/lib/jakarta.servlet.jsp.jstl-3.0.1.jar" \
  "https://repo1.maven.org/maven2/org/glassfish/web/jakarta.servlet.jsp.jstl/3.0.1/jakarta.servlet.jsp.jstl-3.0.1.jar"

log "STEP 7: Enabling ee10-jsp in Jetty"
cd "${JETTY_BASE}"
java -jar "${JETTY_HOME}/start.jar" --add-modules=ee10-jsp || true
chown -R jetty:jetty "${JETTY_BASE}/" "${IDP_HOME}/edit-webapp/"

# ============================================================
# STEP 8 — MySQL / StorageService
# ============================================================
log "STEP 8: Installing MySQL and Java connector libraries"
apt install -y default-mysql-server libmariadb-java \
  libcommons-dbcp2-java libcommons-pool2-java --no-install-recommends

systemctl enable --now mysql

log "STEP 8: Setting MySQL root password"
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';" || \
  warn "Root password may already be set."

log "STEP 8: Downloading and importing storageservice schema"
wget -q https://raw.githubusercontent.com/LEARN-LK/IAM/master/shib-ss-db.sql \
  -O /root/shib-ss-db.sql

# Use sed to inject DB name, user, and password into the SQL file
sed -i "s/storageservice/${MYSQL_DB_NAME}/g"       /root/shib-ss-db.sql
sed -i "s/'shib'/'${MYSQL_SHIB_USER}'/g"           /root/shib-ss-db.sql
sed -i "s/'yourpassword'/'${MYSQL_SHIB_PASSWORD}'/g" /root/shib-ss-db.sql
# Also handle common "Learn@123" default in the sql file
sed -i "s/'Learn@123'/'${MYSQL_SHIB_PASSWORD}'/g"  /root/shib-ss-db.sql

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" < /root/shib-ss-db.sql
systemctl restart mysql

log "STEP 8: Linking MariaDB/DBCP2 jars into IdP"
cd "${IDP_HOME}"
for jar in \
  /usr/share/java/mariadb-java-client.jar \
  /usr/share/java/commons-dbcp2.jar \
  /usr/share/java/commons-pool2.jar; do
  target="edit-webapp/WEB-INF/lib/$(basename "$jar")"
  [[ -e "$target" ]] || ln -s "$jar" "$target"
done

# ============================================================
# STEP 9 — Persistent-ID configuration (sed edits)
# ============================================================
log "STEP 9: Generating persistent-id salt"
PERSISTENT_ID_SALT=$(openssl rand -base64 36)

log "STEP 9: Configuring saml-nameid.properties"
NAMEID_PROPS="${IDP_HOME}/conf/saml-nameid.properties"

sed -i "s|^#\?idp.persistentId.sourceAttribute\s*=.*|idp.persistentId.sourceAttribute = uid|" \
       "${NAMEID_PROPS}"
sed -i "s|^#\?idp.persistentId.salt\s*=.*|idp.persistentId.salt = ${PERSISTENT_ID_SALT}|" \
       "${NAMEID_PROPS}"
sed -i "s|^#\?idp.persistentId.generator\s*=.*|idp.persistentId.generator = shibboleth.StoredPersistentIdGenerator|" \
       "${NAMEID_PROPS}"
sed -i "s|^#\?idp.persistentId.dataSource\s*=.*|idp.persistentId.dataSource = MyDataSource|" \
       "${NAMEID_PROPS}"
sed -i "s|^#\?idp.persistentId.computed\s*=.*|idp.persistentId.computed = shibboleth.ComputedPersistentIdGenerator|" \
       "${NAMEID_PROPS}"

log "STEP 9: Enabling SAML2PersistentGenerator in saml-nameid.xml"
NAMEID_XML="${IDP_HOME}/conf/saml-nameid.xml"
sed -i 's|<!--\s*<ref bean="shibboleth.SAML2PersistentGenerator"\s*/>\s*-->|<ref bean="shibboleth.SAML2PersistentGenerator" />|' \
       "${NAMEID_XML}"
# If it's already uncommented leave it; if the comment style differs try a broader match
grep -q 'shibboleth.SAML2PersistentGenerator' "${NAMEID_XML}" || \
  warn "Could not find SAML2PersistentGenerator line — verify saml-nameid.xml manually."

log "STEP 9: Enabling c14n/SAML2Persistent"
C14N_XML="${IDP_HOME}/conf/c14n/subject-c14n.xml"
sed -i 's|<!--\s*<ref bean="c14n/SAML2Persistent"\s*/>\s*-->|<ref bean="c14n/SAML2Persistent" />|' \
       "${C14N_XML}"

log "STEP 9: Adding DataSource bean to global.xml"
GLOBAL_XML="${IDP_HOME}/conf/global.xml"

# Insert DataSource bean before closing </beans> if not already present
grep -q "MyDataSource" "${GLOBAL_XML}" || sed -i "s|</beans>|    <!-- DataSource for persistent-id -->\n    <bean id=\"MyDataSource\"\n  class=\"org.apache.commons.dbcp2.BasicDataSource\"\n  destroy-method=\"close\" lazy-init=\"true\"\n  p:driverClassName=\"org.mariadb.jdbc.Driver\"\n  p:url=\"jdbc:mysql://127.0.0.1:3306/${MYSQL_DB_NAME}?useSSL=false\&amp;autoReconnect=true\&amp;allowPublicKeyRetrieval=true\"\n  p:username=\"${MYSQL_SHIB_USER}\"\n  p:password=\"${MYSQL_SHIB_PASSWORD}\"\n  p:maxTotal=\"10\"\n  p:maxIdle=\"5\"\n  p:maxWaitMillis=\"15000\"\n  p:testOnBorrow=\"true\"\n  p:validationQuery=\"select 1\"\n  p:validationQueryTimeout=\"5\" />\n\n</beans>|" "${GLOBAL_XML}"

# ============================================================
# STEP 10 — LDAP Configuration (sed edits)
# ============================================================
log "STEP 10: Installing LDAP server certificate into IdP credentials"
LDAP_CERT_DEST="${IDP_HOME}/credentials/ldap_server.crt"
if [[ "$LDAP_MODE" != "plain" ]]; then
  # /tmp/ldap_server.crt was validated at pre-flight; IDP_HOME now exists
  cp "${LDAP_CERT_TMP}" "${LDAP_CERT_DEST}"
  chown jetty:jetty "${LDAP_CERT_DEST}"
  chmod 640 "${LDAP_CERT_DEST}"
  echo "  [OK] LDAP cert installed  -> ${LDAP_CERT_DEST}"
  rm -f "${LDAP_CERT_TMP}"
  echo "  [OK] Removed staging copy  /tmp/ldap_server.crt"
else
  echo "  [SKIP] LDAP mode is 'plain' — no certificate to install."
fi

log "STEP 10: Configuring LDAP properties (mode: ${LDAP_MODE})"
LDAP_PROPS="${IDP_HOME}/conf/ldap.properties"

sed -i "s|^#\?idp.authn.LDAP.authenticator\s*=.*|idp.authn.LDAP.authenticator = bindSearchAuthenticator|" "${LDAP_PROPS}"
sed -i "s|^#\?idp.authn.LDAP.ldapURL\s*=.*|idp.authn.LDAP.ldapURL = ${LDAP_URL}|"                         "${LDAP_PROPS}"
sed -i "s|^#\?idp.authn.LDAP.baseDN\s*=.*|idp.authn.LDAP.baseDN = ou=people,${BASE_DN}|"                  "${LDAP_PROPS}"
sed -i "s|^#\?idp.authn.LDAP.userFilter\s*=.*|idp.authn.LDAP.userFilter = (uid={user})|"                   "${LDAP_PROPS}"
sed -i "s|^#\?idp.authn.LDAP.bindDN\s*=.*|idp.authn.LDAP.bindDN = cn=admin,${BASE_DN}|"                   "${LDAP_PROPS}"
sed -i "s|^#\?idp.authn.LDAP.bindDNCredential\s*=.*|idp.authn.LDAP.bindDNCredential = ${LDAP_BIND_DN_PASSWORD}|" "${LDAP_PROPS}"
sed -i "s|^#\?idp.authn.LDAP.returnAttributes\s*=.*|idp.authn.LDAP.returnAttributes = *|"                  "${LDAP_PROPS}"
sed -i "s|^#\?idp.attribute.resolver.LDAP.returnAttributes\s*=.*|idp.attribute.resolver.LDAP.returnAttributes = %{idp.authn.LDAP.returnAttributes}|" "${LDAP_PROPS}"
sed -i "s|^#\?idp.attribute.resolver.LDAP.exportAttributes\s*=.*|idp.attribute.resolver.LDAP.exportAttributes = *|" "${LDAP_PROPS}"

case "$LDAP_MODE" in
  starttls)
    sed -i "s|^#\?idp.authn.LDAP.useStartTLS\s*=.*|idp.authn.LDAP.useStartTLS = true|"  "${LDAP_PROPS}"
    sed -i "s|^#\?idp.authn.LDAP.useSSL\s*=.*|idp.authn.LDAP.useSSL = false|"            "${LDAP_PROPS}"
    sed -i "s|^#\?idp.authn.LDAP.sslConfig\s*=.*|idp.authn.LDAP.sslConfig = certificateTrust|" "${LDAP_PROPS}"
    sed -i "s|^#\?idp.authn.LDAP.trustCertificates\s*=.*|idp.authn.LDAP.trustCertificates = %{idp.home}/credentials/ldap_server.crt|" "${LDAP_PROPS}"
    sed -i "s|^#\?idp.attribute.resolver.LDAP.trustCertificates\s*=.*|idp.attribute.resolver.LDAP.trustCertificates = %{idp.authn.LDAP.trustCertificates:undefined}|" "${LDAP_PROPS}"
    ;;
  tls)
    sed -i "s|^#\?idp.authn.LDAP.useStartTLS\s*=.*|idp.authn.LDAP.useStartTLS = false|" "${LDAP_PROPS}"
    sed -i "s|^#\?idp.authn.LDAP.useSSL\s*=.*|idp.authn.LDAP.useSSL = true|"             "${LDAP_PROPS}"
    sed -i "s|^#\?idp.authn.LDAP.sslConfig\s*=.*|idp.authn.LDAP.sslConfig = certificateTrust|" "${LDAP_PROPS}"
    sed -i "s|^#\?idp.authn.LDAP.trustCertificates\s*=.*|idp.authn.LDAP.trustCertificates = %{idp.home}/credentials/ldap_server.crt|" "${LDAP_PROPS}"
    sed -i "s|^#\?idp.attribute.resolver.LDAP.trustCertificates\s*=.*|idp.attribute.resolver.LDAP.trustCertificates = %{idp.authn.LDAP.trustCertificates:undefined}|" "${LDAP_PROPS}"
    ;;
  plain)
    sed -i "s|^#\?idp.authn.LDAP.useStartTLS\s*=.*|idp.authn.LDAP.useStartTLS = false|" "${LDAP_PROPS}"
    sed -i "s|^#\?idp.authn.LDAP.useSSL\s*=.*|idp.authn.LDAP.useSSL = false|"            "${LDAP_PROPS}"
    ;;
esac

# ============================================================
# STEP 11 — Attribute Resolver / Filter from LEARN
# ============================================================
log "STEP 11: Downloading LEARN attribute-resolver and attribute-filter"
wget -q https://fr.ac.lk/templates/attribute-resolver-LEARN-v5.xml \
     -O "${IDP_HOME}/conf/attribute-resolver-LEARN-v5.xml"
wget -q https://fr.ac.lk/templates/attribute-filter-LEARN-v5.xml  \
     -O "${IDP_HOME}/conf/attribute-filter-LEARN-v5.xml"

log "STEP 11: Patching schacHomeOrganizationType in attribute-resolver"
RESOLVER="${IDP_HOME}/conf/attribute-resolver-LEARN-v5.xml"
sed -i "s|urn:schac:homeOrganizationType:lk:others|${SCHAC_HOME_ORG_TYPE}|g" "${RESOLVER}"
# Update domain-specific values
sed -i "s|dc=YOUR-DOMAIN,dc=ac,dc=lk|${BASE_DN}|g" "${RESOLVER}"

log "STEP 11: Patching services.xml (attribute-resolver and filter)"
SERVICES="${IDP_HOME}/conf/services.xml"

# Switch to LEARN resolver
sed -i "s|%{idp.home}/conf/attribute-resolver.xml|%{idp.home}/conf/attribute-resolver-LEARN-v5.xml|g" \
       "${SERVICES}"

# Add Default-Filter bean and switch shibboleth.AttributeFilterResources
grep -q "Default-Filter" "${SERVICES}" || sed -i "s|</beans>|    <bean id=\"Default-Filter\" class=\"net.shibboleth.ext.spring.resource.FileBackedHTTPResource\"\n          c:client-ref=\"shibboleth.FileCachingHttpClient\"\n          c:url=\"https://fr.ac.lk/signedmetadata/files/attribute-filter-LEARN-v5.xml\"\n          c:backingFile=\"%{idp.home}/conf/attribute-filter-LEARN-v5.xml\"/>\n\n</beans>|" "${SERVICES}"

# Replace shibboleth.AttributeFilterResources list
# Use Python for multi-line XML replacement (more reliable than sed for blocks)
python3 - << PYEOF
import re, pathlib
f = pathlib.Path("${SERVICES}")
txt = f.read_text()
old = r'<util:list id\s*=\s*"shibboleth\.AttributeFilterResources"[^>]*>.*?</util:list>'
new = '''<util:list id ="shibboleth.AttributeFilterResources">
   <!--  <value>%{idp.home}/conf/attribute-filter.xml</value> -->
   <ref bean="Default-Filter"/>
</util:list>'''
txt2 = re.sub(old, new, txt, flags=re.DOTALL)
f.write_text(txt2)
print("services.xml AttributeFilterResources updated.")
PYEOF

# ============================================================
# STEP 12 — idp-metadata.xml (UIInfo, DisplayName)
# ============================================================
log "STEP 12: Patching idp-metadata.xml with institute name and description"
METADATA="${IDP_HOME}/metadata/idp-metadata.xml"

sed -i "s|<mdui:DisplayName xml:lang=\"en\">.*</mdui:DisplayName>|<mdui:DisplayName xml:lang=\"en\">${INSTITUTE_DISPLAY_NAME}</mdui:DisplayName>|" \
       "${METADATA}"
sed -i "s|<mdui:Description xml:lang=\"en\">.*</mdui:Description>|<mdui:Description xml:lang=\"en\">${INSTITUTE_DESCRIPTION}</mdui:Description>|" \
       "${METADATA}"

# ============================================================
# STEP 13 — Federation Metadata
# ============================================================
log "STEP 13: Downloading LEARN federation signing certificate"
wget -q https://fr.ac.lk/signedmetadata/metadata-signer \
     -O "${IDP_HOME}/metadata/federation-cert.pem"

log "STEP 13: Adding federation metadata providers to metadata-providers.xml"
META_PROVIDERS="${IDP_HOME}/conf/metadata-providers.xml"

grep -q "HTTPMD-LEARN-Federation" "${META_PROVIDERS}" || sed -i "s|</MetadataProvider>$|</MetadataProvider>\n\n    <!-- LEARN Federation metadata -->\n    <MetadataProvider id=\"HTTPMD-LEARN-Federation\"\n                      xsi:type=\"FileBackedHTTPMetadataProvider\"\n                      backingFile=\"%{idp.home}/metadata/test-metadata.xml\"\n                      metadataURL=\"https://fr.ac.lk/signedmetadata/metadata.xml\">\n        <MetadataFilter xsi:type=\"SignatureValidation\"\n                        requireSignedRoot=\"true\"\n                        certificateFile=\"%{idp.home}/metadata/federation-cert.pem\"/>\n        <MetadataFilter xsi:type=\"RequiredValidUntil\" maxValidityInterval=\"P10D\"/>\n        <MetadataFilter xsi:type=\"EntityRole\"><RetainedRole>md:SPSSODescriptor</RetainedRole></MetadataFilter>\n    </MetadataProvider>\n\n    <MetadataProvider id=\"HTTPMD-LEARN-interfederation\"\n                      xsi:type=\"FileBackedHTTPMetadataProvider\"\n                      backingFile=\"%{idp.home}/metadata/LEARNmetadata.xml\"\n                      metadataURL=\"https://fr.ac.lk/signedmetadata/LIAF-interfederation-sp-metadata.xml\">\n        <MetadataFilter xsi:type=\"SignatureValidation\"\n                        requireSignedRoot=\"true\"\n                        certificateFile=\"%{idp.home}/metadata/federation-cert.pem\"/>\n        <MetadataFilter xsi:type=\"RequiredValidUntil\" maxValidityInterval=\"P11D\"/>\n        <MetadataFilter xsi:type=\"EntityRole\"><RetainedRole>md:SPSSODescriptor</RetainedRole></MetadataFilter>\n    </MetadataProvider>|" "${META_PROVIDERS}"

# ============================================================
# STEP 14 — logback.xml LDAP debug entries
# ============================================================
log "STEP 14: Adding LDAP loggers to logback.xml"
LOGBACK="${IDP_HOME}/conf/logback.xml"

grep -q "org.ldaptive.auth.Authenticator" "${LOGBACK}" || sed -i "s|</configuration>|    <!-- Logs LDAP related messages -->\n    <logger name=\"org.ldaptive\" level=\"\${idp.loglevel.ldap:-WARN}\"/>\n    <!-- Logs on LDAP user authentication -->\n    <logger name=\"org.ldaptive.auth.Authenticator\" level=\"INFO\" />\n\n</configuration>|" "${LOGBACK}"

# ============================================================
# STEP 15 — Build the WAR
# ============================================================
log "STEP 15: Building IdP WAR file"
cd "${IDP_HOME}"
bin/build.sh
chown -R jetty:jetty "${IDP_HOME}"

# ============================================================
# STEP 16 — Grant port-binding capability to Java
# ============================================================
log "STEP 16: Granting cap_net_bind_service to Java binary"
JAVA_BIN="/usr/lib/jvm/java-17-openjdk-amd64/bin/java"
setcap cap_net_bind_service=+eip "${JAVA_BIN}"
getcap "${JAVA_BIN}"

# ============================================================
# STEP 17 — systemd service for Jetty
# ============================================================
log "STEP 17: Creating Jetty systemd service"
cat > /etc/systemd/system/jetty.service << 'SVCEOF'
[Unit]
Description=Jetty 12 Web Server (Shibboleth IdP)
After=network.target

[Service]
Type=simple
User=jetty
Group=jetty
WorkingDirectory=/opt/jetty-base
Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64"
ExecStart=/usr/lib/jvm/java-17-openjdk-amd64/bin/java \
  -Xms512m \
  -Xmx1024m \
  -XX:+UseG1GC \
  -DIDP_HOME=/opt/shibboleth-idp \
  -Djetty.home=/opt/jetty-home \
  -Djetty.base=/opt/jetty-base \
  -jar /opt/jetty-home/start.jar
Restart=on-failure
RestartSec=5
StandardOutput=append:/var/log/jetty/jetty.log
StandardError=append:/var/log/jetty/jetty-error.log

[Install]
WantedBy=multi-user.target
SVCEOF

log "STEP 17: Enabling and starting Jetty"
systemctl daemon-reload
systemctl enable jetty
systemctl start jetty
sleep 10
systemctl status jetty --no-pager

# ============================================================
# STEP 18 — Verification
# ============================================================
log "STEP 18: Verifying installation"
echo ""
echo "--- Port check ---"
ss -tlnp | grep -E '80|443' || true

echo ""
echo "--- IdP status ---"
curl -sk --resolve "${IDP_FQDN}:443:127.0.0.1" \
  "https://${IDP_FQDN}/idp/status" || \
  warn "IdP status check failed. Check logs: tail -f ${IDP_HOME}/logs/idp-process.log"

echo ""
echo "--- Shibboleth version in log ---"
grep -m1 "Shibboleth IdP" "${IDP_HOME}/logs/idp-process.log" 2>/dev/null || true

echo ""
echo "============================================================"
echo " Installation complete!"
echo " IdP metadata: https://${IDP_FQDN}/idp/shibboleth"
echo " Test SP:      https://sp-test.liaf.ac.lk"
echo " Federation:   https://liaf.ac.lk/"
echo ""
echo " NEXT: Register at https://liaf.ac.lk/ using your metadata"
echo "       from https://${IDP_FQDN}/idp/shibboleth"
echo "============================================================"
