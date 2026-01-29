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




