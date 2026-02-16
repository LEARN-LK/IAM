## This manual is being updated

# Shibboleth IdP v5+ on Ubuntu Linux LTS 24.04

LEARN concluded a workshop on Federated Identity with the introduction of Shibboleth IDP and SP to IAM infrastructure on member institutions. 

Installation assumes you have already installed Ubuntu Server 24.04 with default configuration and has a public IP connectivity with DNS setup

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
   apt install vim wget gnupg ca-certificates openssl apache2 ntp --no-install-recommends
   ```

4. Install Amazon Corretto JDK:
   ```bash
   wget -O - https://apt.corretto.aws/corretto.key | sudo gpg --dearmor -o /usr/share/keyrings/corretto.gpg
   echo "deb [signed-by=/usr/share/keyrings/corretto.gpg] https://apt.corretto.aws stable main" | sudo tee /etc/apt/sources.list.d/corretto.list

   apt-get update; apt-get install -y java-21-amazon-corretto-jdk

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

   (**ATTENTION**: *Replace `idp.YOUR-DOMAIN.org` with your IdP Full Qualified Domain Name and `<HOSTNAME>` with the IdP hostname*)

   * `vim /etc/hosts`

     ```bash
     <YOUR SERVER IP ADDRESS> idp.YOUR-DOMAIN.org <HOSTNAME>
     ```

   * `hostnamectl set-hostname <HOSTNAME>`
   
4. Set the variable `JAVA_HOME` in `/etc/environment`:
   * Set JAVA_HOME:
     ```bash
     echo 'JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto' > /etc/environment

     source /etc/environment

     export JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto

     echo $JAVA_HOME
     ```

### Install Shibboleth Identity Provider v4.x

1. Download the Shibboleth Identity Provider v5.x.y (replace '4.x.y' with the latest version found [here](https://shibboleth.net/downloads/identity-provider/)):
   * `cd /usr/local/src`
   * `wget https://shibboleth.net/downloads/identity-provider/latest5/shibboleth-identity-provider-5.2.0.tar.gz`
   * `tar -xzf shibboleth-identity-provider-5.2.0.tar.gz`


2. Run the installer `install.sh`:

   * `cd shibboleth-identity-provider-5.2.0/bin`
   * `bash install.sh -Didp.host.name=$(hostname -f) -Didp.keysize=3072`

   ```
   Source (Distribution) Directory: [/usr/local/src/shibboleth-identity-provider-4.x]
   Installation Directory: [/opt/shibboleth-idp]
   Hostname: [localhost.localdomain]
   idp.YOUR-DOMAIN
   SAML EntityID: [https://idp.YOUR-DOMAIN/idp/shibboleth]
   Attribute Scope: [localdomain]
   YOUR-DOMAIN
  
   ```
By starting from this point, the variable **idp.home** refers to the directory: `/opt/shibboleth-idp`

### Install Jetty 9 Web Server
Jetty is a Web server and a Java Servlet container. It will be used to run the IdP application through its WAR file.

1. Become ROOT:
   * `sudo su -`

2. Download and Extract Jetty:
   ```bash
   cd /usr/local/src

   wget https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/12.0.32/jetty-home-12.0.32.tar.gz

   tar -xzf jetty-home-12.0.32.tar.gz
   ```
3. Create the `jetty-src` folder as a symbolic link. It will be useful for future Jetty updates:
   ```bash
   ln -nsf jetty-home-12.0.32 jetty-src
   ```
(According to Jetty's documentation, it is better to split Jetty in 2 separates directory, one containing
the home source (it is the directory we have just created) and one for the base application (that we
will create further). Environnement variables reflecting the setup should be created as Jetty will
need it as well.)

4. Create the system user `jetty` that can run the web server (without home directory):
   ```bash
   useradd -r -M jetty
   ```
create a file in /etc/default/jetty to contain these variables :

```
JETTY_HOME=/usr/local/src/jetty-src
JETTY_BASE=/opt/jetty-shibboleth
JETTY_USER=jetty
JETTY_START_LOG=/var/log/jetty/start.log
TMPDIR=$JETTY_BASE/tmp
JETTY_ARGS="jetty.ssl.port=8443"
```
5. Read the variables to reflect their existence in your current shell :

`source /etc/default/jetty`

6. Create the directory that will contain the base for your application :

`mkdir $JETTY_BASE`

7. Create the TMPDIR directory used by Jetty:
   ```bash
   mkdir $JETTY_BASE/tmp ; chown jetty:jetty $JETTY_BASE/tmp
   
   chown -R jetty:jetty $JETTY_BASE /usr/local/src/jetty-src
   ```

8. Create the Jetty Log's folder:
   ```bash
   mkdir /var/log/jetty
   
   mkdir $JETTY_BASE/logs
   
   chown jetty:jetty /var/log/jetty $JETTY_BASE/logs

   ```

Type in the following commands in your directory of choice (not in `$JETTY_BASE`):

* `cd /usr/local/src`

```
git clone https://git.shibboleth.net/git/java-idp-jetty-base
cd java-idp-jetty-base
git checkout 12 
#           or 12.1 as you prefer
cp -r src/main/resources/net/shibboleth/idp/module/jetty/jetty-base/* $JETTY_BASE
```

### Configure Jetty
in `$JETTY_BASE/start.d/idp.ini`

You should open `$JETTY_BASE/start.d/idp.ini` with a text editor (such as vim) and adjust the lines as described below.
Add following setting lines at the top of the file :

```
--exec
-Xmx1500m
-Djava.security.egd=file:/dev/urandom
-Djava.io.tmpdir=tmp
-Dlogback.configurationFile=resources/logback.xml
```

You should modify the password used to access the Java keyfile that holds the access to the certificates used by Jetty (it is the lines with .keyXXXPassword in it with the password changeit);
see further for the setup of the keyfile.
You should comment the lines with jetty.ssl.host and jetty.ssl.port.

These settings will be used further on the Apache2 setup.

## Configure `$JETTY_BASE/webapps/idp.xml`
You should verify that the content corresponds to your Shibboleth installation, especially the path to Shibboleth install
The content should looks to something like :
```
<?xml version="1.0"?>
<!DOCTYPE Configure PUBLIC "-//Jetty//Configure//EN"
"https://www.eclipse.org/jetty/configure_10_0.dtd">
<!-- ======================================================== -->
<!-- Configure the Shibboleth IdP webapp -->
<!-- ======================================================== -->
<Configure class="org.eclipse.jetty.ee9.webapp.WebAppContext">
 <Set name="war">/opt/shibboleth-idp/war/idp.war</Set>
 <Set name="contextPath">/idp</Set>
 <Set name="extractWAR">false</Set>
 <Set name="copyWebDir">false</Set>
 <Set name="copyWebInf">true</Set>
</Configure>
```

## Install the logging module

In the beginning of this chapter, in the file idp.ini, there is a reference to the logging-logback module.
You need to be sure that the module is installed :

`java -jar /usr/local/src/jetty-src/start.jar --add-module=logging-logback`

java -jar /usr/local/src/jetty-src/start.jar --base=$JETTY_BASE --add-module=logging-logback

## Check the loaded modules in $JETTY_BASE/modules/idp.mod
The section [depend] should looks to something like :

```
[depend]
ee9-annotations
ee9-deploy
ext
ee9-webapp
http
ee9-jsp
ee9-jstl
ee9-plus
resources
ee9-servlets
```

As the service is proxied by Apache, there is no need to enable https/ssl here, as it will be handled by Apache.
It is also possible to make Jetty run directly (thus without be guarded by a proxy), but it is not a choice I've made here. If you want to make it run differently, adapt the setup according to your own choices (it will probably require that you install additional Jetty modules using the same kind of command used to install the logging module).

### Create a systemd service file launcher for Jetty
Depending on the version of your OS, you should adapt to your own configuration, here is an example to launch on Ubuntu 22\4.04 ; 
create the file `/lib/systemd/system/jetty.service` containing following lines :

```
[Unit]
Description=Jetty servlet for Shibboleth
After=network.target auditd.service

[Service]
EnvironmentFile=-/etc/default/jetty
ExecStart=java -jar /usr/local/src/jetty-src/start.jar jetty.home=/usr/local/src/jetty-src jetty.base=/opt/jetty-shibboleth
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
RestartPreventExitStatus=255
Type=simple

[Install]
WantedBy=multi-user.target
Alias=jetty.service
```
Enable the service to start at boot :

`systemctl enable jetty.service`

## Apache configuration

Prerequisites : fully qualified registered domain name for the server

Disable default apache configuration:

`a2dissite 000-default`

Create a new configuration file as idp.conf with the following:

`vim /etc/apache2/sites-available/idp.conf`
```
<VirtualHost *:80>
  ServerName idp.YOUR-DOMAIN.ac.lk
  ServerAdmin admin@YOUR-DOMAIN.ac.lk
  DocumentRoot /var/www/html
</VirtualHost>
```
Enable Apache2 modules:

`a2enmod proxy_http proxy ssl headers alias include negotiation rewrite`

Enable IDP site config:

`a2ensite idp`

Create the Apache2 configuration file for IdP:

`vim /etc/apache2/sites-available/idp-proxy.conf`
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

`a2ensite idp-proxy.conf`

Restart the Apache service:

`service apache2 restart`

if you are going to use Letsencrypt

### Install Letsencrypt and enable HTTPS:

`apt install python3-certbot-apache`

`certbot --apache -d idp.YOUR-DOMAIN.ac.lk`

```
Plugins selected: Authenticator apache, Installer apache Enter email address (used for urgent renewal and security notices) (Enter 'c' to cancel): YOU@YOUR-DOMAIN.ac.lk

Please read the Terms of Service at https://letsencrypt.org/documents/LE-SA-v1.2-November-15-2017.pdf. You must agree in order to register with the ACME server at https://acme-v02.api.letsencrypt.org/directory

(A)gree/(C)ancel: A

Would you be willing to share your email address with the Electronic Frontier Foundation, a founding partner of the Let's Encrypt project and the non-profit organization that develops Certbot? We'd like to send you email about our work encrypting the web, EFF news, campaigns, and ways to support digital freedom.

(Y)es/(N)o: Y

Obtaining a new certificate Performing the following challenges: http-01 challenge for idp.YOUR-DOMAIN Waiting for verification... Cleaning up challenges Created an SSL vhost at /etc/apache2/sites-available/idp-le-ssl.conf Enabled Apache socache_shmcb module Enabled Apache ssl module Deploying Certificate to VirtualHost /etc/apache2/sites-available/idp-le-ssl.conf Enabling available site: /etc/apache2/sites-available/idp-le-ssl.conf

Please choose whether or not to redirect HTTP traffic to HTTPS, removing HTTP access.

1: No redirect - Make no further changes to the webserver configuration. 2: Redirect - Make all requests redirect to secure HTTPS access. Choose this for new sites, or if you're confident your site works on HTTPS. You can undo this change by editing your web server's configuration.

Select the appropriate number [1-2] then [enter] (press 'c' to cancel): 2 Redirecting vhost in /etc/apache2/sites-enabled/rr3.conf to ssl vhost in /etc/apache2/sites-available/rr3-le-ssl.conf

Congratulations! You have successfully enabled https://idp.YOUR-DOMAIN
```

If you use ACME (Let's Encrypt):

`ln -s /etc/letsencrypt/live/<SERVER_FQDN>/chain.pem /etc/ssl/certs/ACME-CA.pem`

Install MySQL Connector Java and other useful libraries for MySQL DB (if you don't have them already):

`apt install default-mysql-server libmariadb-java libcommons-dbcp-java libcommons-pool-java --no-install-recommends`

Activate MariaDB database service:

`systemctl start mysql.service`

Then type mysql on your terminal and hit ENTER.

Run the following `ALTER USER` command to change the root user’s authentication method to mysql_native_password

`ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'YOUR_PASSWORD';`

After making this change, exit the MySQL prompt:

`mysql>` exit Now you can run mysql_secure_installation again and the error should be gone.

Create and prepare the "shibboleth" MySQL DB to host the values of the several persistent-id and StorageRecords MySQL DB to host other useful information about user consent:

`mysql_secure_installation`
```
Securing the MySQL server deployment.

Connecting to MySQL using a blank password.

VALIDATE PASSWORD PLUGIN can be used to test passwords
and improve security. It checks the strength of password
and allows the users to set only those passwords which are
secure enough. Would you like to setup VALIDATE PASSWORD plugin?

Press y|Y for Yes, any other key for No: n

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
log in to your MySQL Server: Create StorageRecords table on storageservice database:

`wget https://raw.githubusercontent.com/LEARN-LK/IAM/master/shib-ss-db.sql -O /root/shib-ss-db.sql`

Open the `shib-ss-db.sql` and change the username and password as your preference

`vi shib-ss-db.sql`

fill missing data on `shib-ss-db.sql` before import

`mysql -u root -p < /root/shib-ss-db.sql`

Restart mysql service: `service mysql restart`

### Enable the generation of the   persistent-id   (this replace the deprecated attribute eduPersonTargetedID)

Find and modify the following variables with the given content on,

```
vim /opt/shibboleth-idp/conf/saml-nameid.properties

idp.persistentId.sourceAttribute = uid

idp.persistentId.salt = ### result of 'openssl rand -base64 36'###

idp.persistentId.generator = shibboleth.StoredPersistentIdGenerator

idp.persistentId.dataSource = MyDataSource

idp.persistentId.computed = shibboleth.ComputedPersistentIdGenerator
```

Enable the SAML2PersistentGenerator:

`vim /opt/shibboleth-idp/conf/saml-nameid.xml`

Remove the comment from the line containing:

`<ref bean="shibboleth.SAML2PersistentGenerator" />`

`vim /opt/shibboleth-idp/conf/c14n/subject-c14n.xml`

Remove the comment to the bean called "c14n/SAML2Persistent".

`<ref bean="c14n/SAML2Persistent" />`

Enable JPAStorageService for the StorageService of the user consent:

`vim /opt/shibboleth-idp/conf/global.xml`

and add this piece of code to the tail before the ending </beans>:
```
<!-- DB-independent Configuration -->

    <bean id="storageservice.JPAStorageService" 
          class="org.opensaml.storage.impl.JPAStorageService"
          p:cleanupInterval="%{idp.storage.cleanupInterval:PT10M}"
          c:factory-ref="storageservice.JPAStorageService.EntityManagerFactory"/>

    <bean id="storageservice.JPAStorageService.EntityManagerFactory"
          class="org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean">
          <property name="packagesToScan" value="org.opensaml.storage.impl"/>
            <!-- <property name="dataSource" ref="storageservice.JPAStorageService.DataSource"/> -->
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

<!-- Bean to store IdP data unrelated with persistent identifiers on 'storageservice' database -->

    <bean id="storageservice.JPAStorageService.DataSource" 
          class="org.apache.commons.dbcp2.BasicDataSource" destroy-method="close" lazy-init="true"
          p:driverClassName="org.mariadb.jdbc.Driver"
          p:url="jdbc:mysql://127.0.0.1:3306/storageservice?useSSL=false&amp;autoReconnect=true&amp;allowPublicKeyRetrieval=true"
          p:username="###_SS-USERNAME-CHANGEME_###"
          p:password="###_SS-DB-USER-PASSWORD-CHANGEME_###"
          p:maxTotal="10"
          p:maxIdle="5"
          p:maxWaitMillis="15000"
          p:testOnBorrow="true"
          p:validationQuery="select 1"
          p:validationQueryTimeout="5" />


    <bean id="MyDataSource" 
          class="org.apache.commons.dbcp2.BasicDataSource" destroy-method="close" lazy-init="true"
          p:driverClassName="org.mariadb.jdbc.Driver"
          p:url="jdbc:mysql://127.0.0.1:3306/storageservice?useSSL=false&amp;autoReconnect=true&amp;allowPublicKeyRetrieval=true"
          p:username="###_SS-USERNAME-CHANGEME_###"
          p:password="###_SS-DB-USER-PASSWORD-CHANGEME_###"
          p:maxTotal="10"
          p:maxIdle="5"
          p:maxWaitMillis="15000"
          p:testOnBorrow="true"
          p:validationQuery="select 1"
          p:validationQueryTimeout="5" />
```
(and modify the "###_SS-USERNAME-CHANGEME_###" and "**PASSWORD**" for your "###_SS-DB-USER-PASSWORD-CHANGEME_###" DB)

Modify the IdP configuration file:

`vim /opt/shibboleth-idp/conf/idp.properties`

```
idp.consent.StorageService = storageservice.JPAStorageService
# Track information about SPs logged into
idp.session.trackSPSessions = true
# Support lookup by SP for SAML logout
idp.session.secondaryServiceIndex = true
```
(This will indicate to IdP to store the data collected by User Consent into the "StorageRecords" table)

Connect the openLDAP to the IdP to allow the authentication of the users:
Login to your openLDAP server as root or with sudo permission.

use `openssl x509 -outform der -in /etc/ssl/certs/ldap_server.pem -out /etc/ssl/certs/ldap_server.crt` to convert the ldap .pem certificate to a .cert.

copy the ldap_server.crt to  `/opt/shibboleth-idp/credentials` of your idp server (HINT : you can use scp from ldap server to idp server to obtain the crt file) Log in to your ldap and then, scp ldap_server.crt <your idp user>@<your idp ip>:/path_to_copy

Next, edit `vim /opt/shibboleth-idp/conf/ldap.properties` with one of the following solutions.

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

Note: According to your requirements, change the log level 

Build the `attribute-resolver.xml` to define which attributes your IdP can manage. Here you can find the `attribute-resolver-LEARN-v5.xml provided by LEARN:

Download the attribute resolver provided by LEARN:

`wget https://fr.ac.lk/signedmetadata/files/attribute-resolver-LEARN-v4.xml -O /opt/shibboleth-idp/conf/attribute-resolver-LEARN-v5.xml`

The attribute filter provided by LEARN:

Append your `services.xml` with:

`vim /opt/shibboleth-idp/conf/services.xml`

Add folowing before the closing </beans> Make sure to maintain proper indentation
```
      <bean id="Default-Filter" class="net.shibboleth.ext.spring.resource.FileBackedHTTPResource"
            c:client-ref="shibboleth.FileCachingHttpClient"
            c:url="https://fr.ac.lk/signedmetadata/files/attribute-filter-LEARN-v4.xml"
            c:backingFile="%{idp.home}/conf/attribute-filter-LEARN-v4.xml"/>

```
  Modify the shibboleth.AttributeFilterResources util:list

```
      <util:list id ="shibboleth.AttributeFilterResources">
         <value>%{idp.home}/conf/attribute-filter.xml</value>
         <ref bean="Default-Filter"/>

      </util:list>
```
Reload service with id `shibboleth.AttributeFilterService` to refresh the Attribute Filter followed by the IdP:  
`cd /opt/shibboleth-idp/bin`  
`./reload-service.sh -id shibboleth.AttributeFilterService`

If you decided to use the Solution 3 of `ldap.properties` file configuration, you have to modify the following code as given, from your Attribute Resolver file:

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

- urn:schac:homeOrganizationType:int:university
- urn:schac:homeOrganizationType:int:library
- urn:schac:homeOrganizationType:int:public-research-institution
- urn:schac:homeOrganizationType:int:private-research-institution

Modify services.xml file: `vim /opt/shibboleth-idp/conf/services.xml`,

`<value>%{idp.home}/conf/attribute-resolver.xml</value>`

must become:

`<value>%{idp.home}/conf/attribute-resolver-LEARN-v4.xml</value>`
And

`<value>%{idp.home}/conf/attribute-filter.xml</value>`

must become:

`<value>%{idp.home}/conf/attribute-filter-LEARN-v4.xml</value>`

Restart Jetty: `service jetty restart`

## Enable the SAML2 support by changing the idp-metadata.xml:

`vim /opt/shibboleth-idp/metadata/idp-metadata.xml`

```
   <mdui:UIInfo>
          <mdui:DisplayName xml:lang="en">Your Institute Name</mdui:DisplayName>
          <mdui:Description xml:lang="en">Enter a description of your IdP</mdui:Description>
      </mdui:UIInfo>
```

### Obtain your IdP metadata here:

`https://idp.YOUR-DOMAIN/idp/shibboleth`

## Register your Identity Provider (IDP) in LIAF - LEARN Identity Access Federation

Register you IdP on LIAF:

`https://liaf.ac.lk/`

Once your membership is approved, you will be sent a federation registry joining link where the form will ask lot of questions to identify your provider. Therefore, answer all of them as per the following,

On the IDP registration page start with pasting the whole xml metadata from https://idp.instXY.ac.lk/idp/shibboleth and click next. If you are using a browser to open the metadata link, use its view-source mode to copy the content.

If you have correctly entered metadata you will be asked to select a Federation.

Select `"LEARN Identity Federation"`

Fill in your contact Details

Go to Organization tab and Fill in all details for language English(en) by clicking "Add in new language" button

Name of organization: Institute XY

Displayname of organization: Institute XY

URL: `https://www.YOUR-DOMAIN`

Go to Contacts tab and add at least "Support" and "Technical" contacts

On UI Information tab you will see some data extracted from metadata. Apart from those fill-in the rest

Keywords: university or research
For the tutorial put some dummy URL data for Information and Privacy Policy. But in production, you may have to provide your true data

On Certificates tab, make sure it contains Certificate details, if not start Over by reloading IDP's metadata and pasting them.

Finally click Register.

Your Federation operator will review your application and will proceed with the registration


## Configure the IdP to retrieve the Federation Metadata:

`cd /opt/shibboleth-idp/conf`
`vim metadata-providers.xml`

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

`cd /opt/shibboleth-idp/bin`
`./reload-service.sh -id shibboleth.MetadataResolverService`

### Configure Attribute Filters to release the mandatory attributes:

Make sure that you have the "tmp/httpClientCache" used by "shibboleth.FileCachingHttpClient":

`mkdir -p /opt/shibboleth-idp/tmp/httpClientCache ; chown jetty /opt/shibboleth-idp/tmp/httpClientCache`

Enable Consent Module

The consent module is shown when a user logs in to a service for the first time, and asks the user for permission to release the required (and desired) attributes to the service.

Edit `/opt/shibboleth-idp/conf/idp.properties` to uncomment and modify
```
     idp.consent.compareValues = true
     idp.consent.maxStoredRecords = -1
     idp.consent.storageRecordLifetime = P1Y
```
`	/opt/shibboleth-idp/bin/module.sh -t idp.intercept.Consent || /opt/shibboleth-idp/bin/module.sh -e idp.intercept.Consent	  `

Restart the Jetty service by `service Jetty restart`

By changing idp.consent.maxStoredRecords will remove the limit on the number of consent records held (by default, 10) by setting the limit to -1 (no limit)

The Storage Record Life Time of 1 year should be sufficient and the consent records would expire after a year.

Once you restart the service , the filters defined in step 38 will allow LEARN Federated Services to be authenticated with your IDP.

## Release Attributes for your Service Providers (SP) in Production Environment

If you have any service provider (eg: Moodle) that supports SAML, you may use them to authenticate via your IDP. To do that, edit `/opt/shibboleth-idp/conf/attribute-filter.xml ` to include service providers to authenticate your users for their services.
Consult Service Provider guidelines and `https://fr.ac.lk/templates/attribute-filter-LEARN-v5.xml on deciding what attributes you should release.


Reload shibboleth.AttributeFilterService to apply the new SP

Eg:
```
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
## Customization and Branding

The default install of the IdP login screen will display the Shibbolethlogo, a default prompt for username and password, and text saying that this screen should be customized. It is recommand to customize this page to have the proper institution logo and name. To give a consistent professional look, institution may customize the graphics to match the style of their,

- login pages
- onsent pages
- logout pages
= error pages
Those pages are created as Velocity template under `/opt/shibboleth-idp/views`

Therefore, it is recommended to customize the Velocity pages, adding supplementary images and CSS files as needed

Also the Velocity templates can be configured through message properties defined in message property files on  `/opt/shibboleth-idp/system/messages/messages.properties` which should NOT be modified because of that, any customizations should be inserted into `/opt/shibboleth-idp/messages/messages.properties`

least configurations:

`idp.title` - HTML TITLE to use across all of the IdP page templates. We recommend settings this to something like University of Example Login Service

`idp.logo` - relative path to the logo to render on the templates. E.g., /images/logo.jpg. The logo image has to be installed into /opt/shibboleth-idp/edit-webapp/images and the web application WAR file has to be rebuilt with /opt/shibboleth-idp/bin/build.sh

`idp.logo.alt-text` - the ALT text for your logo. Should be changed from the default value (where the text asks for the logo to be replaced).

`idp.footer` - footer that displays on (almost) all pages.

root.footer - footer that displays on some error pages.

Eg:

```
idp.title = University of Example Login Service
idp.logo = edit-webapp/images/placeholder-logo.png
idp.logo.alt-text = University of Example logo
idp.footer = Copyright University of Example
root.footer = Copyright University of Example
```
Depending on branding requirements, it may be sufficient to edit the CSS files in `/opt/shibboleth-idp/edit-webapp/css`, or it may be necessary to start editing the template pages.

Please note that the login page and most other pages use /opt/shibboleth-idp/edit-webapp/css/main.css, the consent module uses `/opt/shibboleth-idp/edit-webapp/css/consent.css` with different element names.

Besides the logo, the login page (and several other pages) display a toolbox on the right with placeholders for links to password-reset and help-desk pages, these can be customized by adding following to the /opt/shibboleth-idp/messages/messages.properties

`
idp.url.password.reset = http://helpdesk.YOUR-DOMAIN/ChangePassword/
idp.url.helpdesk = http://help.YOUR-DOMAIN/
`
Alternatively, it is also possible to hide the whole toolbox (the whole

element) from all of the relevant pages (essentially, login.vm and all (three) logout pages: logout.vm, logout-complete.vm and logout.propagate). This can be easily done by adding the following CSS snippet into `/opt/shibboleth-idp/edit-webapp/css/main.css`:
```
.column.two {
    display: none;
}
```
When done with changes to the images and css directories, remember to rebuild the WAR file and restart Jetty:

`/opt/shibboleth-idp/bin/build.sh`
`service jetty restart`












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
