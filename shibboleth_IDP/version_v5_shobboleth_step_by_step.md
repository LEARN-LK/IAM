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
