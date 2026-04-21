 
# Shibboleth Identity Provider 5 - Manual Installation - Ubuntu 24
Installation & Configuration Guide with Jetty 12
* Ubuntu Server 24.04 LTS
* Jetty 12 EE10
* Java 17 

### Prerequisites

Before starting, ensure the following:
•	Ubuntu 24.04 LTS (clean server install)
•	Root or sudo access
•	A fully qualified domain name (FQDN) — e.g. idp.YOUR-DOMAIN.ac.lk
•	Internet access to download packages

System Preparation
⚠ NOTE: Run all commands as root or prefix with sudo.

1. Update system packages
`apt update && apt upgrade -y`

2. Install required dependencies
`apt install -y curl wget unzip gnupg2 apt-transport-https ca-certificates software-properties-common ntp`

3. Set the system hostname
```
hostnamectl set-hostname idp.YOUR-DOMAIN.ac.lk
echo "127.0.1.1  idp.YOUR-DOMAIN.ac.lk" >> /etc/hosts
```
4. Install Java 17
ℹ INFO: Shibboleth IdP 5 requires Java 17 or higher. OpenJDK 17 is recommended.

4.1 Install OpenJDK 17
`apt install -y openjdk-17-jdk-headless`

4.2 Verify Java version
`java -version`
# Expected: openjdk version "17.x.x" ...

4.3 Set JAVA_HOME globally
```
echo 'JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> /etc/environment
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> /etc/profile.d/java.sh
source /etc/profile.d/java.sh
```
5. Install Jetty 12
⚠ NOTE: Shibboleth IdP 5 requires Jetty 12 with EE10 (Jakarta EE 10). Do NOT use Jetty 9, 10, or 11.

5.1 Create the jetty system user
`useradd -r -m -U -d /opt/jetty -s /bin/false jetty`
5.2 Download Jetty 12
Check https://jetty.org for the latest 12.x version before running.
```
cd /opt
JETTY_VER="12.0.16"
wget https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/${JETTY_VER}/jetty-home-${JETTY_VER}.tar.gz
tar -xzf jetty-home-${JETTY_VER}.tar.gz
ln -s jetty-home-${JETTY_VER} jetty-home
rm jetty-home-${JETTY_VER}.tar.gz
```

5.3 Create Jetty base directory and enable required modules
```
mkdir -p /opt/jetty-base
cd /opt/jetty-base
java -jar /opt/jetty-home/start.jar \
  --add-modules=server,http,https,ee10-deploy,ee10-annotations,\
ee10-cdi,requestlog,rewrite,ssl,console-capture
Step 4 — Set ownership
chown -R jetty:jetty /opt/jetty-home /opt/jetty-base
```
5. Install Shibboleth IdP 5

5.1 Download Shibboleth IdP 5
Check https://shibboleth.net for the latest 5.x version before running.
```
cd /opt
IDP_VER="5.2.1"
wget https://shibboleth.net/downloads/identity-provider/${IDP_VER}/shibboleth-identity-provider-${IDP_VER}.tar.gz
tar -xzf shibboleth-identity-provider-${IDP_VER}.tar.gz
Step 2 — Run the installer
cd shibboleth-identity-provider-${IDP_VER}
bin/install.sh
```
ℹ INFO: The installer will prompt for: 
	Installation directory → /opt/shibboleth-idp
	EntityID → https://idp.example.org/idp/shibboleth
5.2 Set permissions
```
chown -R jetty:jetty /opt/shibboleth-idp
chmod -R 750 /opt/shibboleth-idp
```
6. Generate SSL Certificate - Install Certbot
⚠ NOTE: The Shibboleth installer does NOT create a Jetty SSL certificate. You must create one separately.

```
apt install -y certbot python3-certbot-apache

certbot --apache -d idp.example.org \
  --agree-tos \
  --email admin@example.org \
  --no-eff-email
```
(Certbot will automatically configure Apache's VirtualHost with the cert and set up auto-renewal. Nothing extra needed on the Apache side.)

Convert the same cert to PKCS12 for Jetty

```
openssl pkcs12 -export \
  -in /etc/letsencrypt/live/idp.YOUR-DOMAIN.ac.lk/fullchain.pem \
  -inkey /etc/letsencrypt/live/idp.YOUR-DOMAIN.ac.lk/privkey.pem \
  -out /opt/shibboleth-idp/credentials/idp.p12 \
  -name idp \
  -passout pass:ChangeMeNow123

chown jetty:jetty /opt/shibboleth-idp/credentials/idp.p12
chmod 640 /opt/shibboleth-idp/credentials/idp.p12
```
Deploy hook for auto-renewal

```
cat > /etc/letsencrypt/renewal-hooks/deploy/jetty-idp.sh << 'EOF'
#!/bin/bash
# Sync renewed Let's Encrypt cert to Jetty PKCS12
openssl pkcs12 -export \
  -in /etc/letsencrypt/live/idp.YOUR-DOMAIN.ac.lk/fullchain.pem \
  -inkey /etc/letsencrypt/live/idp.YOUR-DOMAIN.ac.lk/privkey.pem \
  -out /opt/shibboleth-idp/credentials/idp.p12 \
  -name idp \
  -passout pass:ChangeMeNow123

chown jetty:jetty /opt/shibboleth-idp/credentials/idp.p12
chmod 640 /opt/shibboleth-idp/credentials/idp.p12

systemctl restart jetty
EOF

chmod +x /etc/letsencrypt/renewal-hooks/deploy/jetty-idp.sh
```
Test the full renewal pipeline
`certbot renew --dry-run`

(If it completes cleanly, both Apache and Jetty will automatically get the renewed cert every 90 days without any manual intervention.)

7. Configure Jetty for Shibboleth

7.1 — idp.ini (disable deploy scan)
```
cat > /opt/jetty-base/start.d/idp.ini << 'EOF'
jetty.deploy.scanInterval=0
EOF
```
7.2 — http.ini (port 80)
```
cat > /opt/jetty-base/start.d/http.ini << 'EOF'
--module=http
jetty.http.port=80
jetty.http.host=0.0.0.0
EOF
```
7.3 — ssl.ini (TLS keystore — use password from Phase 5)

```
cat > /opt/jetty-base/start.d/ssl.ini << 'EOF'
--module=ssl
jetty.ssl.port=443
jetty.ssl.host=0.0.0.0
jetty.sslContext.keyStorePath=/opt/shibboleth-idp/credentials/idp.p12
jetty.sslContext.keyStorePassword=ChangeMeNow123
jetty.sslContext.keyStoreType=PKCS12
jetty.sslContext.trustStorePath=/opt/shibboleth-idp/credentials/idp.p12
jetty.sslContext.trustStorePassword=ChangeMeNow123
jetty.sslContext.trustStoreType=PKCS12
EOF
chown jetty:jetty /opt/jetty-base/start.d/ssl.ini
```

7.4 — https.ini (HTTPS connector)

```
cat > /opt/jetty-base/start.d/https.ini << 'EOF'
--module=https
jetty.https.port=443
EOF
```
7.5 — Webapp context descriptor (idp.xml)
⚠ NOTE: Use `org.eclipse.jetty.ee10.webapp.WebAppContext` — NOT the ee9 class. This is critical for Jetty 12.
```
mkdir -p /opt/jetty-base/webapps
cat > /opt/jetty-base/webapps/idp.xml << 'EOF'
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

chown jetty:jetty /opt/jetty-base/webapps/idp.xml
```
7.6 — Create temp directory

```mkdir -p /opt/shibboleth-idp/jetty-tmp
chown jetty:jetty /opt/shibboleth-idp/jetty-tmp
```
7.7 — Configure logging
```
cat > /opt/jetty-base/start.d/console-capture.ini << 'EOF'
--module=console-capture
jetty.console-capture.dir=/var/log/jetty
jetty.console-capture.retain=90
jetty.console-capture.append=true
EOF
mkdir -p /var/log/jetty
chown jetty:jetty /var/log/jetty
```
7.8 — Fix ownership of all jetty-base files
`chown -R jetty:jetty /opt/jetty-base/`

8 Add JSTL and JSP Support
⚠ NOTE: Shibboleth IdP 5 requires JSTL and JSP jars that Jetty 12 does not bundle. They must be added inside the IdP webapp.

8.1 Download JSTL jars into the IdP edit-webapp directory
```
mkdir -p /opt/shibboleth-idp/edit-webapp/WEB-INF/lib
 
# JSTL API
wget -O /opt/shibboleth-idp/edit-webapp/WEB-INF/lib/jakarta.servlet.jsp.jstl-api-3.0.0.jar \
  https://repo1.maven.org/maven2/jakarta/servlet/jsp/jstl/jakarta.servlet.jsp.jstl-api/3.0.0/jakarta.servlet.jsp.jstl-api-3.0.0.jar
 
# JSTL implementation
wget -O /opt/shibboleth-idp/edit-webapp/WEB-INF/lib/jakarta.servlet.jsp.jstl-3.0.1.jar \
  https://repo1.maven.org/maven2/org/glassfish/web/jakarta.servlet.jsp.jstl/3.0.1/jakarta.servlet.jsp.jstl-3.0.1.jar
```
8.2 Enable the ee10-jsp module in Jetty
```
cd /opt/jetty-base
java -jar /opt/jetty-home/start.jar --add-modules=ee10-jsp
chown -R jetty:jetty /opt/jetty-base/
```
8.3Fix ownership
`chown -R jetty:jetty /opt/shibboleth-idp/edit-webapp/`

9. Configure Shibboleth IdP

9.1 Edit idp.properties
`vi /opt/shibboleth-idp/conf/idp.properties`
 
# Set these values:
```
idp.entityID= https://idp.example.org/idp/shibboleth
idp.scope= example.org
```
9.2 Configure LDAP authentication (if using LDAP)
`vi /opt/shibboleth-idp/conf/ldap.properties`
 
```
idp.authn.LDAP.authenticator= bindSearchAuthenticator
idp.authn.LDAP.ldapURL= ldap://ldap.example.org:389
idp.authn.LDAP.baseDN= ou=people,dc=example,dc=org
idp.authn.LDAP.subtreeSearch= true
idp.authn.LDAP.userFilter= (uid={user})
idp.authn.LDAP.bindDN= cn=admin,dc=example,dc=org
idp.authn.LDAP.bindDNCredential= YourLDAPPassword
```
9.3 Build the IdP WAR file
```
cd /opt/shibboleth-idp
bin/build.sh
```
# Expected output: BUILD SUCCESSFUL

10. Grant Port Binding Permission
ℹ INFO: On Linux, non-root users cannot bind to ports below 1024. Grant the Java binary the cap_net_bind_service capability.

10.1 Grant capability to Java binary
`setcap cap_net_bind_service=+eip /usr/lib/jvm/java-17-openjdk-amd64/bin/java`

10.2 Verify the capability was set
`getcap /usr/lib/jvm/java-17-openjdk-amd64/bin/java`
# Expected: /usr/lib/jvm/.../bin/java cap_net_bind_service=eip

11. Systemd Service

11.1 Create the systemd unit file
```
cat > /etc/systemd/system/jetty.service << 'EOF'
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
EOF
```
11.2 Enable and start the service
```
systemctl daemon-reload
systemctl enable jetty
systemctl start jetty
sleep 8
systemctl status jetty
```

12 Verify Installation

12.1 Check IdP status

⚠ NOTE: Always use the FQDN, not localhost — Jetty 12 enforces SNI strictly.
curl -k --resolve idp.example.org:443:127.0.0.1 https://idp.YOUR-DOMAIN.ac.lk/idp/status
# Expected: ## Operating normally

12.2 Check ports are bound

`ss -tlnp | grep -E '80|443'`
12.3 Watch IdP logs
`tail -f /opt/shibboleth-idp/logs/idp-process.log`

# Look for: Shibboleth IdP version 5.x.x

12.4 Check Jetty logs if issues occur

```
cat /var/log/jetty/jetty.log
cat /var/log/jetty/jetty-error.log
```
#### Quick Reference — Key Paths

Resource					Path
IdP home				/opt/shibboleth-idp
IdP config				/opt/shibboleth-idp/conf/
IdP logs				/opt/shibboleth-idp/logs/
IdP WAR					/opt/shibboleth-idp/war/idp.war
IdP credentials			/opt/shibboleth-idp/credentials/
IdP edit-webapp			/opt/shibboleth-idp/edit-webapp/
Jetty home				/opt/jetty-home
Jetty base				/opt/jetty-base
Jetty modules config	/opt/jetty-base/start.d/
Jetty webapp context	/opt/jetty-base/webapps/idp.xml
Jetty logs				/var/log/jetty/
Systemd unit			/etc/systemd/system/jetty.service

Important Notes
•	Always use the FQDN (not localhost) when testing — Jetty 12 enforces SNI.
•	The Shibboleth installer keystore (idp-backchannel.p12) is different from the Jetty SSL keystore (idp.p12). Do not mix them.
•	After any change to conf/ files, rebuild the WAR: cd /opt/shibboleth-idp && bin/build.sh
•	After rebuilding the WAR, clear the temp dir and restart: rm -rf /opt/shibboleth-idp/jetty-tmp/* && systemctl restart jetty
•	Use parentLoaderPriority=false in idp.xml to ensure the IdP's own classes take priority over Jetty's.
•	JSTL jars must go inside edit-webapp/WEB-INF/lib — NOT in Jetty's lib/ext (causes classloader conflicts).
