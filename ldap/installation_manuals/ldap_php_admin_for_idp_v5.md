### phpLDAPadmin + Nginx on Ubuntu

This manual explains step‑by‑step installation and configuration of phpLDAPadmin using Nginx + PHP‑FPM on Ubuntu (20.04 / 22.04 / 24.04).

Use case: Internal LDAP administration on a custom port (not 80/443)

1. Prerequisites

  - Ubuntu server (root or sudo access)
  - Working LDAP directory
  - Internet access for packages

    `sudo apt update && sudo apt upgrade -y`

2.Install Required Packages

  2.1 install Nginx

  `sudo apt install -y nginx`

  verify the service

  `systemctl status nginx`

  2.2 Install PHP + PHP‑FPM + LDAP modules

Install PHP and required extensions:

`sudo apt install -y php php-fpm php-ldap php-xml php-mbstring php-curl php-gd php-zip`

Check PHP‑FPM socket:

`ls /run/php/`

you will see:(version can be different)

`php8.1-fpm.sock`

3. Install phpLDAPadmin

`sudo apt install -y phpldapadmin`

Default path: `/usr/share/phpldapadmin`
Web root (htdocs): `/usr/share/phpldapadmin/htdocs`

4. Configure phpLDAPadmin

4.1 Edit main config : `sudo vi /etc/phpldapadmin/config.php`

Modify as follows;

`$servers->setValue('server','name','Example LDAP');`

`$servers->setValue('server','base', array('dc=example,dc=ac,dc=lk'));`

Now find the login bind_id configuration line and comment it out with a # at the beginning of the line:

`$servers->setValue('login','bind_id','cn=admin,dc=example,dc=ac,dc=lk');`

This option pre-populates the admin login details in the web interface. This is information we shouldn’t share if our phpLDAPadmin page is publicly accessible.

The last thing that we need to adjust is a setting that controls the visibility of some phpLDAPadmin warning messages. By default the application will show quite a few warning messages about template files. These have no impact on our current use of the software. We can hide them by searching for the hide_template_warning parameter, uncommenting the line that contains it, and setting it to true:

`$config->custom->appearance['hide_template_warning'] = true;`

Having made the necessary configuration changes to phpLDAPadmin, we can now begin to use it. Navigate to the application in your web browser. Be sure to substitute your domain for the highlighted area below:

This is the last thing that we need to adjust. Save and close the file to finish. 

Disable anonymous bind (recommended) : `$servers->setValue('login','anon_bind',false);`

5. Configure Nginx (Custom Port)

   5.1 Create Nginx server block
```
server {
listen 8080;
server_name _;

root /usr/share/phpldapadmin/htdocs;
index index.php;

access_log /var/log/nginx/phpldapadmin_access.log;
error_log /var/log/nginx/phpldapadmin_error.log;

location / {
try_files $uri $uri/ =404;
}

location ~ \.php$ {
include snippets/fastcgi-php.conf;
fastcgi_pass unix:/run/php/php8.3-fpm.sock;
}

location ~ /\. {
deny all;
}
}
```
Adjust PHP socket if your version differs

Enable site
```
sudo ln -s /etc/nginx/sites-available/phpldapadmin /etc/nginx/sites-enabled/
sudo unlink /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

Access phpLDAPadmin

Open browser: `http://SERVER-IP:8080`

Login using LDAP bind DN and password: `cn=admin,dc=example,dc=org`

Optional: HTTPS on Custom Port (8443)

Generate self‑signed certificate:
```
sudo openssl req -x509 -nodes -days 365 \
-newkey rsa:2048 \
-keyout /etc/ssl/private/phpldapadmin.key \
-out /etc/ssl/certs/phpldapadmin.crt
```

update Nginx: 

```
server {
listen 8443 ssl;
server_name _;

ssl_certificate /etc/ssl/certs/phpldapadmin.crt;
ssl_certificate_key /etc/ssl/private/phpldapadmin.key;

root /var/lib/phpldapadmin/htdocs;
index index.php;

location ~ \.php$ {
include snippets/fastcgi-php.conf;
fastcgi_pass unix:/run/php/php8.1-fpm.sock;
}
}
```
you can use Let'sencript and the change the certificate and key paths in the server block

Troubleshooting:

PHP errors : `sudo journalctl -u php8.3-fpm`
Nginx logs : `tail -f /var/log/nginx/phpldapadmin_error.log`
PHP LDAP module check : `php -m | grep ldap`

Additional :

Instead of pointing directly to /usr/share

`sudo ln -s /usr/share/phpldapadmin/htdocs /var/www/phpldapadmin`

then in Nginx

`root /var/www/phpldapadmin;`
