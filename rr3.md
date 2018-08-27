This will guide through basic installation of HEANET's product, jagger in Ubuntu 18.04 based on https://jagger.heanet.ie/jaggerdocadmin/installation.html and Terry's https://docs.google.com/document/d/1vvSbGPoF7L1VQKwfaLeN2HMC9TPtk3jeZN8XLxNTerQ

This guide assumes you have pre installed Ubuntu 18.04 server with default configurations and have a public IP connectivity including DNS setup.

All Commands will be run as the root user. You may use sudo su to become root.

Install Apache

apt install apache2

Install Mysql server

apt install mysql-server

Securing mysql

mysql_secure_installation

++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
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
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Install PHP

apt install php libapache2-mod-php

edit php settings as

vim /etc/php/7.X/apache2/php.ini

date.timezone = Asia/Colombo
memory_limit = 256M
max_execution_time = 60

vim /etc/php/7.2/cli/php.ini

date.timezone = Asia/Colombo
max_execution_time = 60

Enable apache modules

a2enmod rewrite
a2enmod unique_id

Install php dependancies

apt install php-apc
apt install php-mysql
apt install php-xml
 

follow steps in https://gist.github.com/arzzen/1209aa4a430bd95db3090a3399e6c35f to install php mcrypt

apt install php-memcached
apt install php-amqplib

Install composer

curl -sS https://getcomposer.org/installer | php
cp composer.phar /usr/local/bin/composer

Install memcached 

apt-get install memcached

Install Gearman

apt-get install gearman-job-server
apt-get install php-gearman

service apache2 restart

Get CodeIgniter

cd /opt
wget https://github.com/bcit-ci/CodeIgniter/archive/3.1.9.zip
apt install unzip

unzip 3.1.9.zip
mv CodeIgniter-3.1.9 codeigniter

Install Jagger

git clone https://github.com/Edugate/Jagger /opt/rr3
cd /opt/rr3

cd /opt/rr3/application
composer install
Note: Ignore the warning about running composer as root/super user!

cp /opt/codeigniter/index.php /opt/rr3/

cd /etc/apache2/sites-available/

a2dissite 000-default.conf

systemctl reload apache2

cp 000-default.conf rr3.conf

vim rr3.conf

<VirtualHost *:80>
 
        ServerName YOUR-URL
        ServerAdmin YOUR-Email
        DocumentRoot /opt/rr3/
        Alias /rr3 /opt/rr3
<Directory /opt/rr3>

        #  you may need to uncomment next line
          Require all granted

#          RewriteEngine On
#          RewriteBase /rr3
#          RewriteCond $1 !^(Shibboleth\.sso|index\.php|logos|signedmetadata|flags|images|app|schemas|fonts|styles|images|js|robots\.txt|pub|includes)
#          RewriteRule  ^(.*)$ /rr3/index.php?/$1 [L]
  </Directory>
  <Directory /opt/rr3/application>
          Order allow,deny
          Deny from all
  </Directory>

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

</VirtualHost>


a2ensite rr3

systemctl reload apache2


mysql -u root -p

create database rr3 CHARACTER SET utf8 COLLATE utf8_general_ci;
grant all on rr3.* to rr3user@'localhost' identified by 'rr3@PasS';
flush privileges;


exit

cd /opt/rr3

./install.sh


cd application/config
cp config-default.php config.php
cp config_rr-default.php config_rr.php
cp database-default.php database.php
cp email-default.php email.php
cp memcached-default.php memcached.php


chgrp www-data /opt/rr3/application/models/Proxies
chmod 755 /opt/rr3/application/models/Proxies
chgrp www-data /opt/rr3/application/cache
chmod 755 /opt/rr3/application/cache

Modify configs


vim config.php
$config['base_url']     = 'https://rr.example.com/rr3/';
$config['log_path'] = '/var/log/rr3/';

You must also create this directory and make it writable by the Apache user www-data

mkdir /var/log/rr3
chown www-data:www-data /var/log/rr3
chmod 750 /var/log/rr3

get a copy of following random output and put it back on config.php

tr -c -d '0123456789abcdefghijklmnopqrstuvwxyz' </dev/urandom | dd  bs=32 count=1 2>/dev/null;echo

as

$config['encryption_key'] = '8mixahy22evqp4k6wbzce16oglg1zlyr';










Letsencypt

add-apt-repository ppa:certbot/certbot
apt install python-certbot-apache
certbot --apache -d example.com



