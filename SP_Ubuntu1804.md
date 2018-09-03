# Shibboleth SP on Ubuntu Linux LTS 18.04

Based on [IDEM-TUTORIALS](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Service%20Provider/Debian/HOWTO%20Install%20and%20Configure%20a%20Shibboleth%20SP%20v2.x%20on%20Debian%20Linux%209%20(Stretch).md) by Marco Malavolti (marco.malavolti@garr.it)

Installation assumes you have already installed Ubuntu Server 18.04 with default configuration and has a public IP connectivity with DNS setup

Lets Assume your server hostname as **sp.YOUR-DOMAIN**

All commands are to be run as root and you may use `sudo su` to become root

1. Install the packages required: 
   * ```apt install apache2 ntp ca-certificates vim openssl binutils```
   

2. Modify ```/etc/hosts```:
   * ```vim /etc/hosts```
  
     ```bash
     127.0.0.1 sp.YOUR-DOMAIN sp
     ```
   (*Replace ```sp.YOUR-DOMAIN``` with your sp FQDN*)



### Install Shibboleth Service Provider

3. Install dependancies to overcome issues with libcurl libraries. ( Credits: [Josh L.'s Blog](https://depts.washington.edu/bitblog/2018/06/libcurl3-libcurl4-shibboleth-php-curl-ubuntu-18-04/) )
   * ```bash
     apt install liblog4shib1v5 libxerces-c3.2 libxml-security-c17v5 libcurl3
     cp /usr/lib/x86_64-linux-gnu/libcurl.so.4.5.0 /usr/lib/x86_64-linux-gnu/libcurl3.so.4.5.0
     apt-get install libcurl4
     mkdir ~/temp
     cd ~/temp
     apt-get download libxmltooling7 # Ignore the warnings
     ar x libxmltooling7_1.6.4-1ubuntu2_amd64.deb
     tar xf control.tar.xz
     sed -i -e 's/libcurl3 (>= 7.16.2)/libcurl4/g' control
     tar -cJvf control.tar.xz control md5sums shlibs triggers
     ar rcs libxmltooling-local.deb debian-binary control.tar.xz data.tar.xz
     dpkg -i libxmltooling-local.deb
     mkdir /etc/systemd/system/shibd.service.d
     ```
   * Create the following script to override defaults,
   * `vim /etc/systemd/system/shibd.service.d/override.conf`
   
     ```bash
     [Service]
     Environment="LD_PRELOAD=libcurl3.so.4.5.0"
     ```
   
4. Install Shibboleth SP:
   * ```bash
     apt install libapache2-mod-shib2 libapache2-mod-php
     ```

   From this point the location of the SP directory is: ```/etc/shibboleth```

## Configuration Instructions

### Configure Apache2

5. These configurations are based for test purposes with self generated ssl certificates. 
   If you have purchased ssl certificate from a commercial CA substitute those with the self signed files.
   If you wish to get **letsencrypt** certificates *Skip* to **Step 10**.

   Create a Certificate and a Key self-signed for HTTPS:
   * ```openssl req -x509 -newkey rsa:4096 -keyout /etc/ssl/private/ssl-sp.key -out /etc/ssl/certs/ssl-sp.crt -nodes -days 1095```

6. Modify the file ```/etc/apache2/sites-available/sp-ssl.conf``` as follows:

   ```apache
   <IfModule mod_ssl.c>
      SSLStaplingCache        shmcb:/var/run/ocsp(128000)
      <VirtualHost _default_:443>
        ServerName sp.YOUR-DOMAIN:443
        ServerAdmin admin@YOUR-DOMAIN
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
        SSLCertificateFile /etc/ssl/certs/ssl-sp.crt
        SSLCertificateKeyFile /etc/ssl/private/ssl-sp.key
        SSLCertificateChainFile /root/certificates/ssl-ca.pem
        ...
      </VirtualHost>
   </IfModule>
   ```

7. Enable **proxy_http**, **SSL** and **headers** Apache2 modules:
   * ```a2enmod proxy_http ssl headers alias include negotiation```
   * ```a2ensite sp-ssl.conf```
   * ```systemctl restart apache2```

8. Configure Apache2 to open port **80** only for localhost:
   * ```vim /etc/apache2/ports.conf```

     ```apache
     # If you just change the port or add more ports here, you will likely also
     # have to change the VirtualHost statement in
     # /etc/apache2/sites-enabled/000-default.conf

     Listen 127.0.0.1:80
 
     <IfModule ssl_module>
       Listen 443
     </IfModule>
    
     <IfModule mod_gnutls.c>
       Listen 443
     </IfModule>
     ```
9. Configure Apache2 to redirect all on HTTPS:
   * ```vim /etc/apache2/sites-enabled/000-default.conf```
   
     ```apache
     <VirtualHost *:80>
        ServerName "sp.YOUR-DOMAIN"
        Redirect permanent "/" "https://sp.YOUR-DOMAIN/"
        RedirectMatch permanent ^/(.*)$ https://sp.YOUR-DOMAIN/$1
     </VirtualHost>
     ```
10. **Let'sencrypt** setup (*Skip this step if you already configured SSL with self signed or CA provided certificates*)

    Disable the default configuration
    * `cd /etc/apache2/sites-available/`
    * `a2dissite 000-default.conf`
    * `systemctl reload apache2`

    Create a new conf file as `sp.conf`

    * `cp 000-default.conf sp.conf`

    Edit `sp.conf` with following

   * `vim sp.conf`

```apache
<VirtualHost *:80>
 
        ServerName sp.YOUR-DOMAIN
        ServerAdmin YOUR-Email
        DocumentRoot /var/www/html
        
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

</VirtualHost>
```

   Enable sp site by, 

   * `a2ensite sp` 
   
   and restart Apache 

   * `systemctl reload apache2`
   
   
   Install Letsencypt and enable https

```bash
add-apt-repository ppa:certbot/certbot
apt install python-certbot-apache
certbot --apache -d sp.YOUR-DOMAIN
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
http-01 challenge for sp.YOUR_DOMAIN
Waiting for verification...
Cleaning up challenges
Created an SSL vhost at /etc/apache2/sites-available/sp-le-ssl.conf
Enabled Apache socache_shmcb module
Enabled Apache ssl module
Deploying Certificate to VirtualHost /etc/apache2/sites-available/sp-le-ssl.conf
Enabling available site: /etc/apache2/sites-available/sp-le-ssl.conf


Please choose whether or not to redirect HTTP traffic to HTTPS, removing HTTP access.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
1: No redirect - Make no further changes to the webserver configuration.
2: Redirect - Make all requests redirect to secure HTTPS access. Choose this for
new sites, or if you're confident your site works on HTTPS. You can undo this
change by editing your web server's configuration.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Select the appropriate number [1-2] then [enter] (press 'c' to cancel): 2
Redirecting vhost in /etc/apache2/sites-enabled/sp.conf to ssl vhost in /etc/apache2/sites-available/sp-le-ssl.conf

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Congratulations! You have successfully enabled https://sp.YOUR-DOMAIN

```


### Configure Shibboleth SP



11. Download Federation Metadata Signing Certificate: (If its available)
   * ```cd /etc/shibboleth/```
   * ```wget https://LEARN-Test-federation/signning-key.pem```


12. Edit ```shibboleth2.xml``` opportunely:
   * ```vim /etc/shibboleth/shibboleth2.xml```

     ```bash
     ...
     <ApplicationDefaults entityID="https://sp.YOUR-DOMAIN/shibboleth"
          REMOTE_USER="eppn persistent-id targeted-id">
     ...
     <Sessions lifetime="28800" timeout="3600" checkAddress="false" handlerSSL="true" cookieProps="https">
     ...
     <SSO discoveryProtocol="SAMLDS" discoveryURL="https://fds-training.ac.lk">
        SAML2
     </SSO>
     ...
     <MetadataProvider type="XML" uri="https://fr-training.ac.lk/rr3/metadata/federation/FR-training/metadata.xml" legacyOrgName="true" backingFilePath="test-metadata.xml" reloadInterval="600">
           <!-- remove this comment if the signning key is available
           <MetadataFilter type="Signature" certificate="signning-key.pem"/>
           -->
           <MetadataFilter type="RequireValidUntil" maxValidityInterval="864000" />
     </MetadataProvider>
     ```
13. Create SP metadata credentials:
   * ```/usr/sbin/shib-keygen```
   * ```shibd -t /etc/shibboleth/shibboleth2.xml``` (Check Shibboleth configuration)

14. Enable Shibboleth Apache2 configuration:
   * ```a2enmod shib2```
   * ```systemctl reload apache2.service ```

15. Now you are able to reach your Shibboleth SP Metadata on:
   * ```https://sp.YOUR-DOMAIN/Shibboleth.sso/Metadata```
   (change ```sp.YOUR-DOMAIN``` to you SP full qualified domain name)

16. Register you SP on LEARN test federation:
   * Go to ```https://fr-training.ac.lk/rr3/providers/sp_registration``` and continue registration with pasting the content of your metadata file 


### Configure an example federated resouce "secure"

17. Create the Apache2 configuration for the application: 
   * ```sudo su -```

   * ```vim /etc/apache2/site-available/secure.conf```
  
     ```bash
     RedirectMatch    ^/$  /secure

     <Location /secure>
       Authtype shibboleth
       ShibRequireSession On
       require valid-user
     </Location>
     ```

18. Create the "```secure```" application into the DocumentRoot:
   * ```mkdir /var/www/html/secure```

   * ```vim /var/www/html/secure/index.php```

     ```html
     <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
     <html>
       <head>
         <title></title>
         <meta name="GENERATOR" content="Quanta Plus">
         <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
       </head>
       <body>
         <p>
          <a href="https://YOUR-DOMAIN/privacy.html">Privacy Policy</a>
         </p>
         <?php
         
         foreach ($_SERVER as $key => $value){
            print $key." = ".$value."<br>";
         }
         /*foreach ($_ENV as $key => $value){
            print $key." = ".$value."<br>";
         }
         foreach ($_COOKIE as $key => $value){
            print $key." = ".$value."<br>";
         }*/
         ?>
       </body>
     </html>
     ```

19. Install needed packages:
   * ```apt istall libapache2-mod-php```

   * ```systemctl restart apache2.service```


### Enable Attribute Support on Shibboleth SP
20. Enable attribute by remove comment from the related content into "```/etc/shibboleth/attribute-map.xml```"
    Disable First deprecated/incorrect version of ```persistent-id``` from ```attribute-map.xml```
    
### Enable Single Logout

21. Change <Logout> element in /etc/shibboleth/shibboleth2.xml. They get passed as attributes to the SAML2 LogoutInitiator that gets created by the Logout element.  The fully unfolded configuration with settings identical to default is:
```xml
<Logout asynchronous="true" outgoingBindings="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST urn:oasis:names:tc:SAML:2.0:bindings:SOAP">
  SAML2 Local
</Logout>
```
Setting asynchronous="false" would make the flow return back to the SP (this otherwise only happens for the SOAP binding which cannot be done asynchronously).


To initiate, create a button or link to go to a URL on the SP of the form: https://sp.example.org/Shibboleth.sso/Logout

The SLO would use an asynchronous message to the IdP and the flow would end at the IdP Logout page.  The user would be returned to the return URL only if the SLO is done in synchronous mode and the flow returns back to the SP.  To set the return URL, pass it in the return parameter as a query string to the Logout initiator - e.g.: https://sp.example.org/Shibboleth.sso/Logout?return=https://sp.example.org/logout-completed.html
