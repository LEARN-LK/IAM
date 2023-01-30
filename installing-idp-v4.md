# Shibboleth IdP v4+ on Ubuntu Linux LTS 22.04

Based on [IDEM-TUTORIALS](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO%20Install%20and%20Configure%20a%20Shibboleth%20IdP%20v4.x%20on%20Debian-Ubuntu%20Linux%20with%20Apache2%20%2B%20Jetty9.md) by Marco Malavolti (marco.malavolti@garr.it)

LEARN concluded a workshop on Federated Identity with the introduction of Shibboleth IDP and SP to IAM infrastructure on member institutions. 

Installation assumes you have already installed Ubuntu Server 22.04 with default configuration and has a public IP connectivity with DNS setup

Lets Assume your server hostname as **idp.YOUR-DOMAIN**

All commands are to be run as **root** and you may use `sudo su`, to become root

## Install Instructions

### Install software requirements

1. Become ROOT:
   * `sudo su -`
   

2. Update packages:
   ```bash
   apt update && apt-get upgrade -y --no-install-recommends
   ```
   
3.Install the required packages:
   ```bash
   apt install vim wget gnupg ca-certificates openssl apache2 ntp libservlet3.1-java liblogback-java --no-install-recommends
   ```
   
4. Install Amazon Corretto JDK:
   ```bash
   wget -O- https://apt.corretto.aws/corretto.key | apt-key add -

   apt-get install software-properties-common

   add-apt-repository 'deb https://apt.corretto.aws stable main'

   apt-get update; apt-get install -y java-11-amazon-corretto-jdk

   java -version
   ```
Check that Java is working:
   ```bash
   update-alternatives --config java
   ```
   
   (It will return something like this "`There is only one alternative in link group java (providing /usr/bin/java):`" )

### Configure the environment

1. Become ROOT:
   * `sudo su -`
   
2. Be sure that your firewall **is not blocking** the traffic on port **443** and **80** for the IdP server.

3. Set the IdP hostname:

   (**ATTENTION**: *Replace `idp.example.org` with your IdP Full Qualified Domain Name and `<HOSTNAME>` with the IdP hostname*)

   * `vim /etc/hosts`

     ```bash
     <YOUR SERVER IP ADDRESS> idp.example.org <HOSTNAME>
     ```

   * `hostnamectl set-hostname <HOSTNAME>`
   
4. Set the variable `JAVA_HOME` in `/etc/environment`:
   * Set JAVA_HOME:
     ```bash
     echo 'JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto' > /etc/environment

     source /etc/environment

     export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto

     echo $JAVA_HOME
     ```

### Install Shibboleth Identity Provider v4.x

1. Download the Shibboleth Identity Provider v4.x.y (replace '4.x.y' with the latest version found [here](https://shibboleth.net/downloads/identity-provider/)):
   * `cd /usr/local/src`
   * `wget http://shibboleth.net/downloads/identity-provider/4.x.y/shibboleth-identity-provider-4.x.y.tar.gz`
   * `tar -xzf shibboleth-identity-provider-4.*.tar.gz`
   * `cd shibboleth-identity-provider-4.*.`

2. Generate Passwords for later use in the installation, You will need two password strings, ###PASSWORD-FOR-BACKCHANNEL### and ###PASSWORD-FOR-COOKIE-ENCRYPTION### for step 7.
   * ```tr -c -d '0123456789abcdefghijklmnopqrstuvwxyz' </dev/urandom | dd bs=32 count=1 2>/dev/null;echo```

3. Run the installer `install.sh`:
   > According to [NSA and NIST](https://www.keylength.com/en/compare/), RSA with 3072 bit-modulus is the minimum to protect up to TOP SECRET over than 2030.

   * `cd /usr/local/src/shibboleth-identity-provider-4.x/bin`
   * `bash install.sh -Didp.host.name=$(hostname -f) -Didp.keysize=3072`

  
   ```
   Source (Distribution) Directory: [/usr/local/src/shibboleth-identity-provider-4.x]
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
  
   By starting from this point, the variable **idp.home** refers to the directory: `/opt/shibboleth-idp`
     
     Save the `###PASSWORD-FOR-BACKCHANNEL###` value somewhere to be able to find it when you need it.
     
     The `###PASSWORD-FOR-COOKIE-ENCRYPTION###` will be saved into `/opt/shibboleth-idp/credentials/secrets.properties` as `idp.sealer.storePassword` and `idp.sealer.keyPassword` value.
     
   From this point the variable **idp.home** refers to the directory: ```/opt/shibboleth-idp```

### Install Jetty 9 Web Server
Jetty is a Web server and a Java Servlet container. It will be used to run the IdP application through its WAR file.

1. Become ROOT:
   * `sudo su -`

2. Download and Extract Jetty:
   ```bash
   cd /usr/local/src
   
   wget https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-distribution/9.4.43.v20210629/jetty-distribution-9.4.43.v20210629.tar.gz
   
   tar xzvf jetty-distribution-9.4.43.v20210629.tar.gz
   ```

3. Create the `jetty-src` folder as a symbolic link. It will be useful for future Jetty updates:
   ```bash
   ln -nsf jetty-distribution-9.4.43.v20210629 jetty-src
   ```

4. Create the system user `jetty` that can run the web server (without home directory):
   ```bash
   useradd -r -M jetty
   ```

5. Create your custom Jetty configuration that overrides the default one and will survive upgrades:
   ```bash
   mkdir /opt/jetty
   
   wget https://registry.idem.garr.it/idem-conf/shibboleth/IDP4/jetty/start.ini -O /opt/jetty/start.ini
   ```

6. Create the TMPDIR directory used by Jetty:
   ```bash
   mkdir /opt/jetty/tmp ; chown jetty:jetty /opt/jetty/tmp
   
   chown -R jetty:jetty /opt/jetty /usr/local/src/jetty-src
   ```

7. Create the Jetty Log's folder:
   ```bash
   mkdir /var/log/jetty
   
   mkdir /opt/jetty/logs
   
   chown jetty:jetty /var/log/jetty /opt/jetty/logs
   ```

8. Configure **/etc/default/jetty**:
   ```bash
   bash -c 'cat > /etc/default/jetty <<EOF
   JETTY_HOME=/usr/local/src/jetty-src
   JETTY_BASE=/opt/jetty
   JETTY_USER=jetty
   JETTY_START_LOG=/var/log/jetty/start.log
   TMPDIR=/opt/jetty/tmp
   EOF'
   ```

9. Create the service loadable from command line:
   ```bash
   cd /etc/init.d
   
   ln -s /usr/local/src/jetty-src/bin/jetty.sh jetty
   
   update-rc.d jetty defaults
   ```

10. Check if all settings are OK:
    * `service jetty check`   (Jetty NOT running)
    * `service jetty start`
    * `service jetty check`   (Jetty running pid=XXXX)

    If you receive an error likes "*Job for jetty.service failed because the control process exited with error code. See "systemctl status jetty.service" and "journalctl -xe" for details.*", try this:
      * `rm /var/run/jetty.pid`
      * `systemctl start jetty.service`

## Configuration Instructions

### Configure Jetty

1. Become ROOT:
   * `sudo su -`

2. Configure the IdP Context Descriptor:
   ```bash
   mkdir /opt/jetty/webapps
   
   bash -c 'cat > /opt/jetty/webapps/idp.xml <<EOF
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

3. Make the **jetty** user owner of IdP main directories:
   ```bash
   cd /opt/shibboleth-idp

   chown -R jetty logs/ metadata/ credentials/ conf/ war/
   ```

4. Restart Jetty:
   * `systemctl restart jetty.service`

### Configure SSL on Apache2 with Letsencrypt(front-end of Jetty).

If you do this installation in Lab setup please skip to implementing https with self-signed certificates as described in **step 13**.

10. Disable default apache configuration:
   * ```a2dissite 000-default```
   
11. Create a new configuration file as `idp.conf` with the following:
   * ```vim /etc/apache2/sites-available/idp.conf```
  
   ```apache
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
   
   Create the Apache2 configuration file for IdP:
   * ```vim /etc/apache2/sites-available/idp-proxy.conf``
   
   ```
   <IfModule mod_proxy.c>
  ProxyPreserveHost On
  RequestHeader set X-Forwarded-Proto "https"

  <Location /idp>
    Require all granted
  </Location>

        ProxyPass /idp http://localhost:8080/idp retry=5
        ProxyPassReverse /idp http://localhost:8080/idp retry=5

</IfModule>
   ```
   Enable idp_proxy file 
   * ``` a2ensite idp-proxy.conf ```
   
   Restart the Apache service:
   * ```service apache2 restart```

12. Install Letsencrypt and enable HTTPS:

   * ```apt install python3-certbot-apache```
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
   Redirecting vhost in /etc/apache2/sites-enabled/rr3.conf to ssl vhost in /etc/apache2/sites-available/rr3-le-ssl.conf
   
   - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Congratulations! You have successfully enabled https://idp.YOUR-DOMAIN

   ```

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

If you use ACME (Let's Encrypt):

* ``` ln -s /etc/letsencrypt/live/<SERVER_FQDN>/chain.pem /etc/ssl/certs/ACME-CA.pem ```

### Configure Shibboleth Identity Provider v4 to release the persistent-id (Stored mode)


22. Test IdP by opening a terminal and running these commands:
   * ```cd /opt/shibboleth-idp/bin```
   * ```./status.sh``` (You should see some informations about the IdP installed)

23. Install **MySQL Connector Java** and other useful libraries for MySQL DB (if you don't have them already):

   * ```apt install default-mysql-server libmariadb-java libcommons-dbcp-java libcommons-pool-java --no-install-recommends```

Activate MariaDB database service:

* ```systemctl start mysql.service```

25. Create and prepare the "**shibboleth**" MySQL DB to host the values of the several **persistent-id** and **StorageRecords** MySQL DB to host other useful information about user consent:

    * `mysql_secure_installation`


```
Securing the MySQL server deployment.

Connecting to MySQL using a blank password.

VALIDATE PASSWORD PLUGIN can be used to test passwords
and improve security. It checks the strength of password
and allows the users to set only those passwords which are
secure enough. Would you like to setup VALIDATE PASSWORD plugin?

Press y|Y for Yes, any other key for No: y

There are three levels of password validation policy:

LOW    Length >= 8
MEDIUM Length >= 8, numeric, mixed case, and special characters
STRONG Length >= 8, numeric, mixed case, special characters and dictionary file

Please enter 0 = LOW, 1 = MEDIUM and 2 = STRONG: 1
Please set the password for root here.

New password:

Re-enter new password:

Estimated strength of the password: 50
Do you wish to continue with the password provided?(Press y|Y for Yes, any other key for No) : y
By default, a MySQL installation has an anonymous user,
allowing anyone to log into MySQL without having to have
a user account created for them. This is intended only for
testing, and to make the installation go a bit smoother.
You should remove them before moving into a production
environment.

Remove anonymous users? (Press y|Y for Yes, any other key for No) : y
Success.

Normally, root should only be allowed to connect from
'localhost'. This ensures that someone cannot guess at
the root password from the network.

Disallow root login remotely? (Press y|Y for Yes, any other key for No) : y
Success.

By default, MySQL comes with a database named 'test' that
anyone can access. This is also intended only for testing,
and should be removed before moving into a production
environment.


Remove test database and access to it? (Press y|Y for Yes, any other key for No) : y
 - Dropping test database...
Success.

 - Removing privileges on test database...
Success.

Reloading the privilege tables will ensure that all changes
made so far will take effect immediately.

Reload privilege tables now? (Press y|Y for Yes, any other key for No) : y
Success.

All done!
```

   * log in to your MySQL Server:
     ```mysql -u root -p```
    
```sql
    SET NAMES 'utf8';

    SET CHARACTER SET utf8;

    CREATE DATABASE IF NOT EXISTS shibboleth CHARACTER SET=utf8;

    GRANT ALL PRIVILEGES ON shibboleth.* TO root@localhost IDENTIFIED BY '##ROOT-DB-PASSWORD##';
    GRANT ALL PRIVILEGES ON shibboleth.* TO ##USERNAME##@localhost IDENTIFIED BY '##PASSWORD##';

    FLUSH PRIVILEGES;

    USE shibboleth;

    CREATE TABLE IF NOT EXISTS shibpid
    (
    localEntity VARCHAR(255) NOT NULL,
    peerEntity VARCHAR(255) NOT NULL,
    persistentId VARCHAR(50) NOT NULL,
    principalName VARCHAR(50) NOT NULL,
    localId VARCHAR(50) NOT NULL,
    peerProvidedId VARCHAR(50) NULL,
    creationDate TIMESTAMP NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
    deactivationDate TIMESTAMP NULL default NULL,
    PRIMARY KEY (localEntity, peerEntity, persistentId)
    );

    CREATE TABLE IF NOT EXISTS StorageRecords
    (
    context VARCHAR(255) NOT NULL,
    id VARCHAR(255) NOT NULL,
    expires BIGINT(20) DEFAULT NULL,
    value LONGTEXT NOT NULL,
    version BIGINT(20) NOT NULL,
    PRIMARY KEY (context, id)
    );

    quit
```
     
     
   * Restart mysql service:
     ```service mysql restart```
     
     Rebuild IdP with the needed libraries:
```
cd /opt/shibboleth-idp
ln -s /usr/share/java/mariadb-java-client.jar edit-webapp/WEB-INF/lib
ln -s /usr/share/java/commons-dbcp.jar edit-webapp/WEB-INF/lib
ln -s /usr/share/java/commons-pool.jar edit-webapp/WEB-INF/lib
bin/build.sh
```

26. Enable the generation of the ```persistent-id``` (this replace the deprecated attribute *eduPersonTargetedID*)
   
   * Find and modify the following variables with the given content on,
     * ```vim /opt/shibboleth-idp/conf/saml-nameid.properties```
     
```xml
     idp.persistentId.sourceAttribute = uid
     
     idp.persistentId.salt = ### result of 'openssl rand -base64 36'###
     
     idp.persistentId.generator = shibboleth.StoredPersistentIdGenerator
     
     idp.persistentId.dataSource = MyDataSource
     
     idp.persistentId.computed = shibboleth.ComputedPersistentIdGenerator
```

   * Enable the **SAML2PersistentGenerator**:
     * ```vim /opt/shibboleth-idp/conf/saml-nameid.xml```
     
     Remove the comment from the line containing:
    
     ```xml
     <ref bean="shibboleth.SAML2PersistentGenerator" />
     ```

     * ```vim /opt/shibboleth-idp/conf/c14n/subject-c14n.xml```
     
     Remove the comment to the bean called "**c14n/SAML2Persistent**".
       
     ```xml
     <ref bean="c14n/SAML2Persistent" />
     ```
       
27. Enable **JPAStorageService** for the **StorageService** of the user consent:
   * ```vim /opt/shibboleth-idp/conf/global.xml``` 

and add this piece of code to the tail before the ending \</beans\>:

     ```xml
	    <!-- DB-independent Configuration -->

	<bean id="shibboleth.JPAStorageService" 
	      class="org.opensaml.storage.impl.JPAStorageService"
	      p:cleanupInterval="%{idp.storage.cleanupInterval:PT10M}"
	      c:factory-ref="shibboleth.JPAStorageService.EntityManagerFactory"/>

	<bean id="shibboleth.JPAStorageService.EntityManagerFactory"
	      class="org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean">
	      <property name="packagesToScan" value="org.opensaml.storage.impl"/>
	      <property name="dataSource" ref="shibboleth.JPAStorageService.DataSource"/>
	      <property name="jpaVendorAdapter" ref="shibboleth.JPAStorageService.JPAVendorAdapter"/>
	      <property name="jpaDialect">
		 <bean class="org.springframework.orm.jpa.vendor.HibernateJpaDialect" />
	      </property>
	</bean>

	<!-- DB-dependent Configuration -->

	<bean id="shibboleth.JPAStorageService.JPAVendorAdapter" 
	      class="org.springframework.orm.jpa.vendor.HibernateJpaVendorAdapter">
	      <property name="database" value="MYSQL" />
	</bean>

	<!-- Bean to store IdP data unrelated with persistent identifiers on 'storageservice' database -->

	<bean id="shibboleth.JPAStorageService.DataSource"
	      class="org.apache.commons.dbcp.BasicDataSource" destroy-method="close" lazy-init="true"
	      p:driverClassName="org.mariadb.jdbc.Driver"
	      p:url="jdbc:mysql://localhost:3306/shibboleth?autoReconnect=true"
	      p:username="###_SS-USERNAME-CHANGEME_###"
	      p:password="###_SS-DB-USER-PASSWORD-CHANGEME_###"
	      p:maxActive="10"
	      p:maxIdle="5"
	      p:maxWait="15000"
	      p:testOnBorrow="true"
	      p:validationQuery="select 1"
	      p:validationQueryTimeout="5" />   
	```

     (and modify the "###_SS-USERNAME-CHANGEME_###" and "**PASSWORD**" for your "###_SS-DB-USER-PASSWORD-CHANGEME_###" DB)

   * Modify the IdP configuration file:
     * ```vim /opt/shibboleth-idp/conf/idp.properties```

       ```xml
       idp.session.StorageService = shibboleth.JPAStorageService
       idp.consent.StorageService = shibboleth.JPAStorageService
       idp.replayCache.StorageService = shibboleth.JPAStorageService
       idp.artifact.StorageService = shibboleth.JPAStorageService
       # Track information about SPs logged into
       idp.session.trackSPSessions = true
       # Support lookup by SP for SAML logout
       idp.session.secondaryServiceIndex = true
       ```

       (This will indicate to IdP to store the data collected by User Consent into the "**StorageRecords**" table)


28. Connect the openLDAP to the IdP to allow the authentication of the users:
    * Login to your openLDAP server as root or with sudo permission.
    * use ```openssl x509 -outform der -in /etc/ssl/certs/ldap_server.pem -out /etc/ssl/certs/ldap_server.crt``` to convert the ldap `.pem` certificate to a `.cert`.
    * copy the ldap_server.crt to  ```/opt/shibboleth-idp/credentials``` of your `idp` server
    * Next, edit ```vim /opt/shibboleth-idp/conf/ldap.properties``` with one of the following solutions.


     * Solution 1: LDAP + STARTTLS: (recommended)

       ```xml
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
       ```

     * Solution 2: LDAP + TLS:

       ```xml
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
       ```

     * Solution 3: plain LDAP
  
       ```xml
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
       ```

> Make sure to change ***dc=YOUR-DOMAIN,dc=ac,dc=lk*** according to your domain


29. Enrich IDP logs with the authentication error occurred on LDAP:
   * ```vim /opt/shibboleth-idp/conf/logback.xml```

     ```xml
     <!-- Logs LDAP related messages -->
     <logger name="org.ldaptive" level="${idp.loglevel.ldap:-WARN}"/>

     <!-- Logs on LDAP user authentication -->
     <logger name="org.ldaptive.auth.Authenticator" level="INFO" />
     ```

30. Build the **attribute-resolver.xml** to define which attributes your IdP can manage. Here you can find the **attribute-resolver-LEARN.xml** provided by LEARN:
    * Download the attribute resolver provided by LEARN:
      ```wget https://fr.ac.lk/templates/attribute-resolver-LEARN.xml -O /opt/shibboleth-idp/conf/attribute-resolver-LEARN.xml```

>If you decided to use the Solution 3 of step 28, you have to modify the following code as given, from your Attribute Resolver file:
>```xml
>    <!-- LDAP Connector -->
>    <DataConnector id="myLDAP" xsi:type="LDAPDirectory"
>        ldapURL="%{idp.attribute.resolver.LDAP.ldapURL}"
>        baseDN="%{idp.attribute.resolver.LDAP.baseDN}"
>        principal="%{idp.attribute.resolver.LDAP.bindDN}"
>        principalCredential="%{idp.attribute.resolver.LDAP.bindDNCredential}"
>        useStartTLS="%{idp.attribute.resolver.LDAP.useStartTLS:true}">
>	      <!-- trustFile="%{idp.attribute.resolver.LDAP.trustCertificates}" -->
>        <FilterTemplate>
>            <![CDATA[
>                %{idp.attribute.resolver.LDAP.searchFilter}
>            ]]>
>        </FilterTemplate>
>        <!-- <StartTLSTrustCredential id="LDAPtoIdPCredential" xsi:type="sec:X509ResourceBacked">
>            <sec:Certificate>%{idp.attribute.resolver.LDAP.trustCertificates}</sec:Certificate>
>        </StartTLSTrustCredential> -->
>        <ReturnAttributes>%{idp.attribute.resolver.LDAP.returnAttributes}</ReturnAttributes>
>    </DataConnector>
>```


 * Change the value of `schacHomeOrganizationType`,
      ```xml
      <Attribute id="schacHomeOrganizationType">
            <Value>urn:schac:homeOrganizationType:lk:others</Value>
      </Attribute>
      ```
      where value must be either,
      * urn:schac:homeOrganizationType:int:university
      * urn:schac:homeOrganizationType:int:library
      * urn:schac:homeOrganizationType:int:public-research-institution
      * urn:schac:homeOrganizationType:int:private-research-institution


* Modify `services.xml` file: `vim /opt/shibboleth-idp/conf/services.xml`,
```xml
      <value>%{idp.home}/conf/attribute-resolver.xml</value>
```
  must become:
```xml
      <value>%{idp.home}/conf/attribute-resolver-LEARN.xml</value>
```

* Restart Jetty: 
      ```service restart jetty```

31. Enable the SAML2 support by changing the ```idp-metadata.xml```:

* ```vim /opt/shibboleth-idp/metadata/idp-metadata.xml```
  * From the `<IDPSSODescriptor>` session:
    * From the list of `protocolSupportEnumeration` delete:
      * urn:oasis:names:tc:SAML:1.1:protocol
      * urn:mace:shibboleth:1.0  
    * On `<Extensions>` remove commented text and modify, 
      ```xml  
	     <mdui:UIInfo>
                <mdui:DisplayName xml:lang="en">Your Institute Name</mdui:DisplayName>
                <mdui:Description xml:lang="en">Enter a description of your IdP</mdui:Description>
                <mdui:Logo height="60" width="80">https://idp.YOUR-DOMAIN/logo.png</mdui:Logo>
                <mdui:Logo height="16" width="16">https://idp.YOUR-DOMAIN/logo16.png</mdui:Logo>
            </mdui:UIInfo>
      ```
    * Upload example png files to /var/www/html as logo.png with 80x60 pixel and logo16.png with 16x16 pixel images.
    * Remove the endpoint:
	  
	  `<ArtifactResolutionService Binding="urn:oasis:names:tc:SAML:1.0:bindings:SOAP-binding" Location="https://idp.YOUR-DOMAIN:8443/idp/profile/SAML1/SOAP/ArtifactResolution" index="1"/>`
         
	  (and modify the index value of the next one to “1”)

    * Remove the endpoint: 
      
	  `<SingleSignOnService Binding="urn:mace:shibboleth:1.0:profiles:AuthnRequest" Location="https://idp.YOUR-DOMAIN/idp/profile/Shibboleth/SSO"/>`
	  
    * Remove all ":8443" from the existing URL (such port is not used anymore)
    * Uncomment SingleLogoutService:
      ```xml
          <SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="https://identity.thilinapathirana.xyz/idp/profile/SAML2/Redirect/SLO"/>
          <SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="https://identity.thilinapathirana.xyz/idp/profile/SAML2/POST/SLO"/>
          <SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST-SimpleSign" Location="https://identity.thilinapathirana.xyz/idp/profile/SAML2/POST-SimpleSign/SLO"/>
          <SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:SOAP" Location="https://identity.thilinapathirana.xyz/idp/profile/SAML2/SOAP/SLO"/>
     ```
  * On `<AttributeAuthorityDescriptor>` Section:
    * From the list "protocolSupportEnumeration" replace the value of `urn:oasis:names:tc:SAML:1.1:protocol` with
      * urn:oasis:names:tc:SAML:2.0:protocol

    * Remove the comment from:
          
      `<AttributeService Binding="urn:oasis:names:tc:SAML:2.0:bindings:SOAP" Location="https://idp.YOUR-DOMAIN/idp/profile/SAML2/SOAP/AttributeQuery"/>`
	  
    * Remove the endpoint: 
	 
      `<AttributeService Binding="urn:oasis:names:tc:SAML:1.0:bindings:SOAP-binding" Location="https://idp.YOUR-DOMAIN:8443/idp/profile/SAML1/SOAP/AttributeQuery"/>`

    * Remove all ":8443" from the existing URL (such port is not used anymore)
  * Finally remove all existing commented content from the whole document

     

32. Obtain your IdP metadata here:
    *  ```https://idp.YOUR-DOMAIN/idp/shibboleth```

33. Register you IdP on LIAF:
    * ```https://liaf.ac.lk/```
    * Once your membership is approved, you will be sent a federation registry joining link where the form will ask lot of questions to identify your provider. Therefore, answer all of them as per the following,

    * On the IDP registration page start with pasting the whole xml metadata from https://idp.instXY.ac.lk/idp/shibboleth and click next. If you are using a browser to open the metadata link, use its view-source mode to copy the content.

    * If you have correctly entered metadata you will be asked to select a Federation.

    * Select "LEARN Identity Federation"

    * Fill in your contact Details

    * Go to Organization tab and Fill in all details for language English(en) by clicking "Add in new language" button

    * Name of organization: Institute XY

    * Displayname of organization: Institute XY

    * URL: https://www.YOUR-DOMAIN

    * Go to Contacts tab and add at least "Support" and "Technical" contacts

    * On UI Information tab you will see some data extracted from metadata. Apart from those fill-in the rest
      * Keywords: university or research
      * For the tutorial put some dummy URL data for Information and Privacy Policy. But in production, you may have to provide your true data

    * On UI Hints tab you may add your DNS Domain as instXY.ac.lk. Also you may specify your IP blocks or Location

    * on SAML tab, tick the following on IDPSSODescriptor and AttributeAuthorityDescriptor? sections as Supported Name Identifiers

      * urn:oasis:names:tc:SAML:2.0:nameid-format:persistent

    * On Certificates tab, make sure it contains Certificate details, if not start Over by reloading IDP's metadata and pasting them.

    * Finally click Register.

    * Your Federation operator will review your application and will proceed with the registration

34. Configure the IdP to retrieve the Federation Metadata:
    * ```cd /opt/shibboleth-idp/conf```
    * ```vim metadata-providers.xml``` 
	
	Add folowing before the closing ```</MetadataProvider>``` Make sure to maintain proper indentation 

      ```xml
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

    * Retrive the Federation Certificate used to verify its signed metadata:
    *  ```wget https://fr.ac.lk/signedmetadata/metadata-signer -O /opt/shibboleth-idp/metadata/federation-cert.pem```

    
  
35. Reload service with id ```shibboleth.MetadataResolverService``` to retrieve the Federation Metadata:
    *  ```cd /opt/shibboleth-idp/bin```
    *  ```./reload-service.sh -id shibboleth.MetadataResolverService```


36. The day after the Federation Operators approval you, check if you can login with your IdP on the following services:
    * https://sp-test.liaf.ac.lk    (Service Provider provided for testing the LEARN Federation)
   
    To be able to log-in, you should continue with the rest of the guide.

### Configure Attribute Filters to release the mandatory attributes:

37. Make sure that you have the "```tmp/httpClientCache```" used by "```shibboleth.FileCachingHttpClient```":
    * ```mkdir -p /opt/shibboleth-idp/tmp/httpClientCache ; chown jetty /opt/shibboleth-idp/tmp/httpClientCache```

38. Append your ```services.xml``` with:
    * ```vim /opt/shibboleth-idp/conf/services.xml```
	
	Add folowing before the closing ```</beans>``` Make sure to maintain proper indentation 

      ```xml
      <bean id="Default-Filter" class="net.shibboleth.ext.spring.resource.FileBackedHTTPResource"
            c:client-ref="shibboleth.FileCachingHttpClient"
            c:url="https://fr.ac.lk/templates/attribute-filter-LEARN-Default.xml"
            c:backingFile="%{idp.home}/conf/attribute-filter-LEARN-Default.xml"/>
      <bean id="Production-Filter" class="net.shibboleth.ext.spring.resource.FileBackedHTTPResource"
            c:client-ref="shibboleth.FileCachingHttpClient"
            c:url="https://fr.ac.lk/templates/attribute-filter-LEARN-Production.xml"
            c:backingFile="%{idp.home}/conf/attribute-filter-LEARN-Production.xml"/>
      <bean id="ResearchAndScholarship" class="net.shibboleth.ext.spring.resource.FileBackedHTTPResource"
            c:client-ref="shibboleth.FileCachingHttpClient"
            c:url="https://fr.ac.lk/templates/attribute-filter-rs.xml"
            c:backingFile="%{idp.home}/conf/attribute-filter-rs.xml"/>
      <bean id="CodeOfConduct" class="net.shibboleth.ext.spring.resource.FileBackedHTTPResource"
            c:client-ref="shibboleth.FileCachingHttpClient"
            c:url="https://fr.ac.lk/templates/attribute-filter-coco.xml"
            c:backingFile="%{idp.home}/conf/attribute-filter-coco.xml"/>
      ```
      Modify the **shibboleth.AttributeFilterResources** util:list
```xml
      <util:list id ="shibboleth.AttributeFilterResources">
         <value>%{idp.home}/conf/attribute-filter.xml</value>
         <ref bean="Default-Filter"/>
         <ref bean="Production-Filter"/>
	 <ref bean="ResearchAndScholarship"/>
         <ref bean="CodeOfConduct"/>
      </util:list>
```

39. Reload service with id `shibboleth.AttributeFilterService` to refresh the Attribute Filter followed by the IdP:
    *  `cd /opt/shibboleth-idp/bin`
    *  `./reload-service.sh -id shibboleth.AttributeFilterService`

### Enable Consent Module

40. The consent module is shown when a user logs in to a service for the first time, and asks the user for permission to release the required (and desired) attributes to the service.

    Edit `/opt/shibboleth-idp/conf/idp.properties` to uncomment and modify

```
     idp.consent.compareValues = true
     idp.consent.maxStoredRecords = -1
     idp.consent.storageRecordLifetime = P1Y
```
     
   * Restart the Jetty service by service Jetty restart

   * By changing idp.consent.maxStoredRecords will remove the limit on the number of consent records held (by default, 10) by setting the limit to -1 (no limit)

   * The Storage Record Life Time of 1 year should be sufficient and the consent records would expire after a year.

   * Once you restart the service , the filters defined in step 38 will allow LEARN Federated Services to be authenticated with your IDP.


41. Now you will be allowed to login with your IdP on the following services:
    * https://sp-test.liaf.ac.lk   (Service Provider provided for testing the LIAF)
   
    If your authentication is successed, you should see a consent page asking permission to allow the service provider to read your user data and once you approve it must see the following attributes and similar values amoung the rest of the details.
	  
```
	affiliation = staff@learn.ac.lk
	cn = Thilina Pathirana
	eppn = thilina@learn.ac.lk
	givenName = Thilina
	mail = thilina@learn.ac.lk
	schacHomeOrganization = learn.ac.lk
	sn = Pathirana
	uid = thilina
	unscoped-affiliation = staff
```	  
   If you did not get any of those details or the consent page, please contact LEARN TAC for further support.
	  
	  
### Release Attributes for your Service Providers (SP) in Production Environment

42. If you have any service provider (eg: Moodle) that supports SAML, you may use them to authenticate via your IDP. To do that, edit `/opt/shibboleth-idp/conf/attribute-filter.xml` to include service providers to authenticate your users for their services.

   * Consult Service Provider guidelines and https://fr.ac.lk/templates/attribute-filter-LEARN-Production.xml on deciding what attributes you should release.
   * Instruction to add you moodle installations: https://moodle.org/auth/shibboleth/README.txt

   * Reload shibboleth.AttributeFilterService to apply the new SP
  	  
Eg:
```xml
<!--  Example SP  -->
<AttributeFilterPolicy id="exampleSP">
	<PolicyRequirementRule xsi:type="Requester" value="https://sp.YOUR-DOMAIN/shibboleth"/>
	<AttributeRule attributeID="uid">
		<PermitValueRule xsi:type="ANY"/>
	</AttributeRule>
	<AttributeRule attributeID="email">
		<PermitValueRule xsi:type="ANY"/>
	</AttributeRule>
	<AttributeRule attributeID="givenName">
		<PermitValueRule xsi:type="ANY"/>
	</AttributeRule>
	<AttributeRule attributeID="surname">
		<PermitValueRule xsi:type="ANY"/>
	</AttributeRule>
</AttributeFilterPolicy>
```


### Customization and Branding

The default install of the IdP login screen will display the Shibbolethlogo, a default prompt for username and password, and text saying that this screen should be customized. It is recommand to customize this page to have the proper institution logo and name. To give a consistent professional look, institution may customize the graphics to match the style of their,

- login pages
- onsent pages
- logout pages
- error pages 

Those pages are created as Velocity template under `/opt/shibboleth-idp/views`

Therefore, it is recommended to customize the Velocity pages, adding supplementary images and CSS files as needed

Also the Velocity templates can be configured through message properties defined in message property files on  `/opt/shibboleth-idp/system/messages/messages.properties`  **which should NOT be modified**  because of that,  any customizations should be inserted into `/opt/shibboleth-idp/messages/messages.properties`

least configurations:

`idp.title` - HTML TITLE to use across all of the IdP page templates.  We recommend settings this to something like University of Example Login Service

`idp.logo` - relative path to the logo to render on the templates.  E.g., /images/logo.jpg.
The logo image has to be installed into /opt/shibboleth-idp/edit-webapp/images and the web application WAR file has to be rebuilt with /opt/shibboleth-idp/bin/build.sh

`idp.logo.alt-text` - the ALT text for your logo.  Should be changed from the default value (where the text asks for the logo to be replaced).

`idp.footer` - footer that displays on (almost) all pages.

`root.footer` - footer that displays on some error pages.

Eg:

```java
idp.title = University of Example Login Service
idp.logo = /images/logo.jpg
idp.logo.alt-text = University of Example logo
idp.footer = Copyright University of Example
root.footer = Copyright University of Example
```
Depending on branding requirements, it may be sufficient to edit the CSS files in /opt/shibboleth-idp/edit-webapp/css, or it may be necessary to start editing the template pages.

Please note that the login page and most other pages use /opt/shibboleth-idp/edit-webapp/css/main.css, the consent module uses /opt/shibboleth-idp/edit-webapp/css/consent.css with different element names.


Besides the logo, the login page (and several other pages) display a toolbox on the right with placeholders for links to password-reset and help-desk pages, these can be customized by adding following to the `/opt/shibboleth-idp/messages/messages.properties`

```java
idp.url.password.reset = http://helpdesk.YOUR-DOMAIN/ChangePassword/
idp.url.helpdesk = http://help.YOUR-DOMAIN/
```

Alternatively, it is also possible to hide the whole toolbox (the whole <div class="column two"> element) from all of the relevant pages (essentially, login.vm and all (three) logout pages: logout.vm, logout-complete.vm and logout.propagate).  This can be easily done by adding the following CSS snippet into /opt/shibboleth-idp/edit-webapp/css/main.css:

```css
.column.two {
    display: none;
}
```

For your simplisity in developing, temporary add the following to Apache idp.conf file ( /etc/apache2/sites-available/idp.conf ) to server the requests directly by Apache (avoiding going through Jetty and thus avoiding having to rebuild the WAR file after every change):insert the following right above the ***ProxyPass /idp*** directive:

```apache
ProxyPass /idp/images !
ProxyPass /idp/css !
Alias /idp/images /opt/shibboleth-idp/edit-webapp/images
Alias /idp/css /opt/shibboleth-idp/edit-webapp/css
```

And, as default permissions on Apache 2.4 are more restrictive, grant also explicitly access to the /opt/shibboleth-idp/edit-webapp directory: insert this at the very top of /etc/apache2/sites-available/idp.conf:

```apache
<Directory /opt/shibboleth-idp/edit-webapp>
   Require all granted
</Directory>
```
When done with changes to the images and css directories, remember to rebuild the WAR file and restart Jetty:

```bash
/opt/shibboleth-idp/bin/build.sh
service jetty restart
```

Then remove the temporary additions on idp.conf and restart the apache service.

   
### Appendix: Useful logs to find problems

1. Jetty 9 Logs:
   * ```cd /var/log/jetty```


2. Shibboleth IdP Logs:
   * ```cd /opt/shibboleth-idp/logs```
   * **Audit Log:** ```vim idp-audit.log```
   * **Consent Log:** ```vim idp-consent-audit.log```
   * **Warn Log:** ```vim idp-warn.log```
   * **Process Log:** ```vim idp-process.log```
   
3. Apache Logs:

   * ```cd /var/log/apache2/```
   * **Error Log:** ```tail error.log```
   * **Access Log:** ```tail access.log```
