To Be Updated


Based on [IDEM-TUTORIALS](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO%20Install%20and%20Configure%20a%20Shibboleth%20IdP%20v4.x%20on%20Debian-Ubuntu%20Linux%20with%20Apache2%20%2B%20Jetty9.md#configure-shibboleth-identity-provider-to-release-the-persistent-nameid) by Marco Malavolti 

## Requirements

### Hardware

- CPU: 2 Core (64 bit)
- RAM: 4 GB
- HDD: 20 GB
OS:Ubuntu 22.04

#### Other

- SSL Credentials: HTTPS Certificate & Key
- Logo:
     - size: 80x60 px (or other that respect the aspect-ratio)
     - format: PNG
     - style: with a transparent background
- Favicon:
     - size: 16x16 px (or other that respect the aspect-ratio)
     - format: PNG
     - style: with a transparent background

### Software that will be installed

- ca-certificates
- ntp
- vim
- Amazon Corretto 11 JDK
- jetty 9.4.x
- apache2 (>= 2.4)
- openssl
- gnupg
- libservlet3.1-java
- liblogback-java
- default-mysql-server (if JPAStorageService is used)
- libmariadb-java (if JPAStorageService is used)
- libcommons-dbcp-java (if JPAStorageService is used)
- libcommons-pool-java (if JPAStorageService is used)

## Install Instructions

### Install software requirements

Installation assumes you have already installed Ubuntu Server 18.04 with default configuration and has a public IP connectivity with DNS setup

Lets Assume your server hostname as **idp.YOUR-DOMAIN**

All commands are to be run as **root** and you may use `sudo su`, to become root

1. Update packages:

    * ```apt update && apt-get upgrade -y --no-install-recommends```

2. Install the required packages:


    * ```apt install vim wget gnupg ca-certificates openssl apache2 ntp libservlet3.1-java liblogback-java --no-install-recommends```

3. Install Amazon Corretto JDK:
```bash
wget -O- https://apt.corretto.aws/corretto.key | sudo apt-key add -

apt-get install software-properties-common

add-apt-repository 'deb https://apt.corretto.aws stable main'

apt-get update; sudo apt-get install -y java-11-amazon-corretto-jdk

java -version
```
4. Check that Java is working:

(It will return something like this "```There is only one alternative in link group java (providing /usr/bin/java):```" )

5. Configure the environment

(Be sure that your firewall is not blocking the traffic on port 443 and 80 for the IdP server.)

6. Set the IdP hostname:

ATTENTION: Replace idp.YOURDOMAIN.ac.lk with your IdP Full Qualified Domain Name and HOSTNAME with the IdP hostname

    * ```vim /etc/hosts```

     ``` <YOUR SERVER IP ADDRESS> idp.YOURDOMAIN.ac.lk <HOSTNAME> ```
     
    * ```hostnamectl set-hostname <HOSTNAME>```
    
7. Set the variable JAVA_HOME in /etc/environment:
 
     *Set JAVA_HOME:
```bash
echo 'JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto' > /etc/environment

source /etc/environment

export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto

echo $JAVA_HOME
```
#### Install Shibboleth Identity Provider v4.x

8. Download the Shibboleth Identity Provider

    * ```cd /usr/local/src```
    * ``` wget https://shibboleth.net/downloads/identity-provider/4.2.1/sshibboleth-identity-provider-4.2.1.tar.gz```
    *``` tar -xzf shibboleth-identity-provider-4.2.1.tar.gz```

9. Generate Passwords for later use in the installation, You will need two password strings, ###PASSWORD-FOR-BACKCHANNEL### and ###PASSWORD-FOR-COOKIE-ENCRYPTION### for step 11

  * ``` tr -c -d '0123456789abcdefghijklmnopqrstuvwxyz' </dev/urandom | dd bs=32 count=1 2>/dev/null;echo ```

10. Run the installer ```install.sh```:

    * ``` cd /usr/local/src/shibboleth-identity-provider-4.2.1```
    * ``` bash install.sh -Didp.host.name=$(hostname -f) -Didp.keysize=3072```
ATTENTION: Replace the default value of 'Attribute Scope' with the domain name of your institution.

```bash
root@idp:/usr/local/src/shibboleth-identity-provider-4.2.1# ./bin/install.sh
Source (Distribution) Directory: [/usr/local/src/shibboleth-identity-provider-4.2.1]
Installation Directory: [/opt/shibboleth-idp]
Hostname: [localhost.localdomain]
idp.YOUR-DOMAIN
SAML EntityID: [https://idp.YOUR-DOMAIN/idp/shibboleth]
Attribute Scope: [localdomain]
YOUR-DOMAIN
Backchannel PKCS12 Password: ###PASSWORD-FOR-BACKCHANNEL###
Re-enter password:           ###PASSWORD-FOR-BACKCHANNEL###
Cookie Encryption Key Password: ###PASSWORD-FOR-COOKIE-ENCRYPTION###
Re-enter password:              ###PASSWORD-FOR-COOKIE-ENCRYPTION###
```
By starting from this point, the variable idp.home refers to the directory: ```/opt/shibboleth-idp```

Save the ```###PASSWORD-FOR-BACKCHANNEL###``` value somewhere to be able to find it when you need it.

#### Install Jetty 9 Web Server

11. Download and Extract Jetty:

```bash
cd /usr/local/src

wget https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-distribution/9.4.43.v20210629/jetty-distribution-9.4.43.v20210629.tar.gz

tar xzvf jetty-distribution-9.4.43.v20210629.tar.gz
```
12. Create the ```jetty-src``` folder as a symbolic link. It will be useful for future Jetty updates:

```ln -nsf jetty-distribution-9.4.43.v20210629 jetty-src```

12. Create the system user jetty that can run the web server (without home directory):

``` useradd -r -M jetty```
13. Create your custom Jetty configuration that overrides the default one and will survive upgrades:

```bash
mkdir /opt/jetty

wget https://registry.idem.garr.it/idem-conf/shibboleth/IDP4/jetty/start.ini -O /opt/jetty/start.ini
```
14.Create the TMPDIR directory used by Jetty:
   ```bash
   mkdir /opt/jetty/tmp ; chown jetty:jetty /opt/jetty/tmp
   
   chown -R jetty:jetty /opt/jetty /usr/local/src/jetty-src
   ```
   
15. Create the Jetty Log's folder:
   ```bash
   mkdir /var/log/jetty
   
   mkdir /opt/jetty/logs
   
   chown jetty:jetty /var/log/jetty /opt/jetty/logs
   ```
16. Configure **/etc/default/jetty**:
   ```bash
   sudo bash -c 'cat > /etc/default/jetty <<EOF
   JETTY_HOME=/usr/local/src/jetty-src
   JETTY_BASE=/opt/jetty
   JETTY_USER=jetty
   JETTY_START_LOG=/var/log/jetty/start.log
   TMPDIR=/opt/jetty/tmp
   EOF'
   ```
   
17. Create the service loadable from command line:
   ```bash
   cd /etc/init.d
   
   ln -s /usr/local/src/jetty-src/bin/jetty.sh jetty
   
   update-rc.d jetty defaults
   ```
 18.Check if all settings are OK:
    * `service jetty check`   (Jetty NOT running)
    * `service jetty start`
    * `service jetty check`   (Jetty running pid=XXXX)

    If you receive an error likes "*Job for jetty.service failed because the control process exited with error code. See "systemctl status jetty.service" and "journalctl -xe" for details.*", try this:
      * `rm /var/run/jetty.pid`
      * `systemctl start jetty.service`
      
## Configuration Instructions

### Configure Jetty

19.Configure the IdP Context Descriptor:
   ```bash
   mkdir /opt/jetty/webapps
   
   sudo bash -c 'cat > /opt/jetty/webapps/idp.xml <<EOF
   <Configure class="org.eclipse.jetty.webapp.WebAppContext">
     <Set name="war"><SystemProperty name="idp.home"/>/war/idp.war</Set>
     <Set name="contextPath">/idp</Set>
     <Set name="extractWAR">false</Set>
     <Set name="copyWebDir">false</Set>
     <Set name="copyWebInf">true</Set>
     <Set name="persistTempDirectory">false</Set>
   </Configure>
   EOF'
   ```
   
  20. Make the **jetty** user owner of IdP main directories:
   ```bash
   cd /opt/shibboleth-idp

   chown -R jetty logs/ metadata/ credentials/ conf/ war/
   ```
   
  21.Restart Jetty:
   * `systemctl restart jetty.service`

### Configure SSL on Apache2 (front-end of Jetty)

The Apache HTTP Server will be configured as a reverse proxy and it will be used for SSL offloading.

22. Create a new configuration file as idp.conf with the following:

```bash
<VirtualHost *:80>
  ServerName idp.YOUR-DOMAIN
  ServerAdmin admin@YOUR-DOMAIN
  DocumentRoot /var/www/html
</VirtualHost>
```
 
   Enable Apache2 modules:
   * ```a2enmod proxy_http ssl headers alias include negotiation```
   
   Enable IDP site config:
   * ```a2ensite idp```
   
   Restart the Apache service:
   * ```service apache2 restart```

23. Install Letsencrypt and enable HTTPS:

   * ```add-apt-repository ppa:certbot/certbot```
   * ```apt install python-certbot-apache```
   * ```certbot --apache -d idp.YOUR-DOMAIN```
   
   ```
   Plugins selected: Authenticator apache, Installer apache
   Enter email address (used for urgent renewal and security notices) (Enter 'c' to
   cancel): YOU@YOUR-DOMAIN
   - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Please read the Terms of Service at
   https://letsencrypt.org/documents/LE-SA-v1.2-November-15-2017.pdf. You must
   agree in order to register with the ACME server at
   https://acme-v02.api.letsencrypt.org/directory
   - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   (A)gree/(C)ancel: A

   - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Would you be willing to share your email address with the Electronic Frontier
   Foundation, a founding partner of the Let's Encrypt project and the non-profit
   organization that develops Certbot? We'd like to send you email about our work
   encrypting the web, EFF news, campaigns, and ways to support digital freedom.
   - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   (Y)es/(N)o: Y
   
   Obtaining a new certificate
   Performing the following challenges:
http-01 challenge for idp.YOUR-DOMAIN
   Waiting for verification...
   Cleaning up challenges
   Created an SSL vhost at /etc/apache2/sites-available/idp-le-ssl.conf
   Enabled Apache socache_shmcb module
   Enabled Apache ssl module
   Deploying Certificate to VirtualHost /etc/apache2/sites-available/idp-le-ssl.conf
   Enabling available site: /etc/apache2/sites-available/idp-le-ssl.conf
   
   
   Please choose whether or not to redirect HTTP traffic to HTTPS, removing HTTP access.
   - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   1: No redirect - Make no further changes to the webserver configuration.
   2: Redirect - Make all requests redirect to secure HTTPS access. Choose this for
   new sites, or if you're confident your site works on HTTPS. You can undo this
   change by editing your web server's configuration.
   - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Select the appropriate number [1-2] then [enter] (press 'c' to cancel): 2
     Redirecting vhost in /etc/apache2/sites-enabled/idp.conf to ssl vhost in /etc/apache2/sites-available/idp-le-ssl.conf
   
   - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Congratulations! You have successfully enabled https://idp.YOUR-DOMAIN

   ```
   
<!--
13. (OPTIONAL) If you haven't follow the letsencrypt method Create a Certificate and a Key self-signed for HTTPS
   * ```mkdir /root/certificates```
   * ```openssl req -x509 -newkey rsa:4096 -keyout /root/certificates/idp-key-server.key -out /root/certificates/idp-cert-server.crt -nodes -days 1095```
   If you purchased SSL certificates from a Public CA, move the Certificate and the Key file for HTTPS server to ```/root/certificates```: 
   
   * ```mv /location-to-crts/idp-cert-server.crt /root/certificates```
   * ```mv /location-to-crts/idp-key-server.key /root/certificates```
   * ```mv /location-to-crts/PublicCA.crt /root/certificates```
   
   Then,
   
   * ```chmod 400 /root/certificates/idp-key-server.key```
   * ```chmod 644 /root/certificates/idp-cert-server.crt```
   * ```chmod 644 /root/certificates/PublicCA.crt```


   Create the file ```/etc/apache2/sites-available/idp-ssl.conf``` as follows:

   ```apache
   <IfModule mod_ssl.c>
      SSLStaplingCache        shmcb:/var/run/ocsp(128000)
      <VirtualHost _default_:443>
        ServerName idp.YOUR-DOMAIN:443
        ServerAdmin admin@example.org
        DocumentRoot /var/www/html
       
        ...
        SSLEngine On
        
        SSLProtocol All -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
        SSLCipherSuite "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH"

        SSLHonorCipherOrder on

        # Disable SSL Compression
        SSLCompression Off
        
        # OCSP Stapling, only in httpd/apache >= 2.3.3
        SSLUseStapling          on
        SSLStaplingResponderTimeout 5
        SSLStaplingReturnResponderErrors off
        
        # Enable HTTP Strict Transport Security with a 2 year duration
        Header always set Strict-Transport-Security "max-age=63072000;includeSubDomains;preload"
        ...
        SSLCertificateFile /root/certificates/idp-cert-server.crt
        SSLCertificateKeyFile /root/certificates/idp-key-server.key
        #SSLCertificateChainFile /root/certificates/publicCA.crt #Uncomment if used.
        ...
      </VirtualHost>
   </IfModule>
   ```
   Enable **proxy_http**, **SSL** and **headers** Apache2 modules:
   * ```a2enmod proxy_http ssl headers alias include negotiation```
   * ```a2ensite idp-ssl.conf```
   

   Configure Apache2 to redirect all on HTTPS:
   * ```vim /etc/apache2/sites-enabled/000-default.conf```
   
   ```apache
   <VirtualHost *:80>
        ServerName "idp.YOUR-DOMAIN"
        Redirect "/" "https://idp.YOUR-DOMAIN/"
   </VirtualHost>
   ``` 
   * ```service apache2 restart```
-->

24.Enable the required Apache2 modules and the virtual hosts:

```bash
a2enmod proxy_http ssl headers alias include negotiation

a2ensite $(hostname -f).conf

a2dissite 000-default.conf default-ssl

systemctl restart apache2.service
```
25.Check that IdP metadata is available on:

    *```https://idp.YOURDOMAIN/idp/shibboleth```
    
    
### Configure Shibboleth Identity Provider Storage ###

If you don't change anything, the IdP stores data in a browser session cookie or HTML local storage and encrypt his assertions with AES-GCM encryption algorithm.

See the configuration files and the Shibboleth documentation for details.

Check IdP Status:

```bash /opt/shibboleth-idp/bin/status.sh ```

This Storage service will memorize User Consent data on persistent database SQL.

Install required packages:

``` apt install default-mysql-server libmariadb-java libcommons-dbcp-java libcommons-pool-java --no-install-recommends ```


Activate MariaDB database service:

```bash
systemctl start mariadb.service
```
Address several security concerns in a default MariaDB installation (if it is not already done):
```bash
mysql_secure_installation
(OPTIONAL) MySQL DB Access without password:

```
```vim /root/.my.cnf```
```bash
[client]
user=root
password=##ROOT-DB-PASSWORD-CHANGEME##
```
Create StorageRecords table on storageservice database:

```wget https://registry.idem.garr.it/idem-conf/shibboleth/IDP4/db/shib-ss-db.sql -O /root/shib-ss-db.sql```

**fill missing data on shib-ss-db.sql before import**

```bash
mysql -u root < /root/shib-ss-db.sql
systemctl restart mariadb.service
```
Rebuild IdP with the needed libraries:

```bash
cd /opt/shibboleth-idp
ln -s /usr/share/java/mariadb-java-client.jar edit-webapp/WEB-INF/lib
ln -s /usr/share/java/commons-dbcp.jar edit-webapp/WEB-INF/lib
ln -s /usr/share/java/commons-pool.jar edit-webapp/WEB-INF/lib
bin/build.sh
```
Enable JPA Storage Service:

```vim /opt/shibboleth-idp/conf/global.xml```

and add the following directives to the tail, just before the last </beans> tag:
```bash
<!-- DB-independent Configuration -->

<bean id="storageservice.JPAStorageService" 
      class="org.opensaml.storage.impl.JPAStorageService"
      p:cleanupInterval="%{idp.storage.cleanupInterval:PT10M}"
      c:factory-ref="storageservice.JPAStorageService.EntityManagerFactory"/>

<bean id="storageservice.JPAStorageService.EntityManagerFactory"
      class="org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean">
      <property name="packagesToScan" value="org.opensaml.storage.impl"/>
      <property name="dataSource" ref="storageservice.JPAStorageService.DataSource"/>
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

<!-- Bean to store IdP data unrelated with persistent identifiers on 'storageservice' database -->

<bean id="storageservice.JPAStorageService.DataSource"
      class="org.apache.commons.dbcp.BasicDataSource" destroy-method="close" lazy-init="true"
      p:driverClassName="org.mariadb.jdbc.Driver"
      p:url="jdbc:mysql://localhost:3306/storageservice?autoReconnect=true"
      p:username="###_SS-USERNAME-CHANGEME_###"
      p:password="###_SS-DB-USER-PASSWORD-CHANGEME_###"
      p:maxActive="10"
      p:maxIdle="5"
      p:maxWait="15000"
      p:testOnBorrow="true"
      p:validationQuery="select 1"
      p:validationQueryTimeout="5" />
  ```
  
⚠️ IMPORTANT:

remember to change ```"###_SS-USERNAME-CHANGEME_###" ```and ```"###_SS-DB-USER-PASSWORD-CHANGEME_###"``` with your DB user and password data

Set the consent storage service to the JPA storage service:

```vim /opt/shibboleth-idp/conf/idp.properties```

```bash
idp.consent.StorageService = storageservice.JPAStorageService
```
Restart Jetty to apply the changes:

```systemctl restart jetty.service```

Check IdP Status:

```bash /opt/shibboleth-idp/bin/status.sh```

#### Configure the Directory (openLDAP or AD) Connection ####

https://github.com/LEARN-LK/IAM/blob/master/Ldap-with-eduperson.md

Connect the openLDAP to the IdP to allow the authentication of the users:

For OpenLDAP:

#### Solution 1 - LDAP + STARTTLS: ####

```vim /opt/shibboleth-idp/credentials/secrets.properties```

```bash
# Default access to LDAP authn and attribute stores. 
idp.authn.LDAP.bindDNCredential              = ###IDPUSER_PASSWORD###
idp.attribute.resolver.LDAP.bindDNCredential = %{idp.authn.LDAP.bindDNCredential:undefined}
```

```vim /opt/shibboleth-idp/conf/ldap.properties```

The ldap.example.org have to be replaced with the FQDN of the LDAP server.

The ```idp.authn.LDAP.baseDN``` and ```idp.authn.LDAP.bindDN``` have to be replaced with the right value.

The property idp.attribute.resolver.LDAP.exportAttributes has to be added into the file and configured with the list of attributes the IdP retrieves directly from LDAP. The list MUST contain the attribute chosen for the persistent-id generation (idp.persistentId.sourceAttribute).

```bash
idp.authn.LDAP.authenticator = bindSearchAuthenticator
idp.authn.LDAP.ldapURL = ldap://ldap.example.org
idp.authn.LDAP.useStartTLS = true
idp.authn.LDAP.sslConfig = certificateTrust
idp.authn.LDAP.trustCertificates = %{idp.home}/credentials/ldap-server.crt
# List of attributes to request during authentication
idp.authn.LDAP.returnAttributes = passwordExpirationTime,loginGraceRemaining
idp.authn.LDAP.baseDN = ou=people,dc=example,dc=org
idp.authn.LDAP.subtreeSearch = false
idp.authn.LDAP.bindDN = cn=idpuser,ou=system,dc=example,dc=org
# The userFilter is used to locate a directory entry to bind against for LDAP authentication.
idp.authn.LDAP.userFilter = (uid={user})

# LDAP attribute configuration, see attribute-resolver.xml
# Note, this likely won't apply to the use of legacy V2 resolver configurations
idp.attribute.resolver.LDAP.ldapURL             = %{idp.authn.LDAP.ldapURL}
idp.attribute.resolver.LDAP.connectTimeout      = %{idp.authn.LDAP.connectTimeout:PT3S}
idp.attribute.resolver.LDAP.responseTimeout     = %{idp.authn.LDAP.responseTimeout:PT3S}
idp.attribute.resolver.LDAP.baseDN              = %{idp.authn.LDAP.baseDN:undefined}
idp.attribute.resolver.LDAP.bindDN              = %{idp.authn.LDAP.bindDN:undefined}
idp.attribute.resolver.LDAP.useStartTLS         = %{idp.authn.LDAP.useStartTLS:true}
idp.attribute.resolver.LDAP.trustCertificates   = %{idp.authn.LDAP.trustCertificates:undefined}
# The searchFilter is is used to find user attributes from an LDAP source
idp.attribute.resolver.LDAP.searchFilter        = (uid=$resolutionContext.principal)
# List of attributes produced by the Data Connector that should be directly exported as resolved IdPAttributes without requiring any <AttributeDefinition>
idp.attribute.resolver.LDAP.exportAttributes    = ### List space-separated of attributes to retrieve directly from the directory ###
```

Paste the content of OpenLDAP certificate into ```/opt/shibboleth-idp/credentials/ldap-server.crt```

Configure the right owner/group with:

```chown jetty:root /opt/shibboleth-idp/credentials/ldap-server.crt ; chmod 600 /opt/shibboleth-idp/credentials/ldap-server.crt```

Restart Jetty to apply the changes:

```systemctl restart jetty.service```

Check IdP Status:

```bash /opt/shibboleth-idp/bin/status.sh```

Proceed with Configure Shibboleth Identity Provider to release the persistent NameID

Solution 2 - LDAP + TLS:

```vim /opt/shibboleth-idp/credentials/secrets.properties```

```bash
# Default access to LDAP authn and attribute stores. 
idp.authn.LDAP.bindDNCredential              = ###IDPUSER_PASSWORD###
idp.attribute.resolver.LDAP.bindDNCredential = %{idp.authn.LDAP.bindDNCredential:undefined}
```
```vim /opt/shibboleth-idp/conf/ldap.properties```

The ```ldap.example.org``` have to be replaced with the FQDN of the LDAP server.

The ```idp.authn.LDAP.baseDN``` and ```idp.authn.LDAP.bindDN``` have to be replaced with the right value.

The property ```idp.attribute.resolver.LDAP.exportAttributes``` has to be added into the file and configured with the list of attributes the IdP retrieves directly from LDAP. The list MUST contain the attribute chosen for the persistent-id generation (```idp.persistentId.sourceAttribute```).

```bash
idp.authn.LDAP.authenticator = bindSearchAuthenticator
idp.authn.LDAP.ldapURL = ldaps://ldap.example.org
idp.authn.LDAP.useStartTLS = false
idp.authn.LDAP.sslConfig = certificateTrust
idp.authn.LDAP.trustCertificates = %{idp.home}/credentials/ldap-server.crt
# List of attributes to request during authentication
idp.authn.LDAP.returnAttributes = passwordExpirationTime,loginGraceRemaining
idp.authn.LDAP.baseDN = ou=people,dc=example,dc=org
idp.authn.LDAP.subtreeSearch = false
idp.authn.LDAP.bindDN = cn=idpuser,ou=system,dc=example,dc=org
# The userFilter is used to locate a directory entry to bind against for LDAP authentication.
idp.authn.LDAP.userFilter = (uid={user})

# LDAP attribute configuration, see attribute-resolver.xml
# Note, this likely won't apply to the use of legacy V2 resolver configurations
idp.attribute.resolver.LDAP.ldapURL             = %{idp.authn.LDAP.ldapURL}
idp.attribute.resolver.LDAP.connectTimeout      = %{idp.authn.LDAP.connectTimeout:PT3S}
idp.attribute.resolver.LDAP.responseTimeout     = %{idp.authn.LDAP.responseTimeout:PT3S}
idp.attribute.resolver.LDAP.baseDN              = %{idp.authn.LDAP.baseDN:undefined}
idp.attribute.resolver.LDAP.bindDN              = %{idp.authn.LDAP.bindDN:undefined}
idp.attribute.resolver.LDAP.useStartTLS         = %{idp.authn.LDAP.useStartTLS:true}
idp.attribute.resolver.LDAP.trustCertificates   = %{idp.authn.LDAP.trustCertificates:undefined}
# The searchFilter is used to find user attributes from an LDAP source
idp.attribute.resolver.LDAP.searchFilter        = (uid=$resolutionContext.principal)
# List of attributes produced by the Data Connector that should be directly exported as resolved IdPAttributes without requiring any <AttributeDefinition>
idp.attribute.resolver.LDAP.exportAttributes    = ### List space-separated of attributes to retrieve directly from the directory ###
```
Paste the content of OpenLDAP certificate into /opt/shibboleth-idp/credentials/ldap-server.crt

Configure the right owner/group with:

```chown jetty:root /opt/shibboleth-idp/credentials/ldap-server.crt ; chmod 600 /opt/shibboleth-idp/credentials/ldap-server.crt```

Restart Jetty to apply the changes:

```systemctl restart jetty.service```

Check IdP Status:

```bash /opt/shibboleth-idp/bin/status.sh```

Proceed with Configure Shibboleth Identity Provider to release the persistent NameID

Solution 3 - plain LDAP:

```vim /opt/shibboleth-idp/credentials/secrets.properties```

```bash
# Default access to LDAP authn and attribute stores. 
idp.authn.LDAP.bindDNCredential              = ###IDPUSER_PASSWORD###
idp.attribute.resolver.LDAP.bindDNCredential = %{idp.authn.LDAP.bindDNCredential:undefined}
```

```vim /opt/shibboleth-idp/conf/ldap.properties```

The ```ldap.example.org``` have to be replaced with the FQDN of the LDAP server.

The ```idp.authn.LDAP.baseDN``` and ```idp.authn.LDAP.bindDN``` have to be replaced with the right value.

The property ```idp.attribute.resolver.LDAP.exportAttributes``` has to be added into the file and configured with the list of attributes the IdP retrieves directly from LDAP. The list MUST contain the attribute chosen for the persistent-id generation (```idp.persistentId.sourceAttribute```).

```bash
idp.authn.LDAP.authenticator = bindSearchAuthenticator
idp.authn.LDAP.ldapURL = ldap://ldap.example.org
idp.authn.LDAP.useStartTLS = false
# List of attributes to request during authentication
idp.authn.LDAP.returnAttributes = passwordExpirationTime,loginGraceRemaining
idp.authn.LDAP.baseDN = ou=people,dc=example,dc=org
idp.authn.LDAP.subtreeSearch = false
idp.authn.LDAP.bindDN = cn=idpuser,ou=system,dc=example,dc=org
# The userFilter is used to locate a directory entry to bind against for LDAP authentication.
idp.authn.LDAP.userFilter = (uid={user})

# LDAP attribute configuration, see attribute-resolver.xml
# Note, this likely won't apply to the use of legacy V2 resolver configurations
idp.attribute.resolver.LDAP.ldapURL             = %{idp.authn.LDAP.ldapURL}
idp.attribute.resolver.LDAP.connectTimeout      = %{idp.authn.LDAP.connectTimeout:PT3S}
idp.attribute.resolver.LDAP.responseTimeout     = %{idp.authn.LDAP.responseTimeout:PT3S}
idp.attribute.resolver.LDAP.baseDN              = %{idp.authn.LDAP.baseDN:undefined}
idp.attribute.resolver.LDAP.bindDN              = %{idp.authn.LDAP.bindDN:undefined}
idp.attribute.resolver.LDAP.useStartTLS         = %{idp.authn.LDAP.useStartTLS:true}
idp.attribute.resolver.LDAP.trustCertificates   = %{idp.authn.LDAP.trustCertificates:undefined}
# The searchFilter is is used to find user attributes from an LDAP source
idp.attribute.resolver.LDAP.searchFilter        = (uid=$resolutionContext.principal)
# List of attributes produced by the Data Connector that should be directly exported as resolved IdPAttributes without requiring any <AttributeDefinition>
idp.attribute.resolver.LDAP.exportAttributes    = ### List space-separated of attributes to retrieve directly from the directory ###
```

Restart Jetty to apply the changes:

```systemctl restart jetty.service```

Check IdP Status:

```bash /opt/shibboleth-idp/bin/status.sh```

### Release the persistentid ###

https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO%20Install%20and%20Configure%20a%20Shibboleth%20IdP%20v4.x%20on%20Debian-Ubuntu%20Linux%20with%20Apache2%20%2B%20Jetty9.md#configure-shibboleth-identity-provider-to-release-the-persistent-nameid

### Configure Shibboleth Identity Provider to release the persistent NameID ###

Enable the generation of the computed persistent-id with:

```vim /opt/shibboleth-idp/conf/saml-nameid.properties```

The sourceAttribute MUST be an attribute, or a list of comma-separated attributes, that uniquely identify the subject of the generated persistent-id.

The sourceAttribute MUST be Stable, Permanent and Not-reassignable attribute.

```bash
# ... other things ...#
# OpenLDAP has the UserID into "uid" attribute
idp.persistentId.sourceAttribute = uid

# Active Directory has the UserID into "sAMAccountName"
#idp.persistentId.sourceAttribute = sAMAccountName
# ... other things ...#

# BASE64 will match Shibboleth V2 values, we recommend BASE32 encoding for new installs.
idp.persistentId.encoding = BASE32
idp.persistentId.generator = shibboleth.ComputedPersistentIdGenerator
```

```vim /opt/shibboleth-idp/conf/saml-nameid.xml```

Uncomment the line:

```<ref bean="shibboleth.SAML2PersistentGenerator" />```

```vim /opt/shibboleth-idp/credentials/secrets.properties```


```idp.persistentId.salt = ### result of command 'openssl rand -base64 36' ###```

Enable the SAML2PersistentGenerator:

```vim /opt/shibboleth-idp/conf/saml-nameid.xml```

Uncomment the line:

```<ref bean="shibboleth.SAML2PersistentGenerator" />```

```vim /opt/shibboleth-idp/conf/c14n/subject-c14n.xml```

Uncomment the line:

```<ref bean="c14n/SAML2Persistent" />```
(OPTIONAL) vim ```/opt/shibboleth-idp/conf/c14n/subject-c14n.properties```

Transform each letter of username, before storing in into the database, to Lowercase or Uppercase by setting the proper constant:

```bash
# Simple username -> principal name c14n
idp.c14n.simple.lowercase = true
#idp.c14n.simple.uppercase = false
idp.c14n.simple.trim = true
```

Restart Jetty to apply the changes:

```systemctl restart jetty.service```

Check IdP Status:

```bash /opt/shibboleth-idp/bin/status.sh```

Proceed with attribute solver

https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO%20Install%20and%20Configure%20a%20Shibboleth%20IdP%20v4.x%20on%20Debian-Ubuntu%20Linux%20with%20Apache2%20%2B%20Jetty9.md#configure-the-attribute-resolver-sample

--------------------------------

#### Configure the attribute resolver (sample) ####

The attribute resolver contains attribute definitions and data connectors that collect information from a variety of sources, combine and transform it, and produce a final collection of IdPAttribute objects, which are an internal representation of user data not specific to SAML or any other supported identity protocol.

Download the sample attribute resolver provided by IDEM GARR AAI Federation Operators (OpenLDAP / Active Directory compliant):

```wget (link for our resolver file) -O /opt/shibboleth-idp/conf/attribute-resolver.xml```
If you decide to use the Solutions plain LDAP/AD, remove or comment the following directives from your Attribute Resolver file:

```bash
Line 1:  useStartTLS="%{idp.attribute.resolver.LDAP.useStartTLS:true}"
Line 2:  trustFile="%{idp.attribute.resolver.LDAP.trustCertificates}"
```

Configure the right owner:

```chown jetty /opt/shibboleth-idp/conf/attribute-resolver.xml```
Restart Jetty to apply the changes:

systemctl restart jetty.service

Check IdP Status:

```bash /opt/shibboleth-idp/bin/status.sh```

Configure Shibboleth Identity Provider to release the eduPersonTargetedID

eduPersonTargetedID is an abstracted version of the SAML V2.0 Name Identifier format of ```"urn:oasis:names:tc:SAML:2.0:nameid-format:persistent"```.

To be able to follow these steps, you need to have followed the previous steps on "persistent" NameID generation.

**Strategy A - Computed mode - using the computed persistent NameID - Recommended**

Check to have the following ```AttributeDefinition``` and the ```DataConnector``` into the attribute-resolver.xml:


```vim /opt/shibboleth-idp/conf/attribute-resolver.xml```

```bash
<!-- ...other things ... -->

<!--  AttributeDefinition for eduPersonTargetedID - Computed Mode  -->

<AttributeDefinition xsi:type="SAML2NameID" nameIdFormat="urn:oasis:names:tc:SAML:2.0:nameid-format:persistent" id="eduPersonTargetedID">
    <InputDataConnector ref="computed" attributeNames="computedId" />
</AttributeDefinition>

<!-- ... other things... -->

<!--  Data Connector for eduPersonTargetedID - Computed Mode  -->

<DataConnector id="computed" xsi:type="ComputedId"
    generatedAttributeID="computedId"
    salt="%{idp.persistentId.salt}"
    algorithm="%{idp.persistentId.algorithm:SHA}"
    encoding="%{idp.persistentId.encoding:BASE32}">

    <InputDataConnector ref="myLDAP" attributeNames="%{idp.persistentId.sourceAttribute}" />

</DataConnector>
```

Create the custom eduPersonTargetedID.properties file:

```wget https://registry.idem.garr.it/idem-conf/shibboleth/IDP4/attributes/custom/eduPersonTargetedID.properties -O /opt/shibboleth-idp/conf/attributes/custom/eduPersonTargetedID.properties```
Set proper owner/group with:

```chown jetty:root /opt/shibboleth-idp/conf/attributes/custom/eduPersonTargetedID.properties```

Restart Jetty to apply the changes:

```systemctl restart jetty.service```

Check IdP Status:

```bash /opt/shibboleth-idp/bin/status.sh```

Proceed with Configure the attribute resolution with Attribute Registry

**Strategy B - Stored mode - using the persistent NameID database**

Check to have the following ```AttributeDefinition``` and the ```DataConnector``` into the attribute-resolver.xml:

```vim /opt/shibboleth-idp/conf/attribute-resolver.xml```

```bash
<!-- ...other things ... -->

<!--  AttributeDefinition for eduPersonTargetedID - Stored Mode  -->

<AttributeDefinition xsi:type="SAML2NameID" nameIdFormat="urn:oasis:names:tc:SAML:2.0:nameid-format:persistent" id="eduPersonTargetedID">
    <InputDataConnector ref="stored" attributeNames="storedId" />
</AttributeDefinition>

<!-- ... other things... -->

<!--  Data Connector for eduPersonTargetedID - Stored Mode  -->

<DataConnector id="stored" xsi:type="StoredId"
   generatedAttributeID="storedId"
   salt="%{idp.persistentId.salt}"
   queryTimeout="0">

   <InputDataConnector ref="myLDAP" attributeNames="%{idp.persistentId.sourceAttribute}" />

   <BeanManagedConnection>MyDataSource</BeanManagedConnection>
</DataConnector>
```
Create the custom eduPersonTargetedID.properties file:

```wget https://registry.idem.garr.it/idem-conf/shibboleth/IDP4/attributes/custom/eduPersonTargetedID.properties -O /opt/shibboleth-idp/conf/attributes/custom/eduPersonTargetedID.properties```

Set proper owner/group with:

```chown jetty:root /opt/shibboleth-idp/conf/attributes/custom/eduPersonTargetedID.properties```

Restart Jetty to apply the changes:

```systemctl restart jetty.service```

Check IdP Status:

```bash /opt/shibboleth-idp/bin/status.sh```

Proceed with Configure the attribute resolution with Attribute Registry

**Configure the attribute resolution with Attribute Registry**

File(s): ```conf/attribute-registry.xml, conf/attributes/default-rules.xml, conf/attribute-resolver.xml, conf/attributes/custom/```

Download ```schac.xml``` into the right location:

```wget our registeryconf/shibboleth/IDP4/attributes/schac.xml -O /opt/shibboleth-idp/conf/attributes/schac.xml```

Set the proper owner/group with:

```chown jetty:root /opt/shibboleth-idp/conf/attributes/schac.xml```

Change the default-rules.xml to include the new schac.xml file in the list:

```vim /opt/shibboleth-idp/conf/attributes/default-rules.xml```

```bash
    <!-- ...other things ... -->

    <import resource="inetOrgPerson.xml" />
    <import resource="eduPerson.xml" />
    <import resource="eduCourse.xml" />
    <import resource="samlSubject.xml" />
    <import resource="schac.xml" />
</beans>
```
Configure Shibboleth IdP Logging

Enrich IDP logs with the authentication error occurred on LDAP:

```bash
sed -i '/^    <logger name="org.ldaptive".*/a \\n    <!-- Logs on LDAP user authentication - ADDED BY IDEM HOWTO -->' /opt/shibboleth-idp/conf/logback.xml
sed -i '/^    <!-- Logs on LDAP user authentication - ADDED BY IDEM HOWTO -->/a \ \ \ \ \<logger name="org.ldaptive.auth.Authenticator" level="INFO" />' /opt/shibboleth-idp/conf/logback.xml
```
Translate IdP messages into preferred language

Translate the IdP messages in your language:

Get the files translated in your language from Shibboleth page
Put '```messages_XX.properties```' downloaded file into ```/opt/shibboleth-idp/messages``` directory

Restart Jetty to apply the changes with 
```systemctl restart jetty.service```

Enrich IdP Login Page with Information and Privacy Policy pages

Add the following two lines into ```views/login.vm```:

```bash
<li class="list-help-item"><a href="#springMessageText("idp.url.infoPage", '#')"><span class="item-marker">&rsaquo;</span> #springMessageText("idp.login.infoPage", "Information page")</a></li>
<li class="list-help-item"><a href="#springMessageText("idp.url.privacyPage", '#')"><span class="item-marker">&rsaquo;</span> #springMessageText("idp.login.privacyPage", "Privacy Policy")</a></li>
```
under the line containing the Anchor:
```bash
<a href="#springMessageText("idp.url.helpdesk", '#')">
Add the new variables defined with lines added at point 1 into messages*.properties files linked to the view view/login.vm:
```

```messages/messages.properties```:

```bash
idp.login.infoPage=Informations
idp.url.infoPage=https://my.organization.it/english-idp-info-page.html
idp.login.privacyPage=Privacy Policy
idp.url.privacyPage=https://my.organization.it/english-idp-privacy-policy.html
```

Rebuild IdP WAR file and Restart Jetty to apply changes:

```bash
cd /opt/shibboleth-idp/bin ; ./build.sh
sudo systemctl restart jetty
```

Change default login page footer text

Change the content of idp.footer variable into messages*.properties files linked to the view ```view/login.vm```:

```messages/messages.properties```:

```bash
idp.footer=Footer text for english version of IdP login page

```


Change the content of idp.url.password.reset and idp.url.helpdesk variables into messages*.properties files linked to the view view/login.vm:

messages/messages.properties:

idp.url.password.reset=CONTENT-FOR-FORGOT-YOUR-PASSWORD-LINK
idp.url.helpdesk=CONTENT-FOR-NEED-HELP-LINK


Modify the IdP metadata to enable only the SAML2 protocol:

The <AttributeAuthorityDescriptor> role is needed ONLY IF you have SPs that use AttributeQuery to request attributes to your IdP.

_Shibboleth documentation _
     reference: https://wiki.shibboleth.net/confluence/display/IDP4/SecurityAndNetworking#SecurityAndNetworking-AttributeQuery
vim /opt/shibboleth-idp/metadata/idp-metadata.xml

- Remove completely the initial default comment

<EntityDescriptor> Section:
  - Remove `validUntil` XML attribute.

<IDPSSODescriptor> Section:
  - Remove completely the comment containing <mdui:UIInfo>. 
  

  - Remove the endpoint:
  <ArtifactResolutionService Binding="urn:oasis:names:tc:SAML:1.0:bindings:SOAP-binding" Location="https://idp.example.org:8443/idp/profile/SAML1/SOAP/ArtifactResolution" index="1">
    (and modify the index value of the next one to “1”)

  - Remove comment from SingleLogoutService endpoints

  - Between the last <SingleLogoutService> and the first <SingleSignOnService> endpoints add these 2 lines:
    <NameIDFormat>urn:oasis:names:tc:SAML:2.0:nameid-format:transient</NameIDFormat>
    <NameIDFormat>urn:oasis:names:tc:SAML:2.0:nameid-format:persistent</NameIDFormat>

    (because the IdP installed with this guide will release transient NameID, by default, and persistent NameID if requested.)

  - Remove the endpoint: 
    <SingleSignOnService Binding="urn:mace:shibboleth:1.0:profiles:AuthnRequest" Location="https://idp.example.org/idp/profile/Shibboleth/SSO"/>

  - Remove all ":8443" from the existing URL (such port is not used anymore)

<AttributeAuthorityDescriptor> Section (Remember what was said at the beginning of this section):
  - From the list "protocolSupportEnumeration" replace the value:
    - urn:oasis:names:tc:SAML:1.1:protocol
    with:
    - urn:oasis:names:tc:SAML:2.0:protocol

  - Uncomment:
    <AttributeService Binding="urn:oasis:names:tc:SAML:2.0:bindings:SOAP" Location="https://idp.example.org/idp/profile/SAML2/SOAP/AttributeQuery"/>

  - Remove the endpoint: 
    <AttributeService Binding="urn:oasis:names:tc:SAML:1.0:bindings:SOAP-binding" Location="https://idp.example.org:8443/idp/profile/SAML1/SOAP/AttributeQuery"/>

  - Remove the comment starting with "If you uncomment..."

  - Remove all ":8443" from the existing URL (such port is not used anymore)
Check that the metadata is available on:

https://idp.example.org/idp/shibboleth
Secure cookies and other IDP data

_Shibboleth Documentation reference: https://wiki.shibboleth.net/confluence/display/IDP4/SecretKeyManagement
The default configuration of the IdP relies on a component called a "DataSealer" which in turn uses an AES secret key to secure cookies and certain other data for the IdPs own use. This key must never be shared with anybody else, and must be copied to every server node making up a cluster. The Java "JCEKS" keystore file stores secret keys instead of public/private keys and certificates and a parallel file tracks the key version number_
     
These instructions will regularly update the secret key (and increase its version) and provide you the capability to push it to cluster nodes and continually maintain the secrecy of the key.

bin/module.sh -t idp.intercept.Consent || bin/module.sh -e idp.intercept.Consent

Enable Consent Module by editing conf/relying-party.xml with the right postAuthenticationFlows:

<bean parent="SAML2.SSO" p:postAuthenticationFlows="attribute-release" /> - to enable only Attribute Release Consent
<bean parent="SAML2.SSO" p:postAuthenticationFlows="#{ {'terms-of-use', 'attribute-release'} }" /> 
     
     
- to enable both

Restart Jetty:

sudo systemctl restart jetty.service
**Appendix B: Import persistent-id from a previous database**

Follow these steps ONLY IF your need to import persistent-id database from another IdP

Create a DUMP of shibpid table from the previous DB shibboleth on the OLD IdP:

cd /tmp
mysqldump --complete-insert --no-create-db --no-create-info -u root -p shibboleth shibpid > /tmp/shibboleth_shibpid.sql
Move the /tmp/shibboleth_shibpid.sql of old IdP into /tmp/shibboleth_shibpid.sql on the new IdP.

Import the content of /tmp/shibboleth_shibpid.sql into database of the new IDP:

cd /tmp ; mysql -u root -p shibboleth < /tmp/shibboleth_shibpid.sql
Delete /tmp/shibboleth_shibpid.sql:

rm /tmp/shibboleth_shibpid.sql
Appendix C: Useful logs to find problems

Follow this if you need to find a problem of your IdP.

Jetty Logs:

cd /opt/jetty/logs
ls -l *.stderrout.log

Shibboleth IdP Logs:

cd /opt/shibboleth-idp/logs
Audit Log: vim idp-audit.log
Consent Log: vim idp-consent-audit.log
Warn Log: vim idp-warn.log
Process Log: vim idp-process.log
Appendix D: Connect an SP with the IdP

Shibboleth Documentation Reference:

https://wiki.shibboleth.net/confluence/display/IDP4/ChainingMetadataProvider
https://wiki.shibboleth.net/confluence/display/IDP4/FileBackedHTTPMetadataProvider
https://wiki.shibboleth.net/confluence/display/IDP4/AttributeFilterConfiguration
https://wiki.shibboleth.net/confluence/display/IDP4/AttributeFilterPolicyConfiguration
Follow these steps IF your organization IS NOT connected to the GARR Network or IF you need to connect directly a Shibboleth Service Provider.

Connect the SP to the IdP by adding its metadata on the metadata-providers.xml configuration file:

vim /opt/shibboleth-idp/conf/metadata-providers.xml

<MetadataProvider id="HTTPMetadata"
                  xsi:type="FileBackedHTTPMetadataProvider"
                  backingFile="%{idp.home}/metadata/sp-metadata.xml"
                  metadataURL="https://sp.example.org/Shibboleth.sso/Metadata"
                  failFastInitialization="false"/>
Adding an AttributeFilterPolicy on the conf/attribute-filter.xml file:

wget https://registry.idem.garr.it/idem-conf/shibboleth/IDP4/idem-example-arp.txt -O /opt/shibboleth-idp/conf/example-arp.txt

cat /opt/shibboleth-idp/conf/example-arp.txt
copy and paste the content into /opt/shibboleth-idp/conf/attribute-filter.xml before the last element </AttributeFilterPolicyGroup>.

Make sure to change "### SP-ENTITYID ###" of the text pasted with the entityID of the Service Provider to connect with the Identity Provider installed.

Restart Jetty to apply changes:

systemctl restart jetty.service
Utilities

AACLI: Useful to understand which attributes will be released to the federated resources

export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
bash /opt/shibboleth-idp/bin/aacli.sh -n <USERNAME> -r <ENTITYID-SP> --saml2
Customize IdP Login page with the institutional logo:

Replace the images found inside /opt/shibboleth-idp/edit-webapp/images without renaming them.

Rebuild IdP war file:

cd /opt/shibboleth-idp/bin ; ./build.sh
Restart Jetty:

sudo systemctl restart jetty.service
Useful Documentation

https://shibboleth.atlassian.net/wiki/spaces/IDP4/pages/1265631699/SpringConfiguration
https://shibboleth.atlassian.net/wiki/spaces/IDP4/pages/1265631633/ConfigurationFileSummary
https://shibboleth.atlassian.net/wiki/spaces/IDP4/pages/1265631710/LoggingConfiguration
https://shibboleth.atlassian.net/wiki/spaces/IDP4/pages/1265631711/AuditLoggingConfiguration
https://shibboleth.atlassian.net/wiki/spaces/IDP4/pages/1265631712/FTICKSLoggingConfiguration
https://shibboleth.atlassian.net/wiki/spaces/IDP4/pages/1265631635/MetadataConfiguration
https://shibboleth.atlassian.net/wiki/spaces/IDP4/pages/1265631611/PasswordAuthnConfiguration
https://shibboleth.atlassian.net/wiki/spaces/IDP4/pages/1265631549/AttributeResolverConfiguration
https://shibboleth.atlassian.net/wiki/spaces/IDP4/pages/1265631572/LDAPConnector
https://shibboleth.atlassian.net/wiki/spaces/IDP4/pages/1272054306/AttributeRegistryConfiguration
https://shibboleth.atlassian.net/wiki/spaces/IDP4/pages/1272054333/TranscodingRuleConfiguration
https://shibboleth.atlassian.net/wiki/spaces/IDP4/pages/1265631675/HTTPResource
https://shibboleth.atlassian.net/wiki/spaces/CONCEPT/pages/948470554/SAMLKeysAndCertificates
https://shibboleth.atlassian.net/wiki/spaces/IDP4/pages/1265631799/SecretKeyManagement
https://shibboleth.atlassian.net/wiki/spaces/IDP4/pages/1265631671/NameIDGenerationConfiguration
https://shibboleth.atlassian.net/wiki/spaces/IDP4/pages/1285914730/GCMEncryption
https://shibboleth.atlassian.net/wiki/spaces/KB/pages/1435927082/Switching+locale+on+the+login+page
https://shibboleth.atlassian.net/wiki/spaces/IDP4/pages/1265631851/WebInterfaces





