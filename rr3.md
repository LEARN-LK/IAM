# Installation of Jagger Tool in Ubuntu 18.04

This will guide through basic installation of HEANET's product, jagger in Ubuntu 18.04 based on [Jagger Documentation](https://jagger.heanet.ie/jaggerdocadmin/installation.html) and Terry Smith's (@trsau) [Google Doc for Backfire project](https://docs.google.com/document/d/1vvSbGPoF7L1VQKwfaLeN2HMC9TPtk3jeZN8XLxNTerQ)

This guide assumes you have pre installed Ubuntu 18.04 server with default configurations and have a public IP connectivity including DNS setup.

All Commands will be run as the root user. You may use `sudo su` to become root.

### 1. Install Apache

   * `apt install apache2`

#### Enable apache modules

   * `a2enmod rewrite`
   * `a2enmod unique_id`
   * `service apache2 restart`

### 2. Install Mysql server

   * `apt install mysql-server`

### 3. Securing mysql

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


### 4. Install PHP

   - `apt install php libapache2-mod-php`

edit php settings as

   * `vim /etc/php/7.X/apache2/php.ini`
```php
date.timezone = Asia/Colombo
memory_limit = 256M
max_execution_time = 60
```
   * `vim /etc/php/7.2/cli/php.ini`

```php
date.timezone = Asia/Colombo
max_execution_time = 60
```

#### Install php dependancies

   * `apt install php-apcu`
   * `apt install php-mysql`
   * `apt install php-xml`
   * `apt install php-memcached`
   * `apt install php-amqplib`
   * `service apache2 restart`


follow these steps to install php7.X deprecated php-mcrypt [from here](https://gist.github.com/arzzen/1209aa4a430bd95db3090a3399e6c35f)


### 5. Install composer

   * `curl -sS https://getcomposer.org/installer | php`
   * `cp composer.phar /usr/local/bin/composer`


### 6. Install memcached 

   * `apt-get install memcached`


### 7. Install Gearman

   * `apt-get install gearman-job-server`
   * `apt-get install php-gearman`


### 8. Get CodeIgniter

   * `cd /opt`
   * `wget https://github.com/bcit-ci/CodeIgniter/archive/3.1.9.zip`
   * `apt install unzip`
   * `unzip 3.1.9.zip`
   * `mv CodeIgniter-3.1.9 codeigniter`


### 9. Download and prepare Jagger RR3

   * `git clone https://github.com/Edugate/Jagger /opt/rr3`
   * `cd /opt/rr3/application`
   * `composer install`
   
> Note: Ignore the warning about running composer as root/super user!

   * `cp /opt/codeigniter/index.php /opt/rr3/`

#### Configure Apache Virtual Host

Disable the default configuration
   * `cd /etc/apache2/sites-available/`
   * `a2dissite 000-default.conf`
   * `systemctl reload apache2`

Create a new conf file for RR3 as `rr3.conf`

   * `cp 000-default.conf rr3.conf`

Edit `rr3.conf` with following

   * `vim rr3.conf`

```apache
<VirtualHost *:80>
 
        ServerName YOUR-DOMAIN
        ServerAdmin YOUR-Email
        DocumentRoot /opt/rr3/
        Alias /rr3 /opt/rr3
<Directory /opt/rr3>

          Require all granted

          RewriteEngine On
          RewriteBase /rr3
          RewriteCond $1 !^(Shibboleth\.sso|index\.php|logos|signedmetadata|flags|images|app|schemas|fonts|styles|images|js|robots\.txt|pub|includes)
          RewriteRule  ^(.*)$ /rr3/index.php?/$1 [L]
  </Directory>
  <Directory /opt/rr3/application>
          Order allow,deny
          Deny from all
  </Directory>

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

</VirtualHost>
```

Enable rr3 site by, 

   * `a2ensite rr3` 
   
and restart Apache 

   * `systemctl reload apache2`

#### Database Creation 

Log in to MYSQL as root

   * `mysql -u root -p`

```sql
CREATE DATABASE rr3 CHARACTER SET utf8 COLLATE utf8_general_ci;
GRANT ALL ON rr3.* to rr3user@'localhost' IDENTIFIED BY 'rr3@PasS';
FLUSH PRIVILEGES;
```

### 10. Install RR3

```bash
cd /opt/rr3

./install.sh
```
Next, copy the default configurations as samples

```bash
cd application/config
cp config-default.php config.php
cp config_rr-default.php config_rr.php
cp database-default.php database.php
cp email-default.php email.php
cp memcached-default.php memcached.php
```

Give permission to Apache User `www-data` as following

```bash
chgrp www-data /opt/rr3/application/models/Proxies
chmod 755 /opt/rr3/application/models/Proxies
chgrp www-data /opt/rr3/application/cache
chmod 755 /opt/rr3/application/cache
```

#### Modify configurations

##### config.php

   * `vim config.php`
```php
$config['base_url']     = 'https://YOUR-DOMAIN/rr3/';
$config['log_path'] = '/var/log/rr3/';
```

You must also create this directory and make it writable by the Apache user www-data

```bash
mkdir /var/log/rr3
chown www-data:www-data /var/log/rr3
chmod 750 /var/log/rr3
```

get a copy of following random output and put it back on config.php

`tr -c -d '0123456789abcdefghijklmnopqrstuvwxyz' </dev/urandom | dd  bs=32 count=1 2>/dev/null;echo`

as

```php
$config['encryption_key'] = '8mixahy22evqp4k6wbzce16oglg1zlyr';
```

##### config_rr.php

   * `vim config_rr.php`

rr_setup_allowed - it should be always be set to FALSE. TRUE only when setup is initialized

```php
$config['rr_setup_allowed'] = TRUE;
```

Note: This will be changed back to FALSE later in the setup.

site_logo - set filename to be used as main logo in top-left corner. File should be stored in /opt/rr3/images/ folder (Optional)

Note: The default logo is 515 pixels wide and 146 pixels high. Your own site logo should be about the same size.

```php
$config['site_logo'] = 'your_logo.png';
```


syncpass - please generate strong key. It’s used by synchronization - interfederation tool

`tr -c -d '0123456789abcdefghijklmnopqrstuvwxyz' </dev/urandom | dd bs=32 count=1 2>/dev/null;echo`

then assign generated value to attr like:

```php
$config['syncpass'] = 'qp7zwgm6vqzptb87uoe7zzfiq1gx1oa6';
```

support_mailto - set support email. For example this email is displayed as contact mail.
```php
$config['support_mailto'] = 'support@example.com';
```

nameids - array of allowed NameID in JAGGER remove it from config

```php
/*
$config['nameids'] = array(
     'urn:mace:shibboleth:1.0:nameIdentifier' => 'urn:mace:shibboleth:1.0:nameIdentifier',
     'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress' => 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
     'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified'=>'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified',
     'urn:oasis:names:tc:SAML:2.0:nameid-format:transient' => 'urn:oasis:names:tc:SAML:2.0:nameid-format:transient',
     'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent' => 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent',
             );
*/
```

> Note: The above config has been commented out!



##### email.php

```php
$config['protocol'] = 'smtp';
$config['smtp_host'] = "SMTP_HOST";
$config['smtp_port'] = 25;
$config['smtp_user'] = 'USER';
$config['smtp_pass'] = 'PASS';
$config['smtp_crypto'] = 'tls';
```

##### database.php

```php
$db['default']['hostname'] = '127.0.0.1';
$db['default']['username'] = 'rr3user';
$db['default']['password'] = 'rr3@PasS';
$db['default']['database'] = 'rr3';
$db['default']['dsn']      = 'mysql:host=127.0.0.1;port=3306;dbname=rr3';
```

#### Database - populate tables

To populate tables we are going to use doctrine tool.

`cd /opt/rr3/application`


```bash
./doctrine orm:schema-tool:create
```

If you going to run application in production mode then you also need to regenerate proxies:


`./doctrine orm:generate-proxies`

and verify owner of application/models/Proxies/* - apache user should be owner

or 

`chown -R www-data application/models/Proxies/`

In the future after every update you will need to run

```bash
./doctrine orm:schema-tool:update --force
./doctrine orm:generate-proxies

```
### Install Letsencypt and enable https

```bash
add-apt-repository ppa:certbot/certbot
apt install python-certbot-apache
certbot --apache -d YOUR-DOMAIN
```
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
http-01 challenge for YOUR_DOMAIN
Waiting for verification...
Cleaning up challenges
Created an SSL vhost at /etc/apache2/sites-available/rr3-le-ssl.conf
Enabled Apache socache_shmcb module
Enabled Apache ssl module
Deploying Certificate to VirtualHost /etc/apache2/sites-available/rr3-le-ssl.conf
Enabling available site: /etc/apache2/sites-available/rr3-le-ssl.conf


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
Congratulations! You have successfully enabled https://YOUR-DOMAIN

```

Open page **https://YOUR-DOMAIN/rr3/setup** and fill the form.




Once the default user is created switch **OFF** the setup mode on `config_rr.php` by


```php
$config['rr_setup_allowed'] = FALSE;
```

