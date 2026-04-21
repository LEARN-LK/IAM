 
# Shibboleth Identity Provider 5 - Manual Installation - Ubuntu 24

### Prerequisites

Before starting, ensure the following:
* Ubuntu 24.04 LTS (clean server install)
* Root or sudo access
* A fully qualified domain name (FQDN) — e.g. idp.YOUR-DOMAIN.ac.lk
* Internet access to download packages

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

 Expected: openjdk version "17.x.x" ...

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
```

5.4 Set ownership

`chown -R jetty:jetty /opt/jetty-home /opt/jetty-base`

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

7.1 idp.ini (disable deploy scan)

```
cat > /opt/jetty-base/start.d/idp.ini << 'EOF'
jetty.deploy.scanInterval=0
EOF
```

7.2 http.ini (port 80)

```
cat > /opt/jetty-base/start.d/http.ini << 'EOF'
--module=http
jetty.http.port=80
jetty.http.host=0.0.0.0
EOF
```

7.3 ssl.ini (TLS keystore — use password from Phase 5)

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

7.4 https.ini (HTTPS connector)

```
cat > /opt/jetty-base/start.d/https.ini << 'EOF'
--module=https
jetty.https.port=443
EOF
```
7.5 Webapp context descriptor (idp.xml)
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
7.6 Create temp directory

```
mkdir -p /opt/shibboleth-idp/jetty-tmp
chown jetty:jetty /opt/shibboleth-idp/jetty-tmp
```

7.7 Configure logging

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
7.8 Fix ownership of all jetty-base files

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

8.3 Fix ownership

`chown -R jetty:jetty /opt/shibboleth-idp/edit-webapp/`

9. Configure Shibboleth IdP

9.1 Install MySQL and Java connector libraries

```
apt install -y default-mysql-server libmariadb-java \
  libcommons-dbcp2-java libcommons-pool2-java --no-install-recommends

systemctl enable --now mysql
```
Secure MySQL and create the database

 ```
# Set root password first
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'YOUR_ROOT_PASSWORD';"

mysql_secure_installation
```
Create the storageservice database

```
wget https://raw.githubusercontent.com/LEARN-LK/IAM/master/shib-ss-db.sql \
  -O /root/shib-ss-db.sql

# Edit the file — set your preferred DB username and password
vi /root/shib-ss-db.sql

# Import it
mysql -u root -p < /root/shib-ss-db.sql

systemctl restart mysql
```

Link libraries into IdP webapp

```
cd /opt/shibboleth-idp

# IdP 5 uses dbcp2 and pool2 — NOT the old dbcp/pool
ln -s /usr/share/java/mariadb-java-client.jar edit-webapp/WEB-INF/lib/
ln -s /usr/share/java/commons-dbcp2.jar edit-webapp/WEB-INF/lib/
ln -s /usr/share/java/commons-pool2.jar edit-webapp/WEB-INF/lib/

bin/build.sh
```

Configure persistent-id

`vi /opt/shibboleth-idp/conf/saml-nameid.properties`

modify the file 

```
idp.persistentId.sourceAttribute = uid
idp.persistentId.salt = ### result of: openssl rand -base64 36 ###
idp.persistentId.generator = shibboleth.StoredPersistentIdGenerator
idp.persistentId.dataSource = MyDataSource
idp.persistentId.computed = shibboleth.ComputedPersistentIdGenerator
```

Generate the salt:

`openssl rand -base64 36`

 Enable SAML2PersistentGenerator

`/opt/shibboleth-idp/conf/saml-nameid.xml`

 Uncomment this line:

`<ref bean="shibboleth.SAML2PersistentGenerator" />`

 Enable c14n/SAML2Persistent

`<ref bean="c14n/SAML2Persistent" />`

Add JPA beans to global.xml

`vi  /opt/shibboleth-idp/conf/global.xml`

Add before the closing </beans> tag — note dbcp2 class names

```
<!-- DB-independent Configuration -->
<bean id="storageservice.JPAStorageService"
      class="org.opensaml.storage.impl.JPAStorageService"
      p:cleanupInterval="%{idp.storage.cleanupInterval:PT10M}"
      c:factory-ref="storageservice.JPAStorageService.EntityManagerFactory"/>

<bean id="storageservice.JPAStorageService.EntityManagerFactory"
      class="org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean">
    <property name="packagesToScan" value="org.opensaml.storage.impl"/>
    <property name="dataSource" ref="MyDataSource"/>
    <property name="jpaVendorAdapter" ref="storageservice.JPAStorageService.JPAVendorAdapter"/>
    <property name="jpaDialect">
        <bean class="org.springframework.orm.jpa.vendor.HibernateJpaDialect" />
    </property>
</bean>

<!-- DB-dependent Configuration -->
<bean id="storageservice.JPAStorageService.JPAVendorAdapter"
      class="org.springframework.orm.jpa.vendor.HibernateJpaVendorAdapter">
    <property name="database" value="MYSQL" />
</bean>

<!-- DataSource for storageservice DB -->
<bean id="storageservice.JPAStorageService.DataSource"
      class="org.apache.commons.dbcp2.BasicDataSource"
      destroy-method="close" lazy-init="true"
      p:driverClassName="org.mariadb.jdbc.Driver"
      p:url="jdbc:mysql://127.0.0.1:3306/storageservice?useSSL=false&amp;autoReconnect=true&amp;allowPublicKeyRetrieval=true"
      p:username="YOUR_SS_DB_USERNAME"
      p:password="YOUR_SS_DB_PASSWORD"
      p:maxTotal="10"
      p:maxIdle="5"
      p:maxWaitMillis="15000"
      p:testOnBorrow="true"
      p:validationQuery="select 1"
      p:validationQueryTimeout="5" />

<bean id="MyDataSource"
      class="org.apache.commons.dbcp2.BasicDataSource"
      destroy-method="close" lazy-init="true"
      p:driverClassName="org.mariadb.jdbc.Driver"
      p:url="jdbc:mysql://127.0.0.1:3306/storageservice?useSSL=false&amp;autoReconnect=true&amp;allowPublicKeyRetrieval=true"
      p:username="YOUR_SS_DB_USERNAME"
      p:password="YOUR_SS_DB_PASSWORD"
      p:maxTotal="10"
      p:maxIdle="5"
      p:maxWaitMillis="15000"
      p:testOnBorrow="true"
      p:validationQuery="select 1"
      p:validationQueryTimeout="5" />
```

Update idp.properties

`vi /opt/shibboleth-idp/conf/idp.properties`

modify the file

```
idp.consent.StorageService = storageservice.JPAStorageService
idp.session.trackSPSessions = true
idp.session.secondaryServiceIndex = true
```

Verify persistent-id is working

```
# Check logs for any DB connection errors
grep -i "persistentid\|datasource\|storageservice\|error" \
  /opt/shibboleth-idp/logs/idp-process.log | tail -30
```

9.2 Configure LDAP authentication (if using LDAP) 

Login to your openLDAP server as root or with sudo permission.

use `openssl x509 -outform der -in /etc/ssl/certs/ldap_server.pem -out /etc/ssl/certs/ldap_server.crt` to convert the ldap .pem certificate to a .cert.

copy the ldap_server.crt to  `/opt/shibboleth-idp/credentials` of your idp server (HINT : you can use scp from ldap server to idp server to obtain the crt file) Log in to your ldap and then, scp ldap_server.crt <your idp user>@<your idp ip>:/path_to_copy

Next,

`vi /opt/shibboleth-idp/conf/ldap.properties`

Solution 1: LDAP + STARTTLS: (recommended)
```
idp.authn.LDAP.authenticator = bindSearchAuthenticator
idp.authn.LDAP.ldapURL = ldap://your-ldap-server-FQDN:389
idp.authn.LDAP.useStartTLS = true
idp.authn.LDAP.useSSL = false
idp.authn.LDAP.sslConfig = certificateTrust
idp.authn.LDAP.trustCertificates = %{idp.home}/credentials/ldap_server.crt
idp.authn.LDAP.baseDN = ou=people,dc=YOUR-DOMAIN,dc=ac,dc=lk
idp.authn.LDAP.userFilter = (uid={user})
idp.authn.LDAP.bindDN = cn=admin,dc=YOUR-DOMAIN,dc=ac,dc=lk
idp.authn.LDAP.bindDNCredential = ###LDAP_ADMIN_PASSWORD###
idp.attribute.resolver.LDAP.trustCertificates   = %{idp.authn.LDAP.trustCertificates:undefined}
idp.attribute.resolver.LDAP.returnAttributes    = %{idp.authn.LDAP.returnAttributes}
#idp.authn.LDAP.trustStore                       = %{idp.home}/credentials/ldap-server.truststore
idp.authn.LDAP.returnAttributes                 = *
idp.attribute.resolver.LDAP.exportAttributes    =
```

Solution 2: LDAP + TLS:

```
idp.authn.LDAP.authenticator = bindSearchAuthenticator
idp.authn.LDAP.ldapURL = ldaps://LDAP.YOUR-DOMAIN:636
idp.authn.LDAP.useStartTLS = false
idp.authn.LDAP.useSSL = true
idp.authn.LDAP.sslConfig = certificateTrust
idp.authn.LDAP.trustCertificates = %{idp.home}/credentials/ldap_server.crt
idp.authn.LDAP.baseDN = ou=people,dc=YOUR-DOMAIN,dc=ac,dc=lk
idp.authn.LDAP.userFilter = (uid={user})
idp.authn.LDAP.bindDN = cn=admin,dc=YOUR-DOMAIN,dc=ac,dc=lk
idp.authn.LDAP.bindDNCredential = ###LDAP_ADMIN_PASSWORD###
idp.attribute.resolver.LDAP.trustCertificates   = %{idp.authn.LDAP.trustCertificates:undefined}
idp.attribute.resolver.LDAP.returnAttributes    = %{idp.authn.LDAP.returnAttributes}
#idp.authn.LDAP.trustStore                       = %{idp.home}/credentials/ldap_server.truststore
idp.authn.LDAP.returnAttributes                 = *
idp.attribute.resolver.LDAP.exportAttributes    =
```

Solution 3: plain LDAP

```
idp.authn.LDAP.authenticator = bindSearchAuthenticator
idp.authn.LDAP.ldapURL = ldap://LDAP.YOUR-DOMAIN:389
idp.authn.LDAP.useStartTLS = false
idp.authn.LDAP.useSSL = false
idp.authn.LDAP.baseDN = ou=people,dc=YOUR-DOMAIN,dc=ac,dc=lk
idp.authn.LDAP.userFilter = (uid={user})
idp.authn.LDAP.bindDN = cn=admin,dc=YOUR-DOMAIN,dc=ac,dc=lk
idp.authn.LDAP.bindDNCredential = ###LDAP_ADMIN_PASSWORD###
#idp.authn.LDAP.sslConfig = certificateTrust
#idp.authn.LDAP.trustCertificates = %{idp.home}/credentials/ldap-server.crt
idp.attribute.resolver.LDAP.returnAttributes    = %{idp.authn.LDAP.returnAttributes}
#idp.authn.LDAP.trustStore                       = %{idp.home}/credentials/ldap-server.truststore
idp.authn.LDAP.returnAttributes                 = *
idp.attribute.resolver.LDAP.exportAttributes    =
```

Make sure to change dc=YOUR-DOMAIN,dc=ac,dc=lk according to your domain

Enrich IDP logs with the authentication error occurred on LDAP:

`vim /opt/shibboleth-idp/conf/logback.xml`

```
<!-- Logs LDAP related messages -->
<logger name="org.ldaptive" level="${idp.loglevel.ldap:-WARN}"/>

<!-- Logs on LDAP user authentication -->
<logger name="org.ldaptive.auth.Authenticator" level="INFO" />
```

Download the attribute resolver provided by LEARN:

`wget https://fr.ac.lk/signedmetadata/files/attribute-resolver-LEARN-v4.xml -O /opt/shibboleth-idp/conf/attribute-resolver-LEARN-v5.xml`

Download the attribute filter provided by LEARN:

The attribute filter provided by LEARN:

`wget https://fr.ac.lk/signedmetadata/files/attribute-filter-LEARN-v4.xml -O /opt/shibboleth-idp/conf/attribute-resolver-LEARN-v5.xml`


Append your `services.xml` with:

`vim /opt/shibboleth-idp/conf/services.xml`

Add folowing before the closing </beans> Make sure to maintain proper indentation
```
      <bean id="Default-Filter" class="net.shibboleth.ext.spring.resource.FileBackedHTTPResource"
            c:client-ref="shibboleth.FileCachingHttpClient"
            c:url="https://fr.ac.lk/signedmetadata/files/attribute-filter-LEARN-v4.xml"
            c:backingFile="%{idp.home}/conf/attribute-filter-LEARN-v5.xml"/>
```
Modify the shibboleth.AttributeFilterResources util:list
```
      <util:list id ="shibboleth.AttributeFilterResources">
       <!--  <value>%{idp.home}/conf/attribute-filter.xml</value> -->
         <ref bean="Default-Filter"/>
      </util:list>
```

Reload service with id shibboleth.AttributeFilterService to refresh the Attribute Filter followed by the IdP: *  cd /opt/shibboleth-idp/bin *  `./reload-service.sh -id shibboleth.AttributeFilterService`

If you decided to use the Solution 3 of step 28, you have to modify the following code as given, from your Attribute Resolver file:

 ```
  <!-- LDAP Connector -->
   <DataConnector id="myLDAP" xsi:type="LDAPDirectory"
       ldapURL="%{idp.attribute.resolver.LDAP.ldapURL}"
       baseDN="%{idp.attribute.resolver.LDAP.baseDN}"
       principal="%{idp.attribute.resolver.LDAP.bindDN}"
       principalCredential="%{idp.attribute.resolver.LDAP.bindDNCredential}"
       useStartTLS="%{idp.attribute.resolver.LDAP.useStartTLS:true}">
        <!-- trustFile="%{idp.attribute.resolver.LDAP.trustCertificates}" -->
       <FilterTemplate>
           <![CDATA[
               %{idp.attribute.resolver.LDAP.searchFilter}
           ]]>
       </FilterTemplate>
       <!-- <StartTLSTrustCredential id="LDAPtoIdPCredential" xsi:type="sec:X509ResourceBacked">
           <sec:Certificate>%{idp.attribute.resolver.LDAP.trustCertificates}</sec:Certificate>
       </StartTLSTrustCredential> -->
       <ReturnAttributes>%{idp.attribute.resolver.LDAP.returnAttributes}</ReturnAttributes>
   </DataConnector>
```
Change the value of schacHomeOrganizationType,
```
<Attribute id="schacHomeOrganizationType">
      <Value>urn:schac:homeOrganizationType:lk:others</Value>
</Attribute>
```
where value must be either,
```
urn:schac:homeOrganizationType:int:university
urn:schac:homeOrganizationType:int:library
urn:schac:homeOrganizationType:int:public-research-institution
urn:schac:homeOrganizationType:int:private-research-institution
```

Modify services.xml file: vim /opt/shibboleth-idp/conf/services.xml,

` <value>%{idp.home}/conf/attribute-resolver.xml</value>`
	 
must become:

`<value>%{idp.home}/conf/attribute-resolver-LEARN-v5.xml</value>`


Enable the SAML2 support by changing the idp-metadata.xml:

`vim /opt/shibboleth-idp/metadata/idp-metadata.xml`

From the `<IDPSSODescriptor>` session:
From the list of protocolSupportEnumeration delete:

Modify,

 ```
      <mdui:UIInfo>
          <mdui:DisplayName xml:lang="en">Your Institute Name</mdui:DisplayName>
          <mdui:Description xml:lang="en">Enter a description of your IdP</mdui:Description>
      </mdui:UIInfo>
```

9.3 Build the IdP WAR file

```
cd /opt/shibboleth-idp
bin/build.sh
```
 Expected output: BUILD SUCCESSFUL

10. Grant Port Binding Permission

ℹ INFO: On Linux, non-root users cannot bind to ports below 1024. Grant the Java binary the cap_net_bind_service capability.

10.1 Grant capability to Java binary

`setcap cap_net_bind_service=+eip /usr/lib/jvm/java-17-openjdk-amd64/bin/java`

10.2 Verify the capability was set

`getcap /usr/lib/jvm/java-17-openjdk-amd64/bin/java`

 Expected: /usr/lib/jvm/.../bin/java cap_net_bind_service=eip

11. Systemd Service - Jetty

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
 Expected:  Operating normally

12.2 Check ports are bound

`ss -tlnp | grep -E '80|443'`

12.3 Watch IdP logs

`tail -f /opt/shibboleth-idp/logs/idp-process.log`

 Look for: Shibboleth IdP version 5.x.x

12.4 Check Jetty logs if issues occur

```
cat /var/log/jetty/jetty.log
cat /var/log/jetty/jetty-error.log
```
Obtain your IdP metadata here:

`https://idp.YOUR-DOMAIN.AC.LK/idp/shibboleth`

Configure the IdP to retrieve the Federation Metadata:

```
cd /opt/shibboleth-idp/conf
vim metadata-providers.xml
```

Add folowing before the closing </MetadataProvider> Make sure to maintain proper indentation
```
<MetadataProvider
      id="HTTPMD-LEARN-Federation"
      xsi:type="FileBackedHTTPMetadataProvider"
      backingFile="%{idp.home}/metadata/test-metadata.xml"
      metadataURL="https://fr.ac.lk/signedmetadata/metadata.xml">
      <!--
          Verify the signature on the root element of the metadata aggregate
          using a trusted metadata signing certificate.
      -->
      <MetadataFilter xsi:type="SignatureValidation" requireSignedRoot="true" certificateFile="${idp.home}/metadata/federation-cert.pem"/>

      <!--
          Require a validUntil XML attribute on the root element and
          make sure its value is no more than 10 days into the future.
      -->
      <MetadataFilter xsi:type="RequiredValidUntil" maxValidityInterval="P10D"/>

      <!-- Consume all SP metadata in the aggregate -->
      <MetadataFilter xsi:type="EntityRoleWhiteList">
        <RetainedRole>md:SPSSODescriptor</RetainedRole>
      </MetadataFilter>
</MetadataProvider>
<MetadataProvider id="HTTPMD-LEARN-interfederation"
                xsi:type="FileBackedHTTPMetadataProvider"
                backingFile="%{idp.home}/metadata/LEARNmetadata.xml"
                metadataURL="https://fr.ac.lk/signedmetadata/LIAF-interfederation-sp-metadata.xml">

  <MetadataFilter xsi:type="SignatureValidation" requireSignedRoot="true" certificateFile="${idp.home}/metadata/federation-cert.pem"/>
  <MetadataFilter xsi:type="RequiredValidUntil" maxValidityInterval="P11D"/>

      <!-- Consume all SP metadata in the aggregate -->
  <MetadataFilter xsi:type="EntityRoleWhiteList">
      <RetainedRole>md:SPSSODescriptor</RetainedRole>
  </MetadataFilter>
</MetadataProvider>
```

Retrive the Federation Certificate used to verify its signed metadata:

`wget https://fr.ac.lk/signedmetadata/metadata-signer -O /opt/shibboleth-idp/metadata/federation-cert.pem`

Reload service with id shibboleth.MetadataResolverService to retrieve the Federation Metadata:
```
cd /opt/shibboleth-idp/bin
./reload-service.sh -id shibboleth.MetadataResolverService
```
The day after the Federation Operators approval you, check if you can login with your IdP on the following services:

`https://sp-test.liaf.ac.lk`

(Service Provider provided for testing the LEARN Federation)
To be able to log-in, you should continue with the rest of the guide.

### Register you IdP on LIAF:

https://liaf.ac.lk/

Once your membership is approved, you will be sent a federation registry joining link where the form will ask lot of questions to identify your provider. Therefore, answer all of them as per the following,

On the IDP registration page start with pasting the whole xml metadata from https://idp.YOUR-DOMAIN.ac.lk/idp/shibboleth and click next. If you are using a browser to open the metadata link, use its view-source mode to copy the content.

If you have correctly entered metadata you will be asked to select a Federation.

Select "LEARN Identity Federation"

Fill in your contact Details

Go to Organization tab and Fill in all details for language English(en) by clicking "Add in new language" button

Name of organization: Institute XY

Displayname of organization: Institute XY

URL: https://www.YOUR-DOMAIN

Go to Contacts tab and add at least "Support" and "Technical" contacts

On UI Information tab you will see some data extracted from metadata. Apart from those fill-in the rest

Keywords: university or research
For the tutorial put some dummy URL data for Information and Privacy Policy. But in production, you may have to provide your true data
On UI Hints tab you may add your DNS Domain as instXY.ac.lk. Also you may specify your IP blocks or Location

on SAML tab, tick the following on IDPSSODescriptor and AttributeAuthorityDescriptor? sections as Supported Name Identifiers

urn:oasis:names:tc:SAML:2.0:nameid-format:persistent
On Certificates tab, make sure it contains Certificate details, if not start Over by reloading IDP's metadata and pasting them.

Finally click Register.

Your Federation operator will review your application and will proceed with the registration



#### Quick Reference — Key Paths

| Resource			|		Path |

| IdP home			|	/opt/shibboleth-idp |

| IdP config			|	/opt/shibboleth-idp/conf/ |

| IdP logs			|	/opt/shibboleth-idp/logs/ |

| IdP WAR				|	/opt/shibboleth-idp/war/idp.war |

| IdP credentials		|	/opt/shibboleth-idp/credentials/ |

| IdP edit-webapp		|	/opt/shibboleth-idp/edit-webapp/ |

| Jetty home			|	/opt/jetty-home |

| Jetty base			|	/opt/jetty-base |

| Jetty modules config |	/opt/jetty-base/start.d/ |

| Jetty webapp context |	/opt/jetty-base/webapps/idp.xml |

| Jetty logs			|	/var/log/jetty/ |

| Systemd unit		|	/etc/systemd/system/jetty.service |

Important Notes
* Always use the FQDN (not localhost) when testing — Jetty 12 enforces SNI.
* The Shibboleth installer keystore (idp-backchannel.p12) is different from the Jetty SSL keystore (idp.p12). Do not mix them.
* After any change to conf/ files, rebuild the WAR: cd /opt/shibboleth-idp && bin/build.sh
* After rebuilding the WAR, clear the temp dir and restart: rm -rf /opt/shibboleth-idp/jetty-tmp/* && systemctl restart jetty
* Use parentLoaderPriority=false in idp.xml to ensure the IdP's own classes take priority over Jetty's.
* JSTL jars must go inside edit-webapp/WEB-INF/lib — NOT in Jetty's lib/ext (causes classloader conflicts).
