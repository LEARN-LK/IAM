#!/usr/bin/env bash
# =============================================================================
# install-idp5.sh
#
# Shibboleth IdP 5 + Jetty 12 (listening on 127.0.0.1:8080) behind Apache 2,
# on Ubuntu 22.04 / 24.04.  Based on the LEARN "installing-idp-v4" manual
# workflow, adapted for IdP 5 / Jetty 12 (ee9) and Apache as reverse proxy.
#
# Usage:
#   sudo ./install-idp5.sh                  # interactive, prompts for values
#   sudo ./install-idp5.sh -e idp5.env      # read values from an env file
#   sudo ./install-idp5.sh -e idp5.env -y   # non-interactive (fails if a
#                                           # required value is missing)
#
# The script is re-runnable: already-completed work is skipped or re-applied
# idempotently.  Full log: /var/log/idp5-install.log
# =============================================================================
set -Eeuo pipefail
trap 'echo "ERROR: line ${LINENO}: \"${BASH_COMMAND}\" failed (exit $?)" >&2' ERR

ENV_FILE=""
ASSUME_YES="no"
LOG_FILE="/var/log/idp5-install.log"
SECRETS_NOTE="/root/idp5-install-secrets.txt"

# ----------------------------------------------------------------------------
# Small helpers
# ----------------------------------------------------------------------------
log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

usage() {
  sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

confirm() { # confirm "question"   -> 0 = yes
  local a
  if [[ "$ASSUME_YES" == "yes" ]]; then return 0; fi
  read -r -p "$1 [y/N]: " a
  [[ "$a" =~ ^[Yy] ]]
}

# ask VAR "Prompt" "default" [flags]    flags: s = secret input, o = optional
# A value already present in the environment / env file is never re-asked.
ask() {
  local var="$1" prompt="$2" def="${3:-}" flags="${4:-}" val=""
  if [[ -n "${!var:-}" ]]; then return 0; fi
  if [[ "$ASSUME_YES" == "yes" ]]; then
    if [[ -n "$def" || "$flags" == *o* ]]; then
      printf -v "$var" '%s' "$def"
      return 0
    fi
    die "Missing required value ${var} (non-interactive mode). Set it in the env file."
  fi
  while true; do
    if [[ "$flags" == *s* ]]; then
      read -r -s -p "${prompt}: " val; echo
    else
      read -r -p "${prompt}${def:+ [${def}]}: " val
    fi
    val="${val:-$def}"
    if [[ -n "$val" || "$flags" == *o* ]]; then break; fi
    echo "  A value is required."
  done
  printf -v "$var" '%s' "$val"
}

rand_hex()    { openssl rand -hex "${1:-24}"; }
rand_base64() { openssl rand -base64 "${1:-36}"; }

# set_prop FILE KEY VALUE
#   Replace "KEY = ..." (or the first commented "# KEY = ...") in a .properties
#   file, or append it.  Backslashes in VALUE are escaped for .properties.
set_prop() {
  python3 - "$1" "$2" "$3" <<'PY'
import re, sys
path, key, value = sys.argv[1:4]
value = value.replace('\\', '\\\\')
new = f"{key} = {value}\n"
try:
    with open(path, encoding='utf-8') as fh:
        lines = fh.readlines()
except FileNotFoundError:
    lines = []
act = re.compile(r'^\s*' + re.escape(key) + r'\s*[=:]')
com = re.compile(r'^\s*#+\s*' + re.escape(key) + r'\s*[=:]')
hit = [i for i, l in enumerate(lines) if act.match(l)]
if hit:
    for n, i in enumerate(hit):
        lines[i] = new if n == 0 else '# (duplicate removed) ' + lines[i]
else:
    c = [i for i, l in enumerate(lines) if com.match(l)]
    if c:
        lines[c[0]] = new
    else:
        if lines and not lines[-1].endswith('\n'):
            lines[-1] += '\n'
        lines.append(new)
with open(path, 'w', encoding='utf-8') as fh:
    fh.writelines(lines)
PY
}

# has_prop FILE KEY  -> 0 if an active (uncommented) KEY exists
has_prop() { grep -Eq "^[[:space:]]*${2//./\\.}[[:space:]]*[=:]" "$1" 2>/dev/null; }

# insert_xml FILE CLOSING_TAG MARKER   (snippet on stdin)
#   Inserts the snippet before the LAST occurrence of CLOSING_TAG, once only
#   (MARKER must appear inside the snippet).
insert_xml() {
  local file="$1" close="$2" marker="$3" snip
  snip="$(mktemp)"; cat >"$snip"
  if grep -qF "$marker" "$file"; then rm -f "$snip"; return 0; fi
  python3 - "$file" "$close" "$snip" <<'PY'
import sys
path, close, snip = sys.argv[1:4]
text = open(path, encoding='utf-8').read()
add = open(snip, encoding='utf-8').read()
i = text.rfind(close)
if i < 0:
    sys.exit(f"closing tag {close} not found in {path}")
open(path, 'w', encoding='utf-8').write(text[:i] + add.rstrip('\n') + '\n' + text[i:])
PY
  rm -f "$snip"
}

# uncomment_ref FILE BEAN  -> turns  <!-- <ref bean="BEAN" /> -->  into  <ref bean="BEAN" />
uncomment_ref() {
  python3 - "$1" "$2" <<'PY'
import re, sys
path, bean = sys.argv[1:3]
text = open(path, encoding='utf-8').read()
pat = re.compile(r'<!--\s*(<ref\s+bean="' + re.escape(bean) + r'"\s*/>)\s*-->')
new, n = pat.subn(r'\1', text)
if n:
    open(path, 'w', encoding='utf-8').write(new)
    print(f"    enabled {bean} in {path}")
elif re.search(r'<ref\s+bean="' + re.escape(bean) + r'"\s*/>', text):
    print(f"    {bean} already enabled in {path}")
else:
    print(f"    WARNING: {bean} not found in {path}; enable it manually", file=sys.stderr)
PY
}

verify_hash() { # file algo(sha1|sha256) expected
  local actual
  actual="$("$2"sum "$1" | awk '{print $1}')"
  [[ "${actual,,}" == "${3,,}" ]] || die "Checksum mismatch for $1 ($2 expected $3, got $actual)"
}

maven_jar() { # group_path artifact version dest_dir   (downloads + verifies sha1)
  local url="$MAVEN/$1/$2/$3/$2-$3.jar" dest="$4/$2-$3.jar" sum
  if [[ -s "$dest" ]]; then info "have $(basename "$dest")"; return 0; fi
  curl -fsSL -o "$dest" "$url" || die "Download failed: $url"
  sum="$(curl -fsSL "$url.sha1" | grep -oiE '[0-9a-f]{40}' | head -n1 || true)"
  [[ -n "$sum" ]] || die "Could not fetch checksum for $url"
  verify_hash "$dest" sha1 "$sum"
  info "downloaded + verified $(basename "$dest")"
}

# ----------------------------------------------------------------------------
# Configuration: defaults, prompts, validation
# ----------------------------------------------------------------------------
set_defaults() {
  : "${IDP_VERSION:=5.1.6}"
  : "${JETTY_VERSION:=12.1.5}"
  : "${JAVA_PACKAGE:=java-17-amazon-corretto-jdk}"
  : "${JAVA_HOME_DIR:=/usr/lib/jvm/java-17-amazon-corretto}"
  : "${MARIADB_JDBC_VERSION:=3.5.10}"
  : "${DBCP2_VERSION:=2.13.0}"
  : "${POOL2_VERSION:=2.12.0}"
  : "${IDP_HOME:=/opt/shibboleth-idp}"
  : "${JETTY_BASE:=/opt/jetty}"
  : "${SRC_DIR:=/usr/local/src}"
  : "${JETTY_HTTP_PORT:=8080}"
  : "${JETTY_XMX:=1500m}"
  MAVEN="https://repo1.maven.org/maven2"
  JETTY_HOME_LINK="$SRC_DIR/jetty-src"
}

collect_settings() {
  log "Configuration"
  info "Press Enter to accept a [default]. Values can be pre-set with an env file (-e)."
  echo

  ask IDP_FQDN       "IdP host name (FQDN), e.g. idp.inst.ac.lk"
  [[ "$IDP_FQDN" =~ ^([A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,}$ ]] || die "Invalid FQDN: $IDP_FQDN"

  local guess="${IDP_FQDN#*.}"
  ask IDP_SCOPE      "Attribute scope / domain (schacHomeOrganization), e.g. inst.ac.lk" "$guess"
  ask IDP_ENTITY_ID  "IdP entityID" "https://${IDP_FQDN}/idp/shibboleth"
  ask ORG_NAME       "Organisation name for login page title/footer (optional)" "" o

  echo
  ask LDAP_URL       "LDAP URL (ldap://host:389 or ldaps://host:636)"
  [[ "$LDAP_URL" =~ ^ldaps?://[^/[:space:]]+ ]] || die "LDAP_URL must start with ldap:// or ldaps://"
  local def_sec="starttls"; [[ "$LDAP_URL" == ldaps://* ]] && def_sec="ldaps"
  ask LDAP_SECURITY  "LDAP security: starttls | ldaps | plain" "$def_sec"
  case "$LDAP_SECURITY" in starttls|ldaps|plain) ;; *) die "LDAP_SECURITY must be starttls, ldaps or plain";; esac
  ask LDAP_BASE_DN   "LDAP base DN for users, e.g. ou=people,dc=inst,dc=ac,dc=lk"
  ask LDAP_BIND_DN   "LDAP bind DN, e.g. cn=admin,dc=inst,dc=ac,dc=lk"
  ask LDAP_BIND_PASSWORD "LDAP bind password" "" s
  ask LDAP_USER_FILTER   "LDAP user filter ({user} = login name)" "(uid={user})"
  if [[ "$LDAP_SECURITY" != "plain" ]]; then
    ask LDAP_CERT_FILE "Path to LDAP server certificate (PEM) for trust; blank = use Java trust store" "" o
    if [[ -n "${LDAP_CERT_FILE:-}" && ! -r "$LDAP_CERT_FILE" ]]; then die "Cannot read LDAP_CERT_FILE: $LDAP_CERT_FILE"; fi
  fi
  ask PERSISTENT_ID_SOURCE "Attribute used as source for persistent-id" "uid"

  echo
  ask DB_NAME        "MariaDB database name" "storageservice"
  ask DB_USER        "MariaDB user" "idp_admin"
  [[ "$DB_NAME" =~ ^[A-Za-z0-9_]+$ && "$DB_USER" =~ ^[A-Za-z0-9_]+$ ]] || die "DB_NAME / DB_USER may only contain letters, digits and _"
  if [[ -z "${DB_PASSWORD:-}" && -f "$IDP_HOME/credentials/secrets.properties" ]]; then
    DB_PASSWORD="$(sed -n 's/^[[:space:]]*idp\.storage\.dbpassword[[:space:]]*=[[:space:]]*//p' "$IDP_HOME/credentials/secrets.properties" | head -n1 || true)"
    [[ -n "$DB_PASSWORD" ]] && info "Re-using existing DB password from secrets.properties"
  fi
  ask DB_PASSWORD    "MariaDB password for ${DB_USER} (blank = generate)" "" "so"
  if [[ -z "$DB_PASSWORD" ]]; then DB_PASSWORD="$(rand_hex 20)"; fi
  [[ "$DB_PASSWORD" != *"'"* && "$DB_PASSWORD" != *'\'* ]] || die "DB password must not contain ' or \\"

  echo
  ask TLS_MODE       "Apache TLS: letsencrypt | selfsigned | existing" "letsencrypt"
  case "$TLS_MODE" in
    letsencrypt) ask LE_EMAIL "Let's Encrypt contact e-mail (blank = none)" "" o ;;
    selfsigned)  ;;
    existing)
      ask TLS_CERT_FILE  "Path to certificate (full chain preferred)"
      ask TLS_KEY_FILE   "Path to private key"
      ask TLS_CHAIN_FILE "Path to intermediate chain (optional)" "" o
      [[ -r "$TLS_CERT_FILE" && -r "$TLS_KEY_FILE" ]] || die "Cannot read TLS_CERT_FILE / TLS_KEY_FILE" ;;
    *) die "TLS_MODE must be letsencrypt, selfsigned or existing" ;;
  esac

  echo
  ask CONFIGURE_LEARN "Configure LEARN/LIAF federation metadata + attribute files? (yes/no)" "no"
  if [[ "$CONFIGURE_LEARN" == "yes" ]]; then
    ask HOME_ORG_TYPE "schacHomeOrganizationType (urn:schac:homeOrganizationType:int:university | library | public-research-institution | private-research-institution)" \
        "urn:schac:homeOrganizationType:int:university"
  fi

  echo
  log "Summary"
  info "IdP FQDN        : $IDP_FQDN"
  info "Scope           : $IDP_SCOPE"
  info "EntityID        : $IDP_ENTITY_ID"
  info "LDAP            : $LDAP_URL ($LDAP_SECURITY), base $LDAP_BASE_DN"
  info "Database        : $DB_NAME / $DB_USER"
  info "TLS             : $TLS_MODE"
  info "IdP / Jetty     : $IDP_VERSION / $JETTY_VERSION  (home $IDP_HOME, jetty base $JETTY_BASE)"
  info "LEARN federation: $CONFIGURE_LEARN"
  confirm "Continue with the installation?" || die "Aborted."
}

# ----------------------------------------------------------------------------
# Steps
# ----------------------------------------------------------------------------
step_preflight() {
  log "Pre-flight checks"
  [[ $EUID -eq 0 ]] || die "Run as root (sudo)."
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    [[ "${ID:-}" == "ubuntu" || "${ID:-}" == "debian" ]] || warn "Untested OS (${PRETTY_NAME:-unknown}); script targets Ubuntu 22.04/24.04."
    info "OS: ${PRETTY_NAME:-unknown}"
  fi
  if ss -ltn "( sport = :${JETTY_HTTP_PORT} )" 2>/dev/null | grep -q LISTEN \
     && ! systemctl is-active --quiet jetty-idp; then
    die "Port ${JETTY_HTTP_PORT} is already in use by another service. Set JETTY_HTTP_PORT to a free port."
  fi
  getent hosts "$IDP_FQDN" >/dev/null 2>&1 || warn "$IDP_FQDN does not resolve from this server yet (needed for Let's Encrypt)."
}

step_packages() {
  log "Installing packages"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  local pkgs=(apache2 mariadb-server wget curl gnupg ca-certificates openssl chrony unzip python3 iproute2)
  [[ "$TLS_MODE" == "letsencrypt" ]] && pkgs+=(certbot python3-certbot-apache)
  apt-get install -y --no-install-recommends "${pkgs[@]}"
}

step_java() {
  log "Java (Amazon Corretto 17)"
  if [[ -x "$JAVA_HOME_DIR/bin/java" ]]; then info "Found $JAVA_HOME_DIR"; else
    curl -fsSL https://apt.corretto.aws/corretto.key | gpg --dearmor -o /usr/share/keyrings/corretto-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" \
      > /etc/apt/sources.list.d/corretto.list
    apt-get update -y
    apt-get install -y "$JAVA_PACKAGE"
  fi
  [[ -x "$JAVA_HOME_DIR/bin/java" ]] || die "Java not found at $JAVA_HOME_DIR (set JAVA_HOME_DIR)."
  export JAVA_HOME="$JAVA_HOME_DIR"
  "$JAVA_HOME/bin/java" -version 2>&1 | sed 's/^/    /'
  # NOTE: /etc/environment and the system-wide default java are deliberately NOT
  # changed, so other sites on this server keep their own Java setup.
}

step_jetty_user() {
  log "System user 'jetty'"
  getent passwd jetty >/dev/null || useradd -r -M -s /usr/sbin/nologin jetty
}

step_database() {
  log "MariaDB database for persistent-id and storage (consent)"
  systemctl enable --now mariadb
  mysql <<SQL
DROP DATABASE IF EXISTS test;
DROP USER IF EXISTS ''@'localhost';
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
USE \`${DB_NAME}\`;
CREATE TABLE IF NOT EXISTS shibpid (
  localEntity      VARCHAR(255) NOT NULL,
  peerEntity       VARCHAR(255) NOT NULL,
  persistentId     VARCHAR(50)  NOT NULL,
  principalName    VARCHAR(50)  NOT NULL,
  localId          VARCHAR(50)  NOT NULL,
  peerProvidedId   VARCHAR(50)  NULL,
  creationDate     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deactivationDate TIMESTAMP    NULL,
  PRIMARY KEY (localEntity, peerEntity, persistentId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
CREATE TABLE IF NOT EXISTS StorageRecords (
  context VARCHAR(255) NOT NULL,
  id      VARCHAR(255) NOT NULL,
  expires BIGINT DEFAULT NULL,
  value   LONGTEXT NOT NULL,
  version BIGINT NOT NULL,
  PRIMARY KEY (context, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
SQL
  info "Database '${DB_NAME}' and tables shibpid / StorageRecords are ready."
}

step_idp_install() {
  log "Shibboleth IdP ${IDP_VERSION}"
  if [[ -f "$IDP_HOME/conf/idp.properties" ]]; then
    info "IdP already installed in $IDP_HOME - skipping installer (upgrades are a separate procedure)."
    return 0
  fi
  local tgz="$SRC_DIR/shibboleth-identity-provider-${IDP_VERSION}.tar.gz"
  local url="${IDP_URL:-https://shibboleth.net/downloads/identity-provider/${IDP_VERSION}/shibboleth-identity-provider-${IDP_VERSION}.tar.gz}"
  local src="$SRC_DIR/shibboleth-identity-provider-${IDP_VERSION}"

  if [[ ! -s "$tgz" ]]; then curl -fsSL -o "$tgz" "$url" || die "Download failed: $url"; fi

  local expected="${IDP_SHA256:-}"
  if [[ -z "$expected" ]]; then
    expected="$(curl -fsSL "${url}.sha256" 2>/dev/null | grep -oiE '[0-9a-f]{64}' | head -n1 || true)"
  fi
  if [[ -n "$expected" ]]; then
    verify_hash "$tgz" sha256 "$expected"; info "SHA-256 verified."
  else
    warn "No SHA-256 available for the IdP tarball (set IDP_SHA256 to enforce)."
    if [[ "${ALLOW_UNVERIFIED:-no}" != "yes" ]]; then confirm "Continue WITHOUT checksum verification?" || die "Aborted."; fi
  fi

  [[ -d "$src" ]] || tar -xzf "$tgz" -C "$SRC_DIR"

  SEALER_PASSWORD="$(rand_hex 24)"
  BACKCHANNEL_PASSWORD="$(rand_hex 24)"
  local props; props="$(umask 077; mktemp)"
  cat >"$props" <<EOF
idp.target.dir = $IDP_HOME
idp.entityID = $IDP_ENTITY_ID
idp.host.name = $IDP_FQDN
idp.scope = $IDP_SCOPE
idp.initial.modules = idp.authn.Password,idp.intercept.Consent
idp.sealer.password = $SEALER_PASSWORD
idp.keystore.password = $BACKCHANNEL_PASSWORD
EOF
  JAVA_HOME="$JAVA_HOME_DIR" bash "$src/bin/install.sh" --propertyFile "$props" --noPrompt
  shred -u "$props" 2>/dev/null || rm -f "$props"
  [[ -f "$IDP_HOME/conf/idp.properties" ]] || die "IdP installer did not create $IDP_HOME"
}

step_jetty_install() {
  log "Jetty ${JETTY_VERSION} (ee9) on 127.0.0.1:${JETTY_HTTP_PORT}"
  local jhome="$SRC_DIR/jetty-home-${JETTY_VERSION}"
  local tgz="$SRC_DIR/jetty-home-${JETTY_VERSION}.tar.gz"
  local url="$MAVEN/org/eclipse/jetty/jetty-home/${JETTY_VERSION}/jetty-home-${JETTY_VERSION}.tar.gz"

  if [[ ! -d "$jhome" ]]; then
    curl -fsSL -o "$tgz" "$url" || die "Download failed: $url"
    local sum; sum="$(curl -fsSL "$url.sha1" | grep -oiE '[0-9a-f]{40}' | head -n1 || true)"
    [[ -n "$sum" ]] || die "Could not fetch Jetty checksum"
    verify_hash "$tgz" sha1 "$sum"; info "SHA-1 verified."
    tar -xzf "$tgz" -C "$SRC_DIR"
  fi
  ln -nsf "jetty-home-${JETTY_VERSION}" "$JETTY_HOME_LINK"

  install -d -o jetty -g jetty "$JETTY_BASE" "$JETTY_BASE/tmp" "$JETTY_BASE/webapps" /var/log/jetty
  ln -nsf /var/log/jetty "$JETTY_BASE/logs" 2>/dev/null || true

  if [[ ! -d "$JETTY_BASE/start.d" ]]; then
    ( cd "$JETTY_BASE" && runuser -u jetty -- env JAVA_HOME="$JAVA_HOME_DIR" \
        "$JAVA_HOME_DIR/bin/java" -Djetty.home="$JETTY_HOME_LINK" -Djetty.base="$JETTY_BASE" \
        -jar "$JETTY_HOME_LINK/start.jar" --create-startd --approve-all-licenses \
        --add-modules=server,http,http-forwarded,ext,resources,logging-logback,ee9-deploy,ee9-annotations,ee9-plus,ee9-jsp,ee9-jstl,ee9-servlets )
  else
    info "Jetty base already initialised ($JETTY_BASE/start.d)"
  fi

  cat >"$JETTY_BASE/start.d/idp-local.ini" <<EOF
# Jetty listens on localhost only; Apache terminates TLS and proxies /idp here.
jetty.http.host=127.0.0.1
jetty.http.port=${JETTY_HTTP_PORT}
jetty.httpConfig.sendServerVersion=false
EOF

  cat >"$JETTY_BASE/webapps/idp.xml" <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE Configure PUBLIC "-//Jetty//Configure//EN" "https://www.eclipse.org/jetty/configure_10_0.dtd">
<Configure class="org.eclipse.jetty.ee9.webapp.WebAppContext">
  <Set name="war"><SystemProperty name="idp.home"/>/war/idp.war</Set>
  <Set name="contextPath">/idp</Set>
  <Set name="extractWAR">false</Set>
  <Set name="copyWebDir">false</Set>
  <Set name="copyWebInf">true</Set>
  <Set name="persistTempDirectory">false</Set>
</Configure>
EOF

  cat >/etc/systemd/system/jetty-idp.service <<EOF
[Unit]
Description=Jetty ${JETTY_VERSION} - Shibboleth IdP
After=network.target mariadb.service

[Service]
User=jetty
Group=jetty
WorkingDirectory=${JETTY_BASE}
ExecStartPre=/bin/sh -c 'rm -rf ${JETTY_BASE}/tmp/*'
ExecStart=${JAVA_HOME_DIR}/bin/java -Xmx${JETTY_XMX} -Djava.security.egd=file:/dev/urandom -Didp.home=${IDP_HOME} -Djava.io.tmpdir=${JETTY_BASE}/tmp -Djetty.home=${JETTY_HOME_LINK} -Djetty.base=${JETTY_BASE} -jar ${JETTY_HOME_LINK}/start.jar
Restart=on-failure
RestartSec=5
SuccessExitStatus=143
TimeoutStartSec=300
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  chown -R jetty:jetty "$JETTY_BASE"
}

# Is a jar (name prefix) inside idp.war?
WAR_LIST=""
refresh_war_list() { WAR_LIST="$(mktemp)"; unzip -Z1 "$IDP_HOME/war/idp.war" >"$WAR_LIST"; }
war_has() { grep -q "WEB-INF/lib/$1" "$WAR_LIST"; }

step_plugin_libs() {
  log "JDBC storage plugin + JDBC libraries"
  export JAVA_HOME="$JAVA_HOME_DIR"
  local plugin="net.shibboleth.plugin.storage.jdbc" listing
  listing="$("$IDP_HOME/bin/plugin.sh" -l 2>&1 || true)"
  if grep -q "$plugin" <<<"$listing"; then
    info "Plugin $plugin already installed."
  else
    "$IDP_HOME/bin/plugin.sh" -I "$plugin" --noPrompt \
      || die "Plugin install failed. Run manually:  $IDP_HOME/bin/plugin.sh -I $plugin   then re-run this script."
  fi

  local libs="$SRC_DIR/idp-libs" web="$IDP_HOME/edit-webapp/WEB-INF/lib"
  install -d "$libs" "$web"
  maven_jar org/mariadb/jdbc/mariadb-java-client "mariadb-java-client" "$MARIADB_JDBC_VERSION" "$libs"
  cp -f "$libs/mariadb-java-client-${MARIADB_JDBC_VERSION}.jar" "$web/"

  log "Building idp.war"
  "$IDP_HOME/bin/build.sh"
  refresh_war_list

  local rebuild=no
  if ! war_has "commons-dbcp2-"; then
    maven_jar org/apache/commons/commons-dbcp2 commons-dbcp2 "$DBCP2_VERSION" "$libs"
    cp -f "$libs/commons-dbcp2-${DBCP2_VERSION}.jar" "$web/"; rebuild=yes
  fi
  if ! war_has "commons-pool2-"; then
    maven_jar org/apache/commons/commons-pool2 commons-pool2 "$POOL2_VERSION" "$libs"
    cp -f "$libs/commons-pool2-${POOL2_VERSION}.jar" "$web/"; rebuild=yes
  fi
  if ! war_has "spring-jdbc-"; then
    local sv; sv="$(grep -oE 'WEB-INF/lib/spring-core-[0-9][0-9.]*\.jar' "$WAR_LIST" | head -n1 | sed -E 's/.*spring-core-(.*)\.jar/\1/' || true)"
    [[ -n "$sv" ]] || die "Cannot determine the Spring version bundled with the IdP."
    maven_jar org/springframework/spring-jdbc spring-jdbc "$sv" "$libs"
    cp -f "$libs/spring-jdbc-${sv}.jar" "$web/"; rebuild=yes
  fi
  if [[ "$rebuild" == "yes" ]]; then
    log "Rebuilding idp.war with the missing libraries"
    "$IDP_HOME/bin/build.sh"
    refresh_war_list
  fi
  for j in mariadb-java-client commons-dbcp2 commons-pool2 spring-jdbc; do
    war_has "$j-" && info "idp.war contains $j" || die "idp.war is missing $j"
  done
  rm -f "$WAR_LIST"
}

step_idp_config() {
  log "Configuring the IdP (LDAP, persistent-id, consent, storage)"
  local conf="$IDP_HOME/conf" cred="$IDP_HOME/credentials"
  local bak; bak="$IDP_HOME/conf-backup-$(date +%Y%m%d%H%M%S)"
  cp -a "$conf" "$bak"; info "Backup of conf/: $bak"

  # ---- LDAP ---------------------------------------------------------------
  local startTLS=false useSSL=false
  [[ "$LDAP_SECURITY" == "starttls" ]] && startTLS=true
  [[ "$LDAP_SECURITY" == "ldaps"    ]] && useSSL=true
  set_prop "$conf/ldap.properties" idp.authn.LDAP.authenticator "bindSearchAuthenticator"
  set_prop "$conf/ldap.properties" idp.authn.LDAP.ldapURL       "$LDAP_URL"
  set_prop "$conf/ldap.properties" idp.authn.LDAP.useStartTLS   "$startTLS"
  set_prop "$conf/ldap.properties" idp.authn.LDAP.useSSL        "$useSSL"
  if [[ "$LDAP_SECURITY" != "plain" ]]; then
    if [[ -n "${LDAP_CERT_FILE:-}" ]]; then
      install -m 0644 -o jetty -g jetty "$LDAP_CERT_FILE" "$cred/ldap_server.crt"
      set_prop "$conf/ldap.properties" idp.authn.LDAP.sslConfig         "certificateTrust"
      set_prop "$conf/ldap.properties" idp.authn.LDAP.trustCertificates '%{idp.home}/credentials/ldap_server.crt'
    else
      set_prop "$conf/ldap.properties" idp.authn.LDAP.sslConfig "jvmTrust"
    fi
  fi
  set_prop "$conf/ldap.properties" idp.authn.LDAP.baseDN          "$LDAP_BASE_DN"
  set_prop "$conf/ldap.properties" idp.authn.LDAP.userFilter      "$LDAP_USER_FILTER"
  set_prop "$conf/ldap.properties" idp.authn.LDAP.bindDN          "$LDAP_BIND_DN"
  set_prop "$conf/ldap.properties" idp.authn.LDAP.returnAttributes "*"
  local principal='$resolutionContext.principal'
  set_prop "$conf/ldap.properties" idp.attribute.resolver.LDAP.searchFilter "${LDAP_USER_FILTER//\{user\}/$principal}"
  # bind password lives in secrets.properties (not in ldap.properties)
  set_prop "$cred/secrets.properties" idp.authn.LDAP.bindDNCredential "$LDAP_BIND_PASSWORD"

  # ---- Secrets: DB password + persistent-id salt ---------------------------
  set_prop "$cred/secrets.properties" idp.storage.dbpassword "$DB_PASSWORD"
  if ! has_prop "$cred/secrets.properties" idp.persistentId.salt; then
    set_prop "$cred/secrets.properties" idp.persistentId.salt "$(rand_base64 36)"
  fi

  # ---- Persistent-id (stored mode) ----------------------------------------
  set_prop "$conf/saml-nameid.properties" idp.persistentId.sourceAttribute "$PERSISTENT_ID_SOURCE"
  set_prop "$conf/saml-nameid.properties" idp.persistentId.generator       "MyPersistentIdStore"
  uncomment_ref "$conf/saml-nameid.xml"        "shibboleth.SAML2PersistentGenerator"
  uncomment_ref "$conf/c14n/subject-c14n.xml"  "c14n/SAML2Persistent"

  # ---- Consent + session tracking -----------------------------------------
  set_prop "$conf/idp.properties" idp.consent.StorageService        "idp.JDBCConsentStorage"
  set_prop "$conf/idp.properties" idp.consent.compareValues         "true"
  set_prop "$conf/idp.properties" idp.consent.maxStoredRecords      "-1"
  set_prop "$conf/idp.properties" idp.consent.storageRecordLifetime "P1Y"
  set_prop "$conf/idp.properties" idp.session.trackSPSessions       "true"
  set_prop "$conf/idp.properties" idp.session.secondaryServiceIndex "true"

  # ---- Beans: data sources, JDBC storage service, persistent-id store ------
  local jdbc_url="jdbc:mariadb://127.0.0.1:3306/${DB_NAME}?autoReconnect=true&amp;sslMode=disable"
  insert_xml "$conf/global.xml" "</beans>" "LEARN-IDP5-JDBC" <<EOF

    <!-- LEARN-IDP5-JDBC: JDBC storage (consent) and persistent-id data sources -->
    <bean id="idp.JDBCConsentStorage"
          parent="shibboleth.JDBCStorageService"
          p:cleanupInterval="%{idp.storage.cleanupInterval:PT10M}"
          p:dataSource-ref="idp.JDBC.DataSource" />

    <!-- Two separate pools so a problem in one component cannot starve the other -->
    <bean id="idp.JDBC.DataSource"
          class="org.apache.commons.dbcp2.BasicDataSource" destroy-method="close" lazy-init="true"
          p:driverClassName="org.mariadb.jdbc.Driver"
          p:url="${jdbc_url}"
          p:username="${DB_USER}"
          p:password="%{idp.storage.dbpassword}"
          p:maxIdle="5"
          p:maxWaitMillis="15000"
          p:testOnBorrow="true"
          p:validationQuery="select 1"
          p:validationQueryTimeout="5" />

    <bean id="idp.JDBC.PersistentDataSource"
          class="org.apache.commons.dbcp2.BasicDataSource" destroy-method="close" lazy-init="true"
          p:driverClassName="org.mariadb.jdbc.Driver"
          p:url="${jdbc_url}"
          p:username="${DB_USER}"
          p:password="%{idp.storage.dbpassword}"
          p:maxIdle="5"
          p:maxWaitMillis="15000"
          p:testOnBorrow="true"
          p:validationQuery="select 1"
          p:validationQueryTimeout="5" />
EOF
  insert_xml "$conf/saml-nameid.xml" "</beans>" "LEARN-IDP5-PERSISTENTID" <<'EOF'

    <!-- LEARN-IDP5-PERSISTENTID: stored persistent-id generator -->
    <bean id="MyPersistentIdStore" parent="shibboleth.StoredPersistentIdGenerator"
          p:dataSource-ref="idp.JDBC.PersistentDataSource"
          p:queryTimeout="PT2S"
          p:retryableErrors="#{ {'23000'} }" />
EOF

  # ---- Log authentication errors from LDAP ---------------------------------
  insert_xml "$conf/logback.xml" "</configuration>" "LEARN-IDP5-LDAPLOG" <<'EOF'

    <!-- LEARN-IDP5-LDAPLOG: log LDAP authentication outcomes -->
    <logger name="org.ldaptive.auth.Authenticator" level="INFO" />
EOF

  # ---- Optional branding strings -------------------------------------------
  if [[ -n "${ORG_NAME:-}" ]]; then
    local msg="$IDP_HOME/messages/messages.properties"
    set_prop "$msg" idp.title          "${ORG_NAME} Login Service"
    set_prop "$msg" idp.logo.alt-text  "${ORG_NAME} logo"
    set_prop "$msg" idp.footer         "Copyright ${ORG_NAME}"
    set_prop "$msg" root.footer        "Copyright ${ORG_NAME}"
  fi

  # ---- idp-metadata.xml: drop the unused :8443 endpoints --------------------
  local md="$IDP_HOME/metadata/idp-metadata.xml"
  if [[ -f "$md" ]]; then
    python3 - "$md" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
pat = re.compile(r'[ \t]*<(?:\w+:)?(?:ArtifactResolutionService|AttributeService|SingleLogoutService|SingleSignOnService)\b[^>]*:8443[^>]*/>[ \t]*\n?', re.S)
n_t, n = pat.subn('', t)
if n:
    open(p, 'w', encoding='utf-8').write(n_t)
print(f"    removed {n} endpoint(s) on port 8443 from idp-metadata.xml")
PY
  fi

  mkdir -p "$IDP_HOME/tmp/httpClientCache"
}

step_learn() {
  [[ "$CONFIGURE_LEARN" == "yes" ]] || return 0
  log "LEARN / LIAF federation (metadata, attribute resolver + filter)"
  local conf="$IDP_HOME/conf"

  curl -fsSL -o "$IDP_HOME/metadata/federation-cert.pem" https://fr.ac.lk/signedmetadata/metadata-signer \
    || die "Could not download the federation signing certificate"

  insert_xml "$conf/metadata-providers.xml" "</MetadataProvider>" "LEARN-IDP5-FEDERATION" <<'EOF'

    <!-- LEARN-IDP5-FEDERATION -->
    <MetadataProvider id="HTTPMD-LEARN-Federation"
                      xsi:type="FileBackedHTTPMetadataProvider"
                      backingFile="%{idp.home}/metadata/test-metadata.xml"
                      metadataURL="https://fr.ac.lk/signedmetadata/metadata.xml">
        <MetadataFilter xsi:type="SignatureValidation" requireSignedRoot="true" certificateFile="%{idp.home}/metadata/federation-cert.pem"/>
        <MetadataFilter xsi:type="RequiredValidUntil" maxValidityInterval="P10D"/>
        <MetadataFilter xsi:type="EntityRoleWhiteList">
            <RetainedRole>md:SPSSODescriptor</RetainedRole>
        </MetadataFilter>
    </MetadataProvider>

    <MetadataProvider id="HTTPMD-LEARN-interfederation"
                      xsi:type="FileBackedHTTPMetadataProvider"
                      backingFile="%{idp.home}/metadata/LEARNmetadata.xml"
                      metadataURL="https://fr.ac.lk/signedmetadata/LIAF-interfederation-sp-metadata.xml">
        <MetadataFilter xsi:type="SignatureValidation" requireSignedRoot="true" certificateFile="%{idp.home}/metadata/federation-cert.pem"/>
        <MetadataFilter xsi:type="RequiredValidUntil" maxValidityInterval="P11D"/>
        <MetadataFilter xsi:type="EntityRoleWhiteList">
            <RetainedRole>md:SPSSODescriptor</RetainedRole>
        </MetadataFilter>
    </MetadataProvider>
EOF

  # Attribute resolver (downloaded) + attribute filter (self-updating remote resource)
  # NOTE: these are the LEARN "-v4" files; verify they load on IdP 5 (see idp-process.log).
  curl -fsSL -o "$conf/attribute-resolver-LEARN-v4.xml" \
    https://fr.ac.lk/signedmetadata/files/attribute-resolver-LEARN-v4.xml \
    || die "Could not download attribute-resolver-LEARN-v4.xml"
  python3 - "$conf/attribute-resolver-LEARN-v4.xml" "$HOME_ORG_TYPE" <<'PY'
import re, sys
p, val = sys.argv[1:3]
t = open(p, encoding='utf-8').read()
pat = re.compile(r'(<Attribute\s+id="schacHomeOrganizationType"\s*>\s*<Value>)[^<]*(</Value>)')
n_t, n = pat.subn(lambda m: m.group(1) + val + m.group(2), t)
if n:
    open(p, 'w', encoding='utf-8').write(n_t)
    print("    schacHomeOrganizationType set to", val)
else:
    print("    WARNING: schacHomeOrganizationType not found in the LEARN resolver; set it manually", file=sys.stderr)
PY

  insert_xml "$conf/services.xml" "</beans>" "LEARN-IDP5-DEFAULTFILTER" <<'EOF'

    <!-- LEARN-IDP5-DEFAULTFILTER: self-updating LEARN attribute filter -->
    <bean id="Default-Filter" class="net.shibboleth.ext.spring.resource.FileBackedHTTPResource"
          c:client-ref="shibboleth.FileCachingHttpClient"
          c:url="https://fr.ac.lk/signedmetadata/files/attribute-filter-LEARN-v4.xml"
          c:backingFile="%{idp.home}/conf/attribute-filter-LEARN-v4.xml"/>
EOF
  python3 - "$conf/services.xml" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
r_old = '<value>%{idp.home}/conf/attribute-resolver.xml</value>'
r_new = '<value>%{idp.home}/conf/attribute-resolver-LEARN-v4.xml</value>'
f_old = '<value>%{idp.home}/conf/attribute-filter.xml</value>'
f_new = '<ref bean="Default-Filter"/>'
changed = []
if r_old in t: t = t.replace(r_old, r_new); changed.append("resolver")
if f_old in t: t = t.replace(f_old, f_new); changed.append("filter")
open(p, 'w', encoding='utf-8').write(t)
print("    services.xml updated:", ", ".join(changed) or "nothing to change (already done?)")
PY
}

step_permissions_start() {
  log "Permissions and starting Jetty"
  chown -R jetty:jetty "$IDP_HOME"/{logs,metadata,credentials,conf,war,tmp,messages} 2>/dev/null || true
  chown -R jetty:jetty "$IDP_HOME/views" 2>/dev/null || true
  chown -R jetty:jetty "$JETTY_BASE"
  systemctl enable jetty-idp
  systemctl restart jetty-idp
  info "Waiting for the IdP to start (up to ~3 minutes)..."
  local code=000
  for _ in $(seq 1 60); do
    code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${JETTY_HTTP_PORT}/idp/status" || true)"
    if [[ "$code" == "200" ]]; then info "IdP is up (HTTP 200 on /idp/status)."; return 0; fi
    sleep 3
  done
  warn "IdP did not answer 200 on /idp/status (last code: $code)."
  warn "Check:  journalctl -u jetty-idp -n 100   and   $IDP_HOME/logs/idp-process.log"
  return 0
}

step_apache() {
  log "Apache reverse proxy + TLS (${TLS_MODE})"
  a2enmod proxy proxy_http ssl headers rewrite >/dev/null
  local avail=/etc/apache2/sites-available
  local cert key chain_line=""

  # Plain-HTTP vhost first (needed for the ACME challenge). The default site is left untouched
  # so other sites on this server are not affected.
  cat >"$avail/idp.conf" <<'EOF'
<VirtualHost *:80>
    ServerName @FQDN@
    ServerAdmin webmaster@@SCOPE@
    DocumentRoot /var/www/html
</VirtualHost>
EOF
  sed -i "s/@FQDN@/${IDP_FQDN}/g; s/@SCOPE@/${IDP_SCOPE}/g" "$avail/idp.conf"
  a2ensite idp >/dev/null
  apache2ctl configtest
  systemctl reload apache2

  case "$TLS_MODE" in
    letsencrypt)
      local le_args=(certonly --apache -d "$IDP_FQDN" --agree-tos --non-interactive)
      if [[ -n "${LE_EMAIL:-}" ]]; then le_args+=(-m "$LE_EMAIL"); else le_args+=(--register-unsafely-without-email); fi
      certbot "${le_args[@]}"
      cert="/etc/letsencrypt/live/${IDP_FQDN}/fullchain.pem"
      key="/etc/letsencrypt/live/${IDP_FQDN}/privkey.pem"
      install -d /etc/letsencrypt/renewal-hooks/deploy
      printf '#!/bin/sh\nsystemctl reload apache2\n' >/etc/letsencrypt/renewal-hooks/deploy/reload-apache.sh
      chmod 0755 /etc/letsencrypt/renewal-hooks/deploy/reload-apache.sh ;;
    selfsigned)
      cert="/etc/ssl/certs/${IDP_FQDN}.crt"; key="/etc/ssl/private/${IDP_FQDN}.key"
      if [[ ! -s "$cert" ]]; then
        openssl req -x509 -newkey rsa:3072 -nodes -days 1095 -subj "/CN=${IDP_FQDN}" \
          -addext "subjectAltName=DNS:${IDP_FQDN}" -keyout "$key" -out "$cert"
        chmod 0600 "$key"
      fi ;;
    existing)
      cert="$TLS_CERT_FILE"; key="$TLS_KEY_FILE"
      [[ -n "${TLS_CHAIN_FILE:-}" ]] && chain_line="SSLCertificateChainFile ${TLS_CHAIN_FILE}" ;;
  esac

  cat >"$avail/idp-ssl.conf" <<'EOF'
<VirtualHost *:443>
    ServerName @FQDN@
    ServerAdmin webmaster@@SCOPE@
    DocumentRoot /var/www/html

    SSLEngine on
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH"
    SSLHonorCipherOrder on
    SSLCompression Off
    SSLCertificateFile @CERT@
    SSLCertificateKeyFile @KEY@
    @CHAIN@

    Header always set Strict-Transport-Security "max-age=63072000"

    # Reverse proxy to Jetty - scoped to THIS virtual host only
    ProxyPreserveHost On
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"
    <Location /idp>
        Require all granted
    </Location>
    ProxyPass        /idp http://127.0.0.1:@PORT@/idp retry=5
    ProxyPassReverse /idp http://127.0.0.1:@PORT@/idp retry=5
</VirtualHost>
EOF
  sed -i "s|@FQDN@|${IDP_FQDN}|g; s|@SCOPE@|${IDP_SCOPE}|g; s|@CERT@|${cert}|g; s|@KEY@|${key}|g; s|@CHAIN@|${chain_line}|g; s|@PORT@|${JETTY_HTTP_PORT}|g" "$avail/idp-ssl.conf"

  # Port 80: redirect to HTTPS, except ACME challenges
  cat >"$avail/idp.conf" <<'EOF'
<VirtualHost *:80>
    ServerName @FQDN@
    ServerAdmin webmaster@@SCOPE@
    DocumentRoot /var/www/html
    RewriteEngine On
    RewriteCond %{REQUEST_URI} !^/\.well-known/acme-challenge/
    RewriteRule ^/?(.*)$ https://%{SERVER_NAME}/$1 [R=301,L]
</VirtualHost>
EOF
  sed -i "s/@FQDN@/${IDP_FQDN}/g; s/@SCOPE@/${IDP_SCOPE}/g" "$avail/idp.conf"

  a2ensite idp-ssl >/dev/null
  apache2ctl configtest
  systemctl enable apache2
  systemctl reload apache2

  if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow 80/tcp >/dev/null; ufw allow 443/tcp >/dev/null; info "ufw: opened 80/443"
  else
    info "Make sure your firewall allows inbound TCP 80 and 443."
  fi
}

step_final() {
  log "Final checks"
  local code
  code="$(curl -ks -o /dev/null -w '%{http_code}' --resolve "${IDP_FQDN}:443:127.0.0.1" "https://${IDP_FQDN}/idp/shibboleth" || true)"
  info "https://${IDP_FQDN}/idp/shibboleth (metadata) -> HTTP ${code}"
  JAVA_HOME="$JAVA_HOME_DIR" "$IDP_HOME/bin/status.sh" 2>&1 | head -n 12 | sed 's/^/    /' || true

  umask 077
  {
    echo "Shibboleth IdP 5 install - generated $(date -u +%FT%TZ)"
    echo "IdP home        : $IDP_HOME"
    echo "DB name / user  : $DB_NAME / $DB_USER"
    echo "DB password     : $DB_PASSWORD"
    echo "Sealer / backchannel passwords are in $IDP_HOME/credentials/secrets.properties"
    echo "(LDAP bind password is stored only in secrets.properties)"
  } >"$SECRETS_NOTE"
  chmod 600 "$SECRETS_NOTE"

  cat <<EOF

================================================================================
 Installation finished.

 Metadata (register this with LIAF):  https://${IDP_FQDN}/idp/shibboleth
 Secrets summary                   :  ${SECRETS_NOTE}   (root only; move it somewhere safe)

 Still manual (see the guide):
   - Edit ${IDP_HOME}/metadata/idp-metadata.xml: mdui DisplayName/Description, SLO endpoints,
     remove unused SAML1 / commented content.
   - Branding: logo, css, views (rebuild with ${IDP_HOME}/bin/build.sh, then: systemctl restart jetty-idp).
   - Per-SP attribute release in attribute-filter (if not using the LEARN filter).

 Useful logs:
   journalctl -u jetty-idp -f
   ${IDP_HOME}/logs/idp-process.log   idp-warn.log   idp-audit.log
   /var/log/apache2/error.log
================================================================================
EOF
}

# ----------------------------------------------------------------------------
main() {
  while getopts "e:yh" opt; do
    case "$opt" in
      e) ENV_FILE="$OPTARG" ;;
      y) ASSUME_YES="yes" ;;
      h) usage 0 ;;
      *) usage 1 ;;
    esac
  done

  if [[ -n "$ENV_FILE" ]]; then
    [[ -r "$ENV_FILE" ]] || die "Cannot read env file: $ENV_FILE"
    if [[ "$(stat -c '%a' "$ENV_FILE")" != "600" ]]; then
      warn "$ENV_FILE contains secrets - consider: chmod 600 $ENV_FILE"
    fi
    set -a
    # shellcheck source=/dev/null
    . "$ENV_FILE"
    set +a
  fi
  set_defaults

  [[ $EUID -eq 0 ]] || die "Run as root (sudo)."
  mkdir -p "$(dirname "$LOG_FILE")"; touch "$LOG_FILE"; chmod 600 "$LOG_FILE"
  exec > >(tee -a "$LOG_FILE") 2>&1

  collect_settings
  step_preflight
  step_packages
  step_java
  step_jetty_user
  step_database
  step_idp_install
  step_jetty_install
  step_plugin_libs
  step_idp_config
  step_learn
  step_permissions_start
  step_apache
  step_final
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
