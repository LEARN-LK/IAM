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
 




