# Shibboleth IdP v3.3.2 on Ubuntu Linux LTS 18.04

Based on [IDEM-TUTORIALS](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Ubuntu/HOWTO%20Install%20and%20Configure%20a%20Shibboleth%20IdP%20v3.2.1%20on%20Ubuntu%20Linux%20LTS%2016.04%20with%20Apache2%20%2B%20Tomcat8.md) by Marco Malavolti (marco.malavolti@garr.it)

LEARN concluded a workshop on Federated Identity with the introduction of Shibboleth IDP and SP to IAM infrastructure on member institutions. Following are the generalized version of the guides used, originals can be found at [LEARN Workshop CMS](https://ws.learn.ac.lk/wiki/iam2018) 

Installation assumes you have already installed Ubuntu Server 18.04 with default configuration and has a public IP connectivity with DNS setup

Lets Assume your server hostname as **idp.YOUR-DOMAIN**

All commands are to be run as **root** and you may use `sudo su`, to become root

1. Install the packages required: 
   * ```apt-get install vim default-jdk ca-certificates openssl tomcat8 apache2 ntp expat```
   

2. Modify ```/etc/hosts``` and add:
   * ```vim /etc/hosts```
  
     ```bash
     127.0.0.1 idp.YOUR-DOMAIN idp
     ```
   (*Replace ```idp.YOUR-DOMAIN``` with your IdP FQDN, Also remember not to remove the entry for ```localhost```*)

3. Define the costants ```JAVA_HOME``` and ```IDP_SRC``` inside ```/etc/environment```:
   * ```update-alternatives --config java``` (copy the path without /bin/java)
   * ```vim /etc/environment```

     ```bash
     JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
     IDP_SRC=/usr/local/src/shibboleth-identity-provider-3.3.2
     ```
   * ```source /etc/environment```
   * ```export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64```
   * ```export IDP_SRC=/usr/local/src/shibboleth-identity-provider-3.3.2```
  

4. Configure **/etc/default/tomcat8**:
   * ```update-alternatives --config java``` (copy the path without /bin/java)
   * ```update-alternatives --config javac```
   * ```vim /etc/default/tomcat8```
  
     ```bash
     JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
     ...
     JAVA_OPTS="-Djava.awt.headless=true -XX:+DisableExplicitGC -XX:+UseParallelOldGC -Xms256m -Xmx1g -Djava.security.egd=file:/dev/./urandom"
     ```

     (This settings configure the memory of the JVM that will host the IdP Web Application. 
     The Memory value depends on the phisical memory installed on the machine. 
     On production environment Set the "**Xmx**" (max heap space available to the JVM) at least to **2GB**)


5. Download the Shibboleth Identity Provider v3.3.2:
   * ```cd /usr/local/src```
   * ```wget http://shibboleth.net/downloads/identity-provider/3.3.2/shibboleth-identity-provider-3.3.2.tar.gz```
   * ```tar -xzvf shibboleth-identity-provider-3.3.2.tar.gz```
   * ```cd shibboleth-identity-provider-3.3.2```

6. Generate Passwords for later use in the installation, You will need two password strings, ###PASSWORD-FOR-BACKCHANNEL### and ###PASSWORD-FOR-COOKIE-ENCRYPTION### for step 7.
   * ```tr -c -d '0123456789abcdefghijklmnopqrstuvwxyz' </dev/urandom | dd bs=32 count=1 2>/dev/null;echo```
      
7. Run the installer ```install.sh``` to install Shibboleth Identity Provider v3.3.2:
   * ```./bin/install.sh```
  
   ```bash
   root@idp:/usr/local/src/shibboleth-identity-provider-3.3.2# ./bin/install.sh
   Source (Distribution) Directory: [/usr/local/src/shibboleth-identity-provider-3.3.2]
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
  
   From this point the variable **idp.home** refers to the directory: ```/opt/shibboleth-idp```

8. Import the JST libraries to visualize the IdP ```status``` page:
   * ```cd /opt/shibboleth-idp/edit-webapp/WEB-INF/lib```
   * ```wget https://build.shibboleth.net/nexus/service/local/repositories/thirdparty/content/javax/servlet/jstl/1.2/jstl-1.2.jar```
   * ```cd /opt/shibboleth-idp/bin ; ./build.sh -Didp.target.dir=/opt/shibboleth-idp```

9. Change the owner to enable **tomcat8** user to access on the following directories:
   * ```chown -R tomcat8 /opt/shibboleth-idp/logs/```
   * ```chown -R tomcat8 /opt/shibboleth-idp/metadata/```
   * ```chown -R tomcat8 /opt/shibboleth-idp/credentials/```
   * ```chown -R tomcat8 /opt/shibboleth-idp/conf/```


### Configure SSL on Apache2 with Letsencrypt.
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
   
   Restart the Apache service:
   * ```service apache2 restart```

12. Install Letsencrypt and enable HTTPS:

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

### Configure Apache Tomcat 8 to run as the back-end 


14. Modify ```server.xml```:
   * ```vim /etc/tomcat8/server.xml```
  
     Comment out the Connector 8080 (HTTP):
    
     ```xml
     <!-- A "Connector" represents an endpoint by which requests are received
          and responses are returned. Documentation at :
          Java HTTP Connector: /docs/config/http.html (blocking & non-blocking)
          Java AJP  Connector: /docs/config/ajp.html
          APR (HTTP/AJP) Connector: /docs/apr.html
          Define a non-SSL/TLS HTTP/1.1 Connector on port 8080
     -->
     <!--
     <Connector port="8080" protocol="HTTP/1.1"
                connectionTimeout="20000"
                URIEncoding="UTF-8"
                redirectPort="8443" />
     -->
     ```

     Enable the Connector 8009 (AJP):

     ```xml
     <!-- Define an AJP 1.3 Connector on port 8009 -->
     <Connector port="8009" protocol="AJP/1.3" redirectPort="443" address="127.0.0.1" enableLookups="false" tomcatAuthentication="false"/>
     ```
    
     Check the integrity of XML files just edited with:
     ```xmlwf -e UTF-8 /etc/tomcat8/server.xml```

15. Create and change the file ```idp.xml```:
   * ```sudo vim /etc/tomcat8/Catalina/localhost/idp.xml```

     ```xml
     <Context docBase="/opt/shibboleth-idp/war/idp.war"
              privileged="true"
              antiResourceLocking="false"
              swallowOutput="true"/>
     ```

16. Create the Apache2 configuration file for IdP:
   * ```vim /etc/apache2/sites-available/idp-proxy.conf```
  
     ```apache
     <IfModule mod_proxy.c>
       ProxyPreserveHost On
       RequestHeader set X-Forwarded-Proto "https"

       <Proxy ajp://localhost:8009>
         Require all granted
       </Proxy>

       ProxyPass /idp ajp://localhost:8009/idp retry=5
       ProxyPassReverse /idp ajp://localhost:8009/idp retry=5
     </IfModule>
     ```

17. Enable **proxy_ajp** apache2 module and the new IdP site:
   * ```a2enmod proxy_ajp```
   * ```a2ensite idp-proxy.conf```
   * ```service apache2 restart```
  
18. Modify **context.xml** to prevent error of *lack of persistence of the session objects* created by the IdP :
   * ```vim /etc/tomcat8/context.xml```

     and remove the comment from:

     ```<Manager pathname="" />```
    
19. Restart Tomcat8:
   * ```service tomcat8 restart```

20. Verify if the IdP works by opening this page on your browser:
   * ```https://idp.YOUR-DOMAIN/idp/shibboleth``` (you should see the IdP metadata)

> If you see errors please consult log files of Tomcat8, Shibboleth or Apache. Troobleshoot locations are given at the end of this document


### Speed up Tomcat 8 startup

  
21. Find out the JARs that can be skipped from the scanning:
    * ```cd /opt/shibboleth-idp/```
    * ```ls webapp/WEB-INF/lib | awk '{print $1",\\"}'```
  
    Insert the output list into ```/etc/tomcat8/catalina.properties``` at the tail of  ```tomcat.util.scan.StandardJarScanFilter.jarsToSkip```
    Make sure about the  ```,\``` symbols
   
    Restart Tomcat 8:
    * ```service tomcat8 restart```
  

### Configure Shibboleth Identity Provider v3.2.1 to release the persistent-id (Stored mode)


22. Test IdP by opening a terminal and running these commands:
   * ```cd /opt/shibboleth-idp/bin```
   * ```./status.sh``` (You should see some informations about the IdP installed)

23. Install **MySQL Connector Java** and other useful libraries used by Tomcat for MySQL DB (if you don't have them already):
   * ```apt-get install mysql-server libmysql-java libcommons-dbcp-java libcommons-pool-java```
   * ```cd /usr/share/tomcat8/lib/```
   * ```ln -s ../../java/mysql.jar mysql-connector-java.jar```
   * ```ln -s ../../java/commons-pool.jar commons-pool.jar```
   * ```ln -s ../../java/commons-dbcp.jar commons-dbcp.jar```
   * ```ln -s ../../java/tomcat-jbcp.jar tomcat-jbcp.jar```
   Ignore if you get errors for some of the ```ln``` commands as the files might be already there.

24. Rebuild the **idp.war** of Shibboleth with the new libraries:
   * ```cd /opt/shibboleth-idp/ ; ./bin/build.sh```
   You may need to press enter on `Installation Directory: [/opt/shibboleth-idp]`

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

26. Enable the generation of the ```persistent-id``` (this replace the deprecated attribute *eduPersonTargetedID*)
   
    * ```vim /opt/shibboleth-idp/conf/saml-nameid.properties```
   
   (the *sourceAttribute* MUST BE an attribute, or a list of comma-separated attributes, that uniquely identify the subject of the generated ```persistent-id```. It MUST BE: **Stable**, **Permanent** and **Not-reassignable**)

     ```xml
     idp.persistentId.sourceAttribute = uid
     ...
     idp.persistentId.salt = ### result of 'openssl rand -base64 36'###
     ...
     idp.persistentId.generator = shibboleth.StoredPersistentIdGenerator
     ...
     idp.persistentId.dataSource = MyDataSource
     ...
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
   * ```vim /opt/shibboleth-idp/conf/global.xml``` and add this piece of code to the tail before the ending \</beans\>:

     ```xml
     <!-- A DataSource bean suitable for use in the idp.persistentId.dataSource property. -->
     <bean id="MyDataSource" class="org.apache.commons.dbcp.BasicDataSource"
           p:driverClassName="com.mysql.jdbc.Driver"
           p:url="jdbc:mysql://localhost:3306/shibboleth?autoReconnect=true"
           p:username="##USER_DB_NAME##"
           p:password="##PASSWORD##"
           p:maxActive="10"
           p:maxIdle="5"
           p:maxWait="15000"
           p:testOnBorrow="true"
           p:validationQuery="select 1"
           p:validationQueryTimeout="5" />

     <bean id="shibboleth.JPAStorageService" class="org.opensaml.storage.impl.JPAStorageService"
           p:cleanupInterval="%{idp.storage.cleanupInterval:PT10M}"
           c:factory-ref="shibboleth.JPAStorageService.entityManagerFactory"/>

     <bean id="shibboleth.JPAStorageService.entityManagerFactory"
           class="org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean">
           <property name="packagesToScan" value="org.opensaml.storage.impl"/>
           <property name="dataSource" ref="MyDataSource"/>
           <property name="jpaVendorAdapter" ref="shibboleth.JPAStorageService.JPAVendorAdapter"/>
           <property name="jpaDialect">
             <bean class="org.springframework.orm.jpa.vendor.HibernateJpaDialect" />
           </property>
     </bean>

     <bean id="shibboleth.JPAStorageService.JPAVendorAdapter" class="org.springframework.orm.jpa.vendor.HibernateJpaVendorAdapter">
           <property name="database" value="MYSQL" />
     </bean>
     ```
     (and modify the "**USER_DB_NAME**" and "**PASSWORD**" for your "**shibboleth**" DB)

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
    * use ```openssl x509 -outform der -in /etc/ssl/certs/ldap_server.pem -out /opt/shibboleth-idp/credentials/ldap_server.crt``` to load the ldap certificate.
    
    If you host ldap in a seperate machine, copy the ldap_server.crt to  ```/opt/shibboleth-idp/credentials```
    * ```vim /opt/shibboleth-idp/conf/ldap.properties```


     * Solution 1: LDAP + STARTTLS:

       ```xml
       idp.authn.LDAP.authenticator = bindSearchAuthenticator
       idp.authn.LDAP.ldapURL = ldap://LDAP.YOUR-DOMAIN:389
       idp.authn.LDAP.useStartTLS = true
       idp.authn.LDAP.useSSL = false
       idp.authn.LDAP.sslConfig = certificateTrust
       idp.authn.LDAP.trustCertificates = %{idp.home}/credentials/ldap-server.crt
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
       idp.authn.LDAP.trustCertificates = %{idp.home}/credentials/ldap-server.crt
       idp.authn.LDAP.baseDN = ou=people,dc=YOUR-DOMAIN,dc=ac,dc=lk
       idp.authn.LDAP.userFilter = (uid={user})
       idp.authn.LDAP.bindDN = cn=admin,dc=YOUR-DOMAIN,dc=ac,dc=lk
       idp.authn.LDAP.bindDNCredential = ###LDAP_ADMIN_PASSWORD###
       idp.attribute.resolver.LDAP.trustCertificates   = %{idp.authn.LDAP.trustCertificates:undefined}
       idp.attribute.resolver.LDAP.returnAttributes    = %{idp.authn.LDAP.returnAttributes}
       #idp.authn.LDAP.trustStore                       = %{idp.home}/credentials/ldap-server.truststore
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
    * If you decided to use the Solution 3 of step 28, you have to modify the following code as given, from your Attribute Resolver file:
```xml
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

* Change the value of `schacHomeOrganizationType`,

```xml
    <Attribute id="schacHomeOrganizationType">
            <Value>urn:schac:homeOrganizationType:lk:others</Value>

    </Attribute>
```
        
where value must be either,

urn:schac:homeOrganizationType:int:university

urn:schac:homeOrganizationType:int:library

urn:schac:homeOrganizationType:int:public-research-institution

urn:schac:homeOrganizationType:int:private-research-institution


* Modify `services.xml` file: `vim /opt/shibboleth-idp/conf/services.xml`,
```xml
      <value>%{idp.home}/conf/attribute-resolver.xml</value>
```
  must become:
```xml
      <value>%{idp.home}/conf/attribute-resolver-LEARN.xml</value>
```

* Restart Tomcat8: 
      ```service tomcat8 restart```

31. Enable the SAML2 support by changing the ```idp-metadata.xml``` and disabling the SAML v1.x deprecated support:
    * ```vim /opt/shibboleth-idp/metadata/idp-metadata.xml```
      ```xml
      <IDPSSODescriptor> SECTION:
        – From the list of "protocolSupportEnumeration" remove:
          - urn:oasis:names:tc:SAML:1.1:protocol
          - urn:mace:shibboleth:1.0
        
        - On <Extensions> include
            <mdui:UIInfo>
                <mdui:DisplayName xml:lang="en">Your Institute Name</mdui:DisplayName>
                <mdui:Description xml:lang="en">Enter a description of your IdP</mdui:Description>
                <mdui:Logo height="60" width="80">https://idp.YOUR-DOMAIN/logo.png</mdui:Logo>
                <mdui:Logo height="16" width="16">https://idp.YOUR-DOMAIN/logo16.png</mdui:Logo>
            </mdui:UIInfo>
        - Upload example png files to /var/www/html as logo.png with 80x60 pixel and logo16.png with 16x16 pixel images.

        – Remove the endpoint:
          <ArtifactResolutionService Binding="urn:oasis:names:tc:SAML:1.0:bindings:SOAP-binding" Location="https://idp.YOUR-DOMAIN:8443/idp/profile/SAML1/SOAP/ArtifactResolution" index="1"/>
          (and modify the index value of the next one to “1”)


        - Remove the endpoint: 
          <SingleSignOnService Binding="urn:mace:shibboleth:1.0:profiles:AuthnRequest" Location="https://idp.YOUR-DOMAIN/idp/profile/Shibboleth/SSO"/>        
        - Remove all ":8443" from the existing URL (such port is not used anymore)
        
        - Uncomment SingleLogoutService:
        
          <SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="https://identity.thilinapathirana.xyz/idp/profile/SAML2/Redirect/SLO"/>
          <SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="https://identity.thilinapathirana.xyz/idp/profile/SAML2/POST/SLO"/>
          <SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST-SimpleSign" Location="https://identity.thilinapathirana.xyz/idp/profile/SAML2/POST-SimpleSign/SLO"/>
          <SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:SOAP" Location="https://identity.thilinapathirana.xyz/idp/profile/SAML2/SOAP/SLO"/>


      <AttributeAuthorityDescriptor> Section:
        – From the list "protocolSupportEnumeration" replace the value of:
          - urn:oasis:names:tc:SAML:1.1:protocol
          with
          - urn:oasis:names:tc:SAML:2.0:protocol

        - Remove the comment from:
          <AttributeService Binding="urn:oasis:names:tc:SAML:2.0:bindings:SOAP" Location="https://idp.YOUR-DOMAIN/idp/profile/SAML2/SOAP/AttributeQuery"/>
        - Remove the endpoint: 
          <AttributeService Binding="urn:oasis:names:tc:SAML:1.0:bindings:SOAP-binding" Location="https://idp.YOUR-DOMAIN:8443/idp/profile/SAML1/SOAP/AttributeQuery"/>

        - Remove all ":8443" from the existing URL (such port is not used anymore)
        - Finally remove all existing commented content from the whole document

      ```

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
      ```

    * Retrive the Federation Certificate used to verify its signed metadata:
    *  ```wget https://fr.ac.lk/signedmetadata/metadata-signer -O /opt/shibboleth-idp/metadata/federation-cert.pem```

    
  
35. Reload service with id ```shibboleth.MetadataResolverService``` to retrieve the Federation Metadata:
    *  ```cd /opt/shibboleth-idp/bin```
    *  ```./reload-service.sh -id shibboleth.MetadataResolverService```


36. The day after the Federation Operators approval you, check if you can login with your IdP on the following services:
    * https://sp-training.ac.lk/secure   (Service Provider provided for testing the LEARN Federation)
   
    To be able to log-in, you should continue with the rest of the guide.

### Configure Attribute Filters to release the mandatory attributes:

37. Make sure that you have the "```tmp/httpClientCache```" used by "```shibboleth.FileCachingHttpClient```":
    * ```mkdir -p /opt/shibboleth-idp/tmp/httpClientCache ; chown tomcat8 /opt/shibboleth-idp/tmp/httpClientCache```

38. Modify your ```services.xml```:
    * ```vim /opt/shibboleth-idp/conf/services.xml```

      ```xml
      <bean id="Default-Filter" class="net.shibboleth.ext.spring.resource.FileBackedHTTPResource"
            c:client-ref="shibboleth.FileCachingHttpClient"
            c:url="https://fr.ac.lk/templates/attribute-filter-LEARN-Default.xml"
            c:backingFile="%{idp.home}/conf/attribute-filter-LEARN-Default.xml"/>
      <bean id="Production-Filter" class="net.shibboleth.ext.spring.resource.FileBackedHTTPResource"
            c:client-ref="shibboleth.FileCachingHttpClient"
            c:url="https://fr.ac.lk/templates/attribute-filter-LEARN-Production.xml"
            c:backingFile="%{idp.home}/conf/attribute-filter-LEARN-Production.xml"/>
      ...

      <util:list id ="shibboleth.AttributeFilterResources">
         <value>%{idp.home}/conf/attribute-filter.xml</value>
         <ref bean="Default-Filter"/>
         <ref bean="Production-Filter"/>
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
     
   * Restart the Tomcat service by service tomcat8 restart

   * By changing idp.consent.maxStoredRecords will remove the limit on the number of consent records held (by default, 10) by setting the limit to -1 (no limit)

   * The Storage Record Life Time of 1 year should be sufficient and the consent records would expire after a year.

   * Once you restart the service , the filters defined in step 38 will allow LEARN Federated Services to be authenticated with your IDP.


41. Now you will be allowed to login with your IdP on the following services:
    * https://sp-training.ac.lk/secure   (Service Provider provided for testing the LIAF)
   

### Release Attributes for your Service Providers (SP) in Production Environment

42. If you have any service provider (eg: Moodle) that supports SAML, you may use them to authenticate via your IDP. To do that, edit `/opt/shibboleth-idp/conf/attribute-filter.xml` to include service providers to authenticate your users for their services.

   * Consult Service Provider guidelines and https://fr.ac.lk/templates/attribute-filter-LEARN-Production.xml on deciding what attributes you should release.
   * Instruction to add you moodle installations: https://moodle.org/auth/shibboleth/README.txt

   * Reload shibboleth.AttributeFilterService to apply the new SP



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

For your simplisity in developing, temporary add the following to Apache idp.conf file ( /etc/apache2/sites-available/idp.conf ) to server the requests directly by Apache (avoiding going through Tomcat and thus avoiding having to rebuild the WAR file after every change):insert the following right above the ***ProxyPass /idp*** directive:

```apache
ProxyPass /idp/images !
ProxyPass /idp/css !
Alias /idp/images /opt/shibboleth-idp/edit-webapp/images
Alias /idp/css /opt/shibboleth-idp/edit-webapp/css
```

And, as default permissions on Apache 2.4 are more restrictive, grant also explicitly access to the /opt/shibboleth-idp/edit-webapp directory: insert this at the very top of /etc/httpd/conf.d/idp.conf:

```apache
<Directory /opt/shibboleth-idp/edit-webapp>
   Require all granted
</Directory>
```
When done with changes to the images and css directories, remember to rebuild the WAR file and restart Tomcat:

```bash
/opt/shibboleth-idp/bin/build.sh
service tomcat restart
```

Then remove the temporary additions on idp.conf and restart the apache service.

   
### Appendix: Useful logs to find problems

1. Tomcat 8 Logs:
   * ```cd /var/log/tomcat8```
   * ```vim catalina.out```

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
