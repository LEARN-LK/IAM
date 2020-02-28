# This is a Draft -- Donot Continue to follow the steps

nano /etc/netplan/50-cloud-init.yaml

network:
    ethernets:
        enp0s3:
            addresses:
            - 192.168.6.202/24

            dhcp4: false
#            dhcp6: true
            gateway4: 192.168.6.254
#            gateway6: 
            nameservers:
                addresses:
                - 192.168.1.1
                search:
                - inst.ac.lk
    version: 2




2. Modify ```/etc/hosts``` and add:
   * ```vim /etc/hosts```
  
     ```bash
     127.0.0.1 idp.YOUR-DOMAIN idp
     ```
   (*Replace ```idp.YOUR-DOMAIN``` with your IdP FQDN, Also remember not to remove the entry for ```localhost```*)
   
5. Go to the Shibboleth Identity Provider v3.3.2 install location:
   * ```cd /usr/local/src```
   * ```cd shibboleth-identity-provider-3.3.2```
6. Generate Passwords for later use in the installation, You will need two password strings, ###PASSWORD-FOR-BACKCHANNEL### and ###PASSWORD-FOR-COOKIE-ENCRYPTION### for step 7.
   * ```tr -c -d '0123456789abcdefghijklmnopqrstuvwxyz' </dev/urandom | dd bs=32 count=1 2>/dev/null;echo```
     eg: ```7eqtdwpeo4a37y1gxbbd7z1hmhfw9utd``` and ```aj5bd4amluqnl1wwo8r8ko7u3lv7rf1p```
   
      
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

11. Edit configuration file as `idp.conf` with the following:
   * ```vim /etc/apache2/sites-available/idp.conf```
  
   ```apache
   <VirtualHost *:80>
     ServerName idp.YOUR-DOMAIN
     ServerAdmin admin@YOUR-DOMAIN
     DocumentRoot /var/www/html
   </VirtualHost>
   ```
   
   Restart the Apache service:
   * ```service apache2 restart```
   
12. Install Letsencrypt and enable HTTPS:

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
