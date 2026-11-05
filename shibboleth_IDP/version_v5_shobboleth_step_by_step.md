# Shibboleth IdP v5 on Ubuntu LTS (22.04 / 24.04) — Jetty 12 behind Apache 2

Adapted from the LEARN *installing-idp-v4* manual. Same architecture, updated for IdP 5:

All commands are run as **root** (`sudo -i`). Replace `idp.YOUR-DOMAIN.ac.lk` / `YOUR-DOMAIN` with your own values.

> **Don't want to type all this?** Jump to [Automated installation](#automated-installation) — `install_idpv5_ubuntu_24.sh` does every step below.

## What changed compared with v4

| Area | v4 manual | v5 manual (this guide) |
|---|---|---|
| Java | Corretto 11 | **Corretto 17** (IdP 5 requires Java 17+) |
| Jetty | 9.4 `jetty-distribution` | **Jetty 12.1 `jetty-home`**; `ee11` modules for IdP 5.2+, `ee9` for IdP 5.1.x |
| `idp.xml` class | `org.eclipse.jetty.webapp.WebAppContext` | **`org.eclipse.jetty.ee11.webapp.WebAppContext`** (5.2+) / `…ee9…` (5.1.x) |
| JDBC libraries | apt packages symlinked into `edit-webapp` | **Jars from Maven Central** (checksum-verified) |
| Consent / session storage | `JPAStorageService` in `global.xml` | **JDBC Storage plugin** + `shibboleth.JDBCStorageService` |
| JDBC driver URL | `jdbc:mysql://` | **`jdbc:mariadb://`** (MariaDB driver 3.x) |
| SAML1 / port 8443 | removed by hand | not generated for SAML1; leftover `:8443` endpoints are removed |
| Apache proxy rules | global (`idp-proxy.conf`) | **inside the IdP's own VirtualHost** (safe for multi-site servers) |
| Service control | `init.d` symlink | **systemd** unit `jetty-idp.service` |

## Choose your versions first (important)

| IdP | Needs | Jetty | Jetty modules / `idp.xml` class |
|---|---|---|---|
| **5.2.x** (current: 5.2.3) | Servlet **6.1** / Jakarta EE 11 | **12.1 or newer only** | `ee11-*` / `org.eclipse.jetty.ee11.webapp.WebAppContext` |
| 5.1.x | Servlet 5/6 | 12.0 or 12.1 | `ee9-*` / `org.eclipse.jetty.ee9.webapp.WebAppContext` |

Shibboleth's release notes state that IdP 5.2 (Spring 7 / Spring Web Flow 4) drops Jetty 12.0 and Tomcat 10, and that Jetty 12.1 is the recommended Jetty for all IdP 5.x.

Note : **Do not combine IdP 5.2.x with Jetty 12.0.x** (for example `IDP_VER=5.2.2` with `JETTY_VER=12.0.16`) — the IdP will not deploy. `ee10` is not the right choice for either line.

The commands below use shell variables so you set the choice once:

```bash
IDP_VERSION=5.2.3          # latest 5.x: https://shibboleth.net/downloads/identity-provider/
JETTY_VERSION=12.1.5       # newest 12.1.x: https://jetty.org/download.html
EE=ee11                    # ee11 for IdP 5.2+, ee9 for IdP 5.1.x
```

---

## 1. Prerequisites

```bash
apt update && apt upgrade -y
apt install -y apache2 mariadb-server wget curl gnupg ca-certificates openssl chrony unzip python3
```

Install Amazon Corretto 17:

```bash
curl -fsSL https://apt.corretto.aws/corretto.key | gpg --dearmor -o /usr/share/keyrings/corretto-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" \
  > /etc/apt/sources.list.d/corretto.list
apt update && apt install -y java-17-amazon-corretto-jdk

export JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto     # for this shell only
$JAVA_HOME/bin/java -version
```

Make sure ports **80** and **443** are reachable and that `idp.YOUR-DOMAIN.ac.lk` resolves to the server.

Create the Jetty system user:

```bash
useradd -r -M -s /usr/sbin/nologin jetty
```

## 2. MariaDB database (persistent-id + consent storage)

```bash
systemctl enable --now mariadb
mysql
```

```sql
DROP DATABASE IF EXISTS test;
DROP USER IF EXISTS ''@'localhost';

CREATE DATABASE storageservice CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'idp_admin'@'localhost' IDENTIFIED BY '###_DB-PASSWORD_###';
GRANT ALL PRIVILEGES ON storageservice.* TO 'idp_admin'@'localhost';
FLUSH PRIVILEGES;

USE storageservice;

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
```

> Generate the password with `openssl rand -hex 20`. Avoid `'` and `\` in it.
> On Ubuntu, `mysql` run as root works through the unix socket, so no root password step is needed.

## 3. Install the Shibboleth IdP 5

```bash
cd /usr/local/src
wget https://shibboleth.net/downloads/identity-provider/${IDP_VERSION}/shibboleth-identity-provider-${IDP_VERSION}.tar.gz
wget https://shibboleth.net/downloads/identity-provider/${IDP_VERSION}/shibboleth-identity-provider-${IDP_VERSION}.tar.gz.sha256
cat shibboleth-identity-provider-${IDP_VERSION}.tar.gz.sha256
sha256sum shibboleth-identity-provider-${IDP_VERSION}.tar.gz      # the two hashes must match
tar xzf shibboleth-identity-provider-${IDP_VERSION}.tar.gz
cd shibboleth-identity-provider-${IDP_VERSION}/bin
JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto bash install.sh
```

Answer the prompts:

```
Installation Directory: [/opt/shibboleth-idp]
Hostname:       idp.YOUR-DOMAIN.ac.lk
SAML EntityID:  [https://idp.YOUR-DOMAIN.ac.lk/idp/shibboleth]
Attribute Scope: YOUR-DOMAIN.ac.lk
Sealer / keystore passwords: (generate with  openssl rand -hex 24  and keep them safe)
```

From here on `idp.home` = `/opt/shibboleth-idp`. The sealer password is saved in `/opt/shibboleth-idp/credentials/secrets.properties`.

## 4. Install Jetty 12

```bash
cd /usr/local/src
wget https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/${JETTY_VERSION}/jetty-home-${JETTY_VERSION}.tar.gz
wget https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/${JETTY_VERSION}/jetty-home-${JETTY_VERSION}.tar.gz.sha1
echo "$(cat jetty-home-${JETTY_VERSION}.tar.gz.sha1)  jetty-home-${JETTY_VERSION}.tar.gz" | sha1sum -c -
tar xzf jetty-home-${JETTY_VERSION}.tar.gz
ln -nsf jetty-home-${JETTY_VERSION} jetty-src          # makes future Jetty upgrades a one-line change
```

Create the Jetty **base** (your configuration, separate from the Jetty distribution) and enable the modules:

```bash
mkdir -p /opt/jetty/{tmp,webapps} /var/log/jetty
ln -nsf /var/log/jetty /opt/jetty/logs
chown -R jetty:jetty /opt/jetty /var/log/jetty

cd /opt/jetty
runuser -u jetty -- env JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto \
  /usr/lib/jvm/java-17-amazon-corretto/bin/java \
  -Djetty.home=/usr/local/src/jetty-src -Djetty.base=/opt/jetty \
  -jar /usr/local/src/jetty-src/start.jar --create-startd --approve-all-licenses \
  --add-modules=server,http,forwarded,ext,resources,logging-logback,${EE}-deploy,${EE}-annotations,${EE}-plus,${EE}-jsp,${EE}-jstl,${EE}-servlets
```

> The `forwarded` module (called `http-forwarded` before Jetty 12.1, now deprecated) is essential behind Apache: it makes Jetty trust `X-Forwarded-Proto` / `X-Forwarded-For`, so redirects, cookies and IP-based access rules in `access-control.xml` work.

Bind Jetty to localhost only (`/opt/jetty/start.d/idp-local.ini`):

```ini
jetty.http.host=127.0.0.1
jetty.http.port=8080
jetty.httpConfig.sendServerVersion=false
# do not rescan webapps/ - the IdP is only (re)deployed by restarting the service
jetty.deploy.scanInterval=0
```

### Deploy the IdP — `idp.xml`

```bash
cat > /opt/jetty/webapps/idp.xml <<EOF
<?xml version="1.0"?>
<!DOCTYPE Configure PUBLIC "-//Jetty//Configure//EN" "https://www.eclipse.org/jetty/configure_10_0.dtd">
<Configure class="org.eclipse.jetty.${EE}.webapp.WebAppContext">
  <Set name="war"><SystemProperty name="idp.home"/>/war/idp.war</Set>
  <Set name="contextPath">/idp</Set>
  <Set name="extractWAR">false</Set>
  <Set name="copyWebDir">false</Set>
  <Set name="copyWebInf">true</Set>
</Configure>
EOF
```

The only difference from v4 is the `ee11` / `ee9` class name (see *Choose your versions*). The WAR is built by the IdP (`/opt/shibboleth-idp/war/idp.war`); Jetty just points at it.

### systemd service

```bash
cat > /etc/systemd/system/jetty-idp.service <<'EOF'
[Unit]
Description=Jetty 12 - Shibboleth IdP
After=network.target mariadb.service

[Service]
User=jetty
Group=jetty
WorkingDirectory=/opt/jetty
ExecStartPre=/bin/sh -c 'rm -rf /opt/jetty/tmp/*'
ExecStart=/usr/lib/jvm/java-17-amazon-corretto/bin/java -Xmx1500m -Djava.security.egd=file:/dev/urandom -Didp.home=/opt/shibboleth-idp -Djava.io.tmpdir=/opt/jetty/tmp -Djetty.home=/usr/local/src/jetty-src -Djetty.base=/opt/jetty -jar /usr/local/src/jetty-src/start.jar
Restart=on-failure
RestartSec=5
SuccessExitStatus=143
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
```

Give Jetty write access to the IdP directories (same as the v4 guide) and don't start it yet:

```bash
cd /opt/shibboleth-idp
mkdir -p tmp/httpClientCache
chown -R jetty:jetty logs metadata credentials conf war tmp messages views
```

## 5. JDBC storage plugin and libraries

### 5.1 Install the JDBC Storage plugin

```bash
export JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto
/opt/shibboleth-idp/bin/plugin.sh -I net.shibboleth.plugin.storage.jdbc
/opt/shibboleth-idp/bin/plugin.sh -l          # confirm it is listed
```

`plugin.sh` verifies the download's PGP signature and, the first time, asks whether to import the signing key. Check that the fingerprint it shows is listed in https://shibboleth.net/downloads/PGP_KEYS and answer `yes`.

**Unattended install (what `install-idp5.sh` does):** `--noPrompt` answers *no* to that question, so the install fails with `Key import barred by user` / `Could not check signature of distribution` unless the key is already trusted. Pre-seed the plugin's truststore first:

```bash
mkdir -p /opt/shibboleth-idp/credentials/net.shibboleth.plugin.storage.jdbc
curl -fsSL https://shibboleth.net/downloads/PGP_KEYS \
  -o /opt/shibboleth-idp/credentials/net.shibboleth.plugin.storage.jdbc/truststore.asc
/opt/shibboleth-idp/bin/plugin.sh -I net.shibboleth.plugin.storage.jdbc 
```

check whether the plugin is listed 
`/opt/shibboleth-idp/bin/plugin.sh -l`

### 5.2 Download the JDBC jars (checksum-verified)

| Library | Version | Link |
|---|---|---|
| mariadb-java-client | 3.5.10 | https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/3.5.10/mariadb-java-client-3.5.10.jar |
| commons-dbcp2 | 2.13.0 | https://repo1.maven.org/maven2/org/apache/commons/commons-dbcp2/2.13.0/commons-dbcp2-2.13.0.jar |
| commons-pool2 | 2.12.0 | https://repo1.maven.org/maven2/org/apache/commons/commons-pool2/2.12.0/commons-pool2-2.12.0.jar |
| spring-jdbc | same version as the IdP's `spring-core` | https://repo1.maven.org/maven2/org/springframework/spring-jdbc/ |

(dbcp2 2.13.0 is built against pool2 2.12.0; dbcp2 2.14.0 pairs with pool2 2.13.0.)

```bash
mkdir -p /usr/local/src/idp-libs && cd /usr/local/src/idp-libs
BASE=https://repo1.maven.org/maven2
for f in \
  org/mariadb/jdbc/mariadb-java-client/3.5.10/mariadb-java-client-3.5.10.jar \
  org/apache/commons/commons-dbcp2/2.13.0/commons-dbcp2-2.13.0.jar \
  org/apache/commons/commons-pool2/2.12.0/commons-pool2-2.12.0.jar
do
  wget -q "$BASE/$f" "$BASE/$f.sha1"
  j=$(basename "$f")
  echo "$(cat $j.sha1)  $j" | sha1sum -c -          # must print OK
done
```

### 5.3 Build the WAR, then add only what is missing

Copy the MariaDB driver into `edit-webapp` and build:

```bash
mkdir -p /opt/shibboleth-idp/edit-webapp/WEB-INF/lib
cp /usr/local/src/idp-libs/mariadb-java-client-3.5.10.jar /opt/shibboleth-idp/edit-webapp/WEB-INF/lib/
JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto /opt/shibboleth-idp/bin/build.sh

unzip -Z1 /opt/shibboleth-idp/war/idp.war | grep -E 'mariadb|dbcp2|pool2|spring-jdbc|spring-core'
```

The plugin may already bring `commons-dbcp2`, `commons-pool2` and `spring-jdbc` into the WAR. **Only if one of them is missing from the listing**, copy it into `edit-webapp/WEB-INF/lib/` and run `build.sh` again. For `spring-jdbc`, use exactly the version shown for `spring-core` in the listing (e.g. `spring-core-7.0.1.jar` → `spring-jdbc-7.0.1.jar`).

```bash
# example, only if missing:
cp /usr/local/src/idp-libs/commons-dbcp2-2.13.0.jar /usr/local/src/idp-libs/commons-pool2-2.12.0.jar \
   /opt/shibboleth-idp/edit-webapp/WEB-INF/lib/
JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto /opt/shibboleth-idp/bin/build.sh
chown -R jetty:jetty /opt/shibboleth-idp/war
```

> Do **not** use the apt packages `libcommons-dbcp-java` / `libcommons-pool-java`: they are the old 1.x / javax generation.

## 6. Configure the IdP

Back up first: `cp -a /opt/shibboleth-idp/conf /opt/shibboleth-idp/conf-backup`.

### 6.1 Secrets — `credentials/secrets.properties`  (do not skip)

```properties
idp.authn.LDAP.bindDNCredential = ###LDAP_ADMIN_PASSWORD###
idp.storage.dbpassword = ###_DB-PASSWORD_###
idp.persistentId.salt = ### result of: openssl rand -base64 36 ###
```

> **All three lines are required.** `idp.storage.dbpassword` is referenced by the data-source beans in `global.xml`. If it is missing the IdP fails to start with
> `PlaceholderResolutionException: Could not resolve placeholder 'idp.storage.dbpassword' in value "%{idp.storage.dbpassword}"`
> while Jetty itself looks healthy (port 8080 is open but `/idp/status` returns 503).
> The value must be exactly the password you gave the MariaDB user in step 2. Keep the file readable by the `jetty` user (`chown -R jetty:jetty /opt/shibboleth-idp/credentials`, or `root:jetty` with mode `640`) — note that `sed -i` re-creates the file as root, so re-check ownership after editing it that way.

Quick one-liner to set the DB password safely:

```bash
cd /opt/shibboleth-idp/credentials
sed -i '/^[[:space:]]*idp\.storage\.dbpassword[[:space:]]*=/d' secrets.properties
printf '\nidp.storage.dbpassword = %s\n' 'YOUR_DB_PASSWORD' >> secrets.properties
chown root:jetty secrets.properties && chmod 640 secrets.properties
```

### 6.2 LDAP — `conf/ldap.properties`

Pick **one** of the three variants.

**STARTTLS (recommended)**

```properties
idp.authn.LDAP.authenticator = bindSearchAuthenticator
idp.authn.LDAP.ldapURL = ldap://ldap.YOUR-DOMAIN.ac.lk:389
idp.authn.LDAP.useStartTLS = true
idp.authn.LDAP.useSSL = false
idp.authn.LDAP.sslConfig = certificateTrust
idp.authn.LDAP.trustCertificates = %{idp.home}/credentials/ldap_server.crt
```

**LDAPS**

```properties
idp.authn.LDAP.authenticator = bindSearchAuthenticator
idp.authn.LDAP.ldapURL = ldaps://ldap.YOUR-DOMAIN.ac.lk:636
idp.authn.LDAP.useStartTLS = false
idp.authn.LDAP.useSSL = true
idp.authn.LDAP.sslConfig = certificateTrust
idp.authn.LDAP.trustCertificates = %{idp.home}/credentials/ldap_server.crt
```

**Plain LDAP**

```properties
idp.authn.LDAP.authenticator = bindSearchAuthenticator
idp.authn.LDAP.ldapURL = ldap://ldap.YOUR-DOMAIN.ac.lk:389
idp.authn.LDAP.useStartTLS = false
idp.authn.LDAP.useSSL = false
```

Common to all variants:

```properties
idp.authn.LDAP.baseDN = ou=people,dc=YOUR-DOMAIN,dc=ac,dc=lk
idp.authn.LDAP.userFilter = (uid={user})
idp.authn.LDAP.bindDN = cn=admin,dc=YOUR-DOMAIN,dc=ac,dc=lk
idp.authn.LDAP.returnAttributes = *
idp.attribute.resolver.LDAP.searchFilter = (uid=$resolutionContext.principal)

# used by the LEARN attribute resolver's LDAP connector
idp.attribute.resolver.LDAP.returnAttributes = %{idp.authn.LDAP.returnAttributes}
idp.attribute.resolver.LDAP.trustCertificates = %{idp.authn.LDAP.trustCertificates:undefined}
idp.attribute.resolver.LDAP.exportAttributes =
```

For STARTTLS / LDAPS, copy the LDAP server's PEM certificate to the IdP:

```bash
# on the LDAP server:  scp /etc/ssl/certs/ldap_server.pem user@idp:/tmp/
install -m 0644 -o jetty -g jetty /tmp/ldap_server.pem /opt/shibboleth-idp/credentials/ldap_server.crt
```

### 6.3 Persistent-id (stored mode) and consent storage

`conf/saml-nameid.properties`:

```properties
idp.persistentId.sourceAttribute = uid
idp.persistentId.generator = MyPersistentIdStore
```

Enable the generators — remove the comment markers around these lines:

* `vi conf/saml-nameid.xml`

uncomment `<ref bean="shibboleth.SAML2PersistentGenerator" />`

* `vi conf/c14n/subject-c14n.xml`

 uncomment `<ref bean="c14n/SAML2Persistent" />`

Add the persistent-id store bean **before the closing `</beans>`** of `conf/saml-nameid.xml`:

```xml
<bean id="MyPersistentIdStore" parent="shibboleth.StoredPersistentIdGenerator"
      p:dataSource-ref="idp.JDBC.PersistentDataSource"
      p:queryTimeout="PT2S"
      p:retryableErrors="#{ {'23000'} }" />
```

Add the storage service and data sources **before the closing `</beans>`** of `conf/global.xml`:

```xml
<bean id="idp.JDBCConsentStorage"
      parent="shibboleth.JDBCStorageService"
      p:cleanupInterval="%{idp.storage.cleanupInterval:PT10M}"
      p:dataSource-ref="idp.JDBC.DataSource" />

<!-- Two separate pools so a problem in one component cannot starve the other -->
<bean id="idp.JDBC.DataSource"
      class="org.apache.commons.dbcp2.BasicDataSource" destroy-method="close" lazy-init="true"
      p:driverClassName="org.mariadb.jdbc.Driver"
      p:url="jdbc:mariadb://127.0.0.1:3306/storageservice?autoReconnect=true&amp;sslMode=disable"
      p:username="idp_admin"
      p:password="%{idp.storage.dbpassword}"
      p:maxIdle="5"
      p:maxWaitMillis="15000"
      p:testOnBorrow="true"
      p:validationQuery="select 1"
      p:validationQueryTimeout="5" />

<bean id="idp.JDBC.PersistentDataSource"
      class="org.apache.commons.dbcp2.BasicDataSource" destroy-method="close" lazy-init="true"
      p:driverClassName="org.mariadb.jdbc.Driver"
      p:url="jdbc:mariadb://127.0.0.1:3306/storageservice?autoReconnect=true&amp;sslMode=disable"
      p:username="idp_admin"
      p:password="%{idp.storage.dbpassword}"
      p:maxIdle="5"
      p:maxWaitMillis="15000"
      p:testOnBorrow="true"
      p:validationQuery="select 1"
      p:validationQueryTimeout="5" />
```

> With the MariaDB 3.x driver the URL must start with `jdbc:mariadb://` (a `jdbc:mysql://` URL is rejected unless you add `permitMysqlScheme`). `useSSL=false` from the v4 guide is replaced by `sslMode=disable` (localhost connection).

`conf/idp.properties`:

```properties
idp.consent.StorageService = idp.JDBCConsentStorage
idp.consent.compareValues = true
idp.consent.maxStoredRecords = -1
idp.consent.storageRecordLifetime = P1Y
idp.session.trackSPSessions = true
idp.session.secondaryServiceIndex = true
```

(The Consent module itself was enabled at install time via `idp.initial.modules`. To enable it later: `bin/module.sh -e idp.intercept.Consent`.)

### 6.4 Log LDAP authentication errors — `conf/logback.xml`

Add before `</configuration>`:

```xml
<logger name="org.ldaptive.auth.Authenticator" level="INFO" />
```

### 6.5 Clean the IdP metadata — `metadata/idp-metadata.xml`

* In `<Extensions>` uncomment `mdui:UIInfo` and set a meaningful `mdui:DisplayName` / `mdui:Description` (en). (The script does this automatically only if the block is already uncommented; otherwise it prints a note.)

* Remove leftover commented content.

The final metadata is served at `https://idp.YOUR-DOMAIN.ac.lk/idp/shibboleth`.

## 7. Apache 2 (TLS + reverse proxy)

```bash
a2enmod proxy proxy_http ssl headers rewrite
```

Port-80 vhost first (`/etc/apache2/sites-available/idp.conf`) — needed for the Let's Encrypt challenge:

```apache
<VirtualHost *:80>
    ServerName idp.YOUR-DOMAIN.ac.lk
    ServerAdmin webmaster@YOUR-DOMAIN.ac.lk
    DocumentRoot /var/www/html
</VirtualHost>
```

```bash
a2ensite idp && apache2ctl configtest && systemctl reload apache2
```

### 7.1 Certificate — choose one

**Let's Encrypt (production — recommended)**

Prerequisites: a DNS **A record** for `idp.YOUR-DOMAIN.ac.lk` pointing at this server, and inbound TCP **80** and **443** open. Verify first with `getent hosts idp.YOUR-DOMAIN` and `curl -I http://idp.YOUR-DOMAIN.ac.lk/` (the port-80 vhost from above must answer).

```bash
apt install -y certbot python3-certbot-apache
certbot certonly --apache -d idp.YOUR-DOMAIN.ac.lk -m you@YOUR-DOMAIN.ac.lk --agree-tos
printf '#!/bin/sh\nsystemctl reload apache2\n' > /etc/letsencrypt/renewal-hooks/deploy/reload-apache.sh
chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-apache.sh
```

Certificate: `/etc/letsencrypt/live/idp.YOUR-DOMAIN.ac.lk/fullchain.pem`, key: `.../privkey.pem`.

**Certificate from a public CA** — put the full chain in the certificate file (or add `SSLCertificateChainFile`).
**Using Self-singned certificates is not encouraged**

### 7.2 HTTPS vhost with the proxy — `/etc/apache2/sites-available/idp-ssl.conf`

```apache
<VirtualHost *:443>
    ServerName idp.YOUR-DOMAIN.ac.lk
    ServerAdmin webmaster@YOUR-DOMAIN.ac.lk
    DocumentRoot /var/www/html

    SSLEngine on
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH"
    SSLHonorCipherOrder on
    SSLCompression Off
    SSLCertificateFile    /etc/letsencrypt/live/idp.YOUR-DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/idp.YOUR-DOMAIN/privkey.pem

    Header always set Strict-Transport-Security "max-age=63072000"

    # Reverse proxy to Jetty - scoped to THIS virtual host only
    ProxyPreserveHost On
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"
    <Location /idp>
        Require all granted
    </Location>
    ProxyPass        /idp http://127.0.0.1:8080/idp retry=5
    ProxyPassReverse /idp http://127.0.0.1:8080/idp retry=5
</VirtualHost>
```

> Unlike the v4 `idp-proxy.conf` (which sat outside any VirtualHost and would proxy `/idp` for **every** site), the proxy rules here only apply to the IdP's own host name. `includeSubDomains;preload` is intentionally left out of the HSTS header because other sites might share this server.

Redirect port 80 to HTTPS (replace `idp.conf`), keeping Let's Encrypt challenges reachable:

```apache
<VirtualHost *:80>
    ServerName idp.YOUR-DOMAIN.ac.lk
    ServerAdmin webmaster@YOUR-DOMAIN.ac.lk
    DocumentRoot /var/www/html
    RewriteEngine On
    RewriteCond %{REQUEST_URI} !^/\.well-known/acme-challenge/
    RewriteRule ^/?(.*)$ https://%{SERVER_NAME}/$1 [R=301,L]
</VirtualHost>
```

```bash
a2ensite idp-ssl && apache2ctl configtest && systemctl reload apache2
```
Not: please disable unwanted sites in apache

## 8. Start and test

### 8.1 Pre-start checklist (catches the usual restart loops)

```bash
cd /opt/shibboleth-idp

# 1) all three secrets present
grep -nE '^[[:space:]]*(idp\.storage\.dbpassword|idp\.authn\.LDAP\.bindDNCredential|idp\.persistentId\.salt)[[:space:]]*=' credentials/secrets.properties | sed -E 's/=.*/= ***/'

# 2) list the %{placeholders} your beans use - each must be defined (see note below)
grep -ohE '%\{[A-Za-z0-9_.-]+\}' conf/global.xml conf/saml-nameid.xml | sort -u

# 3) the jetty user can read the secrets
sudo -u jetty test -r credentials/secrets.properties && echo "jetty can read secrets"

# 4) the DB login used in global.xml works
mysql -u idp_admin -p -h 127.0.0.1 storageservice -e 'SELECT 1;'

# 5) EE level of idp.xml matches the enabled Jetty modules
grep -o 'ee[0-9]*' /opt/jetty/webapps/idp.xml | sort -u
ls /opt/jetty/start.d | grep -E '^ee[0-9]+-deploy'
```

For step 2, each placeholder printed (other than ones with a `:default`, e.g. `%{idp.storage.cleanupInterval:PT10M}`, and `%{idp.home}`) must exist as a key in `conf/*.properties` or `credentials/secrets.properties`. `install-idp5.sh` performs checks 1–4 automatically and refuses to start Jetty if one fails.

### 8.2 Start

```bash
systemctl enable --now jetty-idp
journalctl -u jetty-idp -f                         # watch startup (Ctrl+C to leave)

curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/idp/status     # 200 once started
JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto /opt/shibboleth-idp/bin/status.sh
curl -sI https://idp.YOUR-DOMAIN.ac.lk/idp/shibboleth                              # 200 from outside
```

Confirm that `https://idp.YOUR-DOMAIN.ac.lk/idp/status` is **not** reachable from the internet (it should be restricted to localhost by `conf/access-control.xml`). If it is open, check that Apache sends `X-Forwarded-For` (it does by default with `mod_proxy`) and that the `forwarded` Jetty module is enabled.

## 9. Register with LIAF and configure the federation

Registration steps on https://liaf.ac.lk are unchanged from the v4 guide (paste the metadata from `https://idp.YOUR-DOMAIN.ac.lk/idp/shibboleth`, choose *LEARN Identity Federation*, fill in organisation, contacts, UI info, and tick `urn:oasis:names:tc:SAML:2.0:nameid-format:persistent`).

### 9.1 Federation metadata — `conf/metadata-providers.xml`

```bash
wget https://fr.ac.lk/signedmetadata/metadata-signer -O /opt/shibboleth-idp/metadata/federation-cert.pem
```

Add before the final `</MetadataProvider>`:

```xml
<MetadataProvider id="HTTPMD-LEARN-Federation"
                  xsi:type="FileBackedHTTPMetadataProvider"
                  backingFile="%{idp.home}/metadata/test-metadata.xml"
                  metadataURL="https://fr.ac.lk/signedmetadata/metadata.xml">
    <MetadataFilter xsi:type="SignatureValidation" requireSignedRoot="true" certificateFile="%{idp.home}/metadata/federation-cert.pem"/>
    <MetadataFilter xsi:type="RequiredValidUntil" maxValidityInterval="P10D"/>
    <MetadataFilter xsi:type="EntityRole" xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata">
        <RetainedRole>md:SPSSODescriptor</RetainedRole>
    </MetadataFilter>
</MetadataProvider>

<MetadataProvider id="HTTPMD-LEARN-interfederation"
                  xsi:type="FileBackedHTTPMetadataProvider"
                  backingFile="%{idp.home}/metadata/LEARNmetadata.xml"
                  metadataURL="https://fr.ac.lk/signedmetadata/LIAF-interfederation-sp-metadata.xml">
    <MetadataFilter xsi:type="SignatureValidation" requireSignedRoot="true" certificateFile="%{idp.home}/metadata/federation-cert.pem"/>
    <MetadataFilter xsi:type="RequiredValidUntil" maxValidityInterval="P11D"/>
    <MetadataFilter xsi:type="EntityRole" xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata">
        <RetainedRole>md:SPSSODescriptor</RetainedRole>
    </MetadataFilter>
</MetadataProvider>
```

> The filter type is `EntityRole`. The old name `EntityRoleWhiteList` used in the v4 guide has been deprecated since IdP 3.2 and should not be used on IdP 5.

### 9.2 LEARN attribute resolver and filter

```bash
wget https://fr.ac.lk/templates/attribute-resolver-LEARN-v5.xml \
     -O /opt/shibboleth-idp/conf/attribute-resolver-LEARN-v5.xml
wget https://fr.ac.lk/templates/attribute-filter-LEARN-v5.xml \
     -O /opt/shibboleth-idp/conf/attribute-filter-LEARN-v5.xml      # seeds the filter's backing file
```

In that resolver file replace the placeholder `dc=YOUR-DOMAIN,dc=ac,dc=lk` (if present) with your LDAP root DN, and set `schacHomeOrganizationType` to one of `urn:schac:homeOrganizationType:int:university`, `…:int:library`, `…:int:public-research-institution`, `…:int:private-research-institution`.

In `conf/services.xml`, add before `</beans>`:

```xml
<bean id="Default-Filter" class="net.shibboleth.ext.spring.resource.FileBackedHTTPResource"
      c:client-ref="shibboleth.FileCachingHttpClient"
      c:url="https://fr.ac.lk/signedmetadata/files/attribute-filter-LEARN-v5.xml"
      c:backingFile="%{idp.home}/conf/attribute-filter-LEARN-v5.xml"/>
```

then change `…/conf/attribute-resolver.xml` → `…/conf/attribute-resolver-LEARN-v5.xml` in `shibboleth.AttributeResolverResources`, and replace the `attribute-filter.xml` value in `shibboleth.AttributeFilterResources` with `<ref bean="Default-Filter"/>`.

> Use the LEARN **v5** files (as above). If you ever fall back to the v4 files, verify them on IdP 5: after a restart check `logs/idp-process.log` for resolver/filter errors.

Reload and restart:

```bash
cd /opt/shibboleth-idp/bin
./reload-service.sh -id shibboleth.MetadataResolverService
./reload-service.sh -id shibboleth.AttributeFilterService
systemctl restart jetty-idp
```

Then test with https://sp-test.liaf.ac.lk. A successful login shows the consent page and the released attributes (`eppn`, `mail`, `givenName`, `sn`, `schacHomeOrganization`, `uid`, …).

## 10. Release attributes to your own SPs

Add policies to `conf/attribute-filter.xml` (or your own filter file) and run
`./reload-service.sh -id shibboleth.AttributeFilterService`:

```xml
<AttributeFilterPolicy id="exampleSP">
    <PolicyRequirementRule xsi:type="Requester" value="https://sp.YOUR-DOMAIN/shibboleth"/>
    <AttributeRule attributeID="uid"><PermitValueRule xsi:type="ANY"/></AttributeRule>
    <AttributeRule attributeID="mail"><PermitValueRule xsi:type="ANY"/></AttributeRule>
    <AttributeRule attributeID="givenName"><PermitValueRule xsi:type="ANY"/></AttributeRule>
    <AttributeRule attributeID="surname"><PermitValueRule xsi:type="ANY"/></AttributeRule>
</AttributeFilterPolicy>
```

## 11. Branding

Unchanged from v4: customise `messages/messages.properties` (`idp.title`, `idp.footer`, `root.footer`, `idp.logo.alt-text`, `idp.url.password.reset`, `idp.url.helpdesk`), put logos/CSS in `edit-webapp/images` and `edit-webapp/css`, and the Velocity templates in `views/`. After changes:

```bash
JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto /opt/shibboleth-idp/bin/build.sh
chown -R jetty:jetty /opt/shibboleth-idp/war
systemctl restart jetty-idp
```

For quick iteration you can let Apache serve `/idp/images` and `/idp/css` straight from `edit-webapp` (add `ProxyPass /idp/images !`, `ProxyPass /idp/css !` and matching `Alias` lines **above** the `ProxyPass /idp` line, plus a `<Directory>` block granting access) — remove them again when finished.

## Appendix A — Logs

| What | Where |
|---|---|
| Jetty / service | `journalctl -u jetty-idp`, `/var/log/jetty/` |
| IdP process / warnings | `/opt/shibboleth-idp/logs/idp-process.log`, `idp-warn.log` |
| IdP audit / consent | `idp-audit.log`, `idp-consent-audit.log` |
| Apache | `/var/log/apache2/error.log`, `access.log` |

## Appendix B — Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| Jetty won't start, `ClassNotFoundException` for `org.eclipse.jetty.webapp...` | `idp.xml` still uses the Jetty 9 class — use the `ee11` (IdP 5.2+) or `ee9` (5.1.x) class. |
| `ClassNotFoundException: org.eclipse.jetty.ee11.webapp.WebAppContext` (or `ee9`), service restart-loops | `idp.xml` names an EE level whose modules are not enabled in `/opt/jetty/start.d` (typically the base was created with `ee9` modules and `idp.xml` was changed later). Enable the matching modules (see below) and remove the other EE level's `*.ini` files. |
| `NoSuchMethodException: ...ee11.webapp.WebAppContext.setPersistTempDirectory` (or any other `set...` named in `idp.xml`) | That setter does not exist in the ee11 `WebAppContext`. Delete the `<Set name="persistTempDirectory">` line; `idp.xml` only needs `war`, `contextPath`, `extractWAR`, `copyWebDir`, `copyWebInf`. |
| Jetty warns `Use the "forwarded" module instead` | Replace `http-forwarded` by `forwarded` (Jetty 12.1). |
| IdP 5.2.x fails to deploy, Servlet / Spring errors | Jetty is older than 12.1 or the `ee9`/`ee10` modules are enabled. Use Jetty 12.1+ with `ee11-*` modules. |
| `No suitable driver` / `Unable to load JDBC driver` | Driver jar not in `idp.war`, or URL still `jdbc:mysql://`. Re-check §5.3 and §6.3. |
| `ClassNotFoundException: org.apache.commons.dbcp2…` / `…pool2…` | Add the missing jars (§5.3) and rebuild the WAR. |
| `Key import barred by user` / `Could not check signature of distribution` | `--noPrompt` used without a trusted key. Pre-seed `credentials/<plugin id>/truststore.asc` (§5.1) or run `plugin.sh -I …` without `--noPrompt` and answer `yes`. |
| `PlaceholderResolutionException: Could not resolve placeholder 'idp.storage.dbpassword'`; Jetty up on 8080 but `/idp/status` = 503 | `idp.storage.dbpassword` missing/misspelled in `credentials/secrets.properties`, or not readable by `jetty`. See §6.1. |
| `NoSuchBeanDefinitionException: shibboleth.JDBCStorageService` | JDBC Storage plugin not installed, or WAR not rebuilt after installing it. |
| Redirect loops, wrong `http://` links | `forwarded` module missing, or Apache not setting `X-Forwarded-Proto`. |
| `/idp/status` reachable from the internet | `X-Forwarded-For` not reaching Jetty; check §8. |
| Metadata still lists `:8443` endpoints | Finish §6.5 and restart. |
| Let's Encrypt challenge fails | DNS not pointing here, port 80 blocked, or the `RewriteCond` for `/.well-known/acme-challenge/` was removed. |

### Fixing an EE mismatch on an existing Jetty base

```bash
cd /opt/jetty
EE=ee11
runuser -u jetty -- /usr/lib/jvm/java-17-amazon-corretto/bin/java \
  -Djetty.home=/usr/local/src/jetty-src -Djetty.base=/opt/jetty \
  -jar /usr/local/src/jetty-src/start.jar --approve-all-licenses \
  --add-modules=forwarded,${EE}-deploy,${EE}-annotations,${EE}-plus,${EE}-jsp,${EE}-jstl,${EE}-servlets
rm -f /opt/jetty/start.d/ee9-*.ini /opt/jetty/start.d/ee10-*.ini /opt/jetty/start.d/http-forwarded.ini
ls /opt/jetty/start.d
grep -o 'ee[0-9]*' /opt/jetty/webapps/idp.xml | sort -u        # must match $EE
systemctl restart jetty-idp && journalctl -u jetty-idp -n 50 --no-pager
```

## Appendix C — Upgrading Jetty or the IdP later

* **Jetty:** unpack the new `jetty-home-12.x.y`, repoint `/usr/local/src/jetty-src`, `systemctl restart jetty-idp`. Your configuration lives in `/opt/jetty` and is untouched.
* **IdP:** follow the Shibboleth upgrade procedure (re-run `install.sh` from the new distribution against `/opt/shibboleth-idp`, rebuild the WAR, restart). Keep your `edit-webapp` jars.

---

# Automated installation

`install_idpv5_ubuntu_24.sh` performs sections 1–8 (and optionally 9.1–9.2) in one run, prompting for what it needs.

## Files

| File | Purpose |
|---|---|
| `install_idpv5_ubuntu_24.sh` | The installer (run as root) |
| `idp5.env` | Template for non-interactive runs |

## Interactive

```bash
chmod +x install_idpv5_ubuntu_24.sh
sudo ./install_idpv5_ubuntu_24.sh
```

You will be asked for: IdP FQDN, scope (domain), entityID, organisation name (optional), LDAP URL / security mode / base DN / bind DN / **bind password** (hidden) / user filter / optional LDAP certificate, DB name/user/password (blank = generated), TLS mode (`letsencrypt`, `selfsigned`, `existing`), and whether to configure the LEARN federation.

## Using an environment file

The script also understands the **older LEARN variable names** (`idp_server.env` / `idp.env`: `IDP_VER`, `JETTY_VER`, `MYSQL_DB_NAME`, `MYSQL_SHIB_USER`, `MYSQL_SHIB_PASSWORD`, `LDAP_MODE` (`starttls|tls|plain`), `LDAP_FQDN`, `DOMAIN_DC1..3`, `LDAP_BIND_DN_PASSWORD`, `SCHAC_HOME_ORG_TYPE`, `ADMIN_EMAIL`, `INSTITUTE_*`), so an existing file can be passed to `-e` unchanged. Notes on that mapping:

* `MYSQL_ROOT_PASSWORD` and `SSL_KEYSTORE_PASSWORD` are ignored — Apache holds the certificate and MariaDB root uses the unix socket.
* A `JETTY_VER` older than 12.1 is ignored (with a warning) when the IdP is 5.2+.
* The legacy format turns the LEARN federation step **on** by default (as the old script always did).
* `/tmp/ldap_server.crt` is picked up automatically as the LDAP certificate if present.

```bash
cp idp5.env.example idp_server.env
chmod 600 idp_server.env
nano idp_server.env
sudo ./install-idp5.sh -e idp_server.env         # asks only for anything missing
sudo ./install-idp5.sh -e idp_server.env -y       # fully unattended; fails fast if a required value is missing
```

Wrap values that contain `$ ! \` " \` or spaces in **single quotes** (`LDAP_BIND_PASSWORD='p@ss$word'`).

## What the script does

1. Checks root / OS / that the Jetty port is free.
2. Installs Apache, MariaDB, Corretto 17 and helpers (system-wide Java default and `JAVA_HOME` are left alone).
3. Creates the MariaDB database, user and the `shibpid` / `StorageRecords` tables.
4. Downloads the IdP tarball, **verifies its SHA-256**, and runs the installer unattended with generated passwords.
5. Picks the Jetty/EE combination for the IdP version (5.2+ → Jetty 12.1+ with `ee11`; 5.1.x → `ee9`; mismatches are refused), downloads Jetty 12 from Maven Central, **verifies SHA-1**, creates the Jetty base, writes `idp.xml` and the systemd unit.
6. Installs the JDBC Storage plugin, adds the MariaDB driver, builds `idp.war`, and adds `commons-dbcp2`, `commons-pool2` or `spring-jdbc` **only if the WAR lacks them** (Spring version matched to the one in the WAR).
7. Edits `ldap.properties`, `secrets.properties`, `saml-nameid.*`, `idp.properties`, `global.xml`, `logback.xml` and removes `:8443` endpoints from `idp-metadata.xml` (a timestamped backup of `conf/` is taken first).
8. Optionally adds the LEARN metadata providers (`EntityRole` filter), the LEARN **v5** attribute resolver and filter (falls back to v4 with a warning), and patches `schacHomeOrganizationType` and the `YOUR-DOMAIN` placeholder.
9. Fixes ownership, then **validates the configuration** (secrets present, every `%{placeholder}` in `global.xml` / `saml-nameid.xml` defined, `jetty` can read the secrets, MariaDB login works) and refuses to start Jetty if anything fails; then starts `jetty-idp` and waits for `/idp/status` to return 200.
10. (Let's Encrypt mode stops early if the FQDN does not resolve.) Creates the Apache vhosts (80 → 443 redirect, 443 with the `/idp` proxy), obtains/creates the certificate, reloads Apache.
11. Prints a summary and writes `/root/idp5-install-secrets.txt` (mode 600).

Everything is logged to `/var/log/idp5-install.log`. The script is **re-runnable**: existing installs are detected, config edits are idempotent, and the existing DB password is re-used.

## Still manual after the script

* `metadata/idp-metadata.xml` content edits (DisplayName, SLO endpoints) — §6.5
* Branding — §11
* Attribute release for your own SPs — §10
* Registering the IdP with LIAF — §9

## Verification status

**Confirmed on a real test server** (Ubuntu, Jetty 12.1.5 with `ee11` modules, IdP 5.2.x, MariaDB, Apache with Let's Encrypt): the issues found during that run are fixed in this guide and the script — plugin key trust (§5.1), `ee11` module setup and the `forwarded` module (§4), no `persistTempDirectory` in `idp.xml` (§4), and the mandatory `idp.storage.dbpassword` secret (§6.1). After applying them the IdP starts and its metadata is served at `https://idp.YOUR-DOMAIN/idp/shibboleth` through Apache.

**Not yet confirmed end-to-end** — check these on your first full run:

* a complete unattended run of `install-idp5.sh` on a fresh VM (individual steps were exercised, the whole script in one go was not);
* LDAP login, consent storage and stored persistent-id with a real SP (`sp-test.liaf.ac.lk`);
* the LEARN v5 URLs (`fr.ac.lk/templates/...`) and that the LEARN resolver/filter load on your IdP version (check `idp-process.log`);
* the commented `<ref bean=…>` lines in `saml-nameid.xml` / `subject-c14n.xml` match what the script uncomments (it prints a warning if not).
