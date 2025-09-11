# Shibboleth SPv3 on Ubuntu Linux LTS 20.04

Installation assumes you have already installed Ubuntu Server 20.04 with default configuration and has a public IP connectivity with DNS setup

Lets Assume your server hostname as **sp.YOUR-DOMAIN**

All commands are to be run as root and you may use `sudo su` to become root

1. Install the packages required: 
   * ```apt install apache2 ca-certificates vim openssl binutils```
   

2. Modify ```/etc/hosts```:
   * ```vim /etc/hosts```
  
     ```bash
     127.0.0.1 sp.YOUR-DOMAIN sp
     ```
   (*Replace ```sp.YOUR-DOMAIN``` with your sp FQDN*)



### Install Shibboleth Service Provider
   
3. Install Shibboleth SP:
   * ```bash
     apt install libapache2-mod-shib ntp --no-install-recommends
     ```

   From this point the location of the SP directory is: ```/etc/shibboleth```

## Configuration Instructions

### Configure Apache2

4. These configurations are based for test purposes with self generated ssl certificates. 
   If you have purchased ssl certificate from a commercial CA substitute those with the self signed files.
   If you wish to get **letsencrypt** certificates *Skip* to **Step 10**.

5.  Create a Certificate and a Key self-signed for HTTPS:
   * ```openssl req -x509 -newkey rsa:4096 -keyout /etc/ssl/private/ssl-sp.key -out /etc/ssl/certs/ssl-sp.crt -nodes -days 1095```

6. Modify the file ```/etc/apache2/sites-available/sp-ssl.conf``` as follows:

   ```apache
   <IfModule mod_ssl.c>
      <VirtualHost *:443>

          ServerName sp.YOUR-DOMAIN

          ServerAdmin webmaster@localhost
          DocumentRoot /var/www/html

          ErrorLog ${APACHE_LOG_DIR}/error.log
          CustomLog ${APACHE_LOG_DIR}/access.log combined

        SSLCertificateFile /etc/ssl/certs/ssl-sp.crt
        SSLCertificateKeyFile /etc/ssl/private/ssl-sp.key
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
apt install certbot python3-certbot-apache
certbot --apache
```
   Go through the interactive prompt and include your server details. Make sure you select **redirect** option when asked.


### Configure Shibboleth SP



11. Download Federation Metadata Signing Certificate:
   * ```cd /etc/shibboleth/```
   * ```wget https://fr.ac.lk/signedmetadata/metadata-signer -O federation-cert.pem```


12. Edit ```shibboleth2.xml``` opportunely:
   * ```vim /etc/shibboleth/shibboleth2.xml```

     ```bash
     ...
     <ApplicationDefaults entityID="https://sp.YOUR-DOMAIN/shibboleth"
             REMOTE_USER="eppn subject-id pairwise-id persistent-id"
             cipherSuites="DEFAULT:!EXP:!LOW:!aNULL:!eNULL:!DES:!IDEA:!SEED:!RC4:!3DES:!kRSA:!SSLv2:!SSLv3:!TLSv1:!TLSv1.1">
     ...
     <Sessions lifetime="28800" timeout="3600" relayState="ss:mem" checkAddress="false" handlerSSL="true" cookieProps="https">
     ...
     <SSO discoveryProtocol="SAMLDS" discoveryURL="https://fds.ac.lk">
        SAML2
     </SSO>
     ...
     <MetadataProvider type="XML" url="https://fr.ac.lk/signedmetadata/metadata.xml" legacyOrgName="true" backingFilePath="test-metadata.xml" maxRefreshDelay="7200">
           
           <MetadataFilter type="Signature" certificate="federation-cert.pem" verifyBackup="false"/>
           
           <MetadataFilter type="RequireValidUntil" maxValidityInterval="864000" />
     </MetadataProvider>
     <!-- Simple file-based resolvers for separate signing/encryption keys. -->
     <CredentialResolver type="File" use="signing"
           key="sp-signing-key.pem" certificate="sp-signing-cert.pem"/>
     <CredentialResolver type="File" use="encryption"
           key="sp-encrypt-key.pem" certificate="sp-encrypt-cert.pem"/>
     ```
13. Create SP metadata credentials:
   * ```/usr/sbin/shib-keygen -n sp-signing -e https://sp.YOUR-DOMAIN/shibboleth```
   * ```/usr/sbin/shib-keygen -n sp-encrypt -e https://sp.YOUR-DOMAIN/shibboleth```
   * ```shibd -t /etc/shibboleth/shibboleth2.xml``` (Check Shibboleth configuration)

14. Enable Shibboleth Apache2 configuration:
   * ```a2enmod shib```
   * ```systemctl reload apache2.service ```

15. Now you are able to reach your Shibboleth SP Metadata on:
   * ```https://sp.YOUR-DOMAIN/Shibboleth.sso/Metadata```
   (change ```sp.YOUR-DOMAIN``` to you SP full qualified domain name)

16. Register your SP on LEARN test federation:
   * Go to ```https://liaf.ac.lk/#join``` and follow the Service provider registration. Once the federation operator approves your request, you will be asked to use the content of your metadata file on federation registry registration.

You may have to answer several questions decsribing your service to the federation provider.

### Configure an example federated resouce "secure"

17. Create the Apache2 configuration for the application: 
   * ```sudo su -```

   * ```vim /etc/apache2/sites-available/secure.conf```
  
     ```bash
     #RedirectMatch    ^/$  /secure

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
         <p> <a href="https://sp.YOUR-DOAMIN/Shibboleth.sso/Logout"><button>Sign Out</button></a> </p>
       </body>
     </html>
     ```

19. Install needed packages:
   * ```apt install libapache2-mod-php php```
   
   * ```a2ensite secure```
  
   * ```systemctl restart shibd```
   
   * ```systemctl restart apache2```

   Now you may browse to `https://sp.YOUR-DOMAIN/secure` and select your IDP to log in.
   
### Enable Attribute Support on Shibboleth SP
20. Enable attribute by removing comment from the related content of ```/etc/shibboleth/attribute-map.xml``` you may enable any attribute map as per your requirement. Restart Shibd to apply ```systemctl restart shibd.service```
    

**Note**

For this system following parameters may come in handy.

* Login Initiator: `https://sp.YOUR-DOMAIN/Shibboleth.sso/Login`

* Logout Initiator: `https://sp.YOUR-DOMAIN/Shibboleth.sso/Logout`


### Credits

* The original autor: Marco Malavolti (marco.malavolti@garr.it) 
* eduGAIN Wiki: For the original [How to configure Shibboleth SP attribute checker](https://wiki.geant.org/display/eduGAIN/How+to+configure+Shibboleth+SP+attribute+checker)


### Enable Attribute Checker Support on Shibboleth SP (OPTIONAL)
1. Add a sessionHook for attribute checker: `sessionHook="/Shibboleth.sso/AttrChecker"` and the `metadataAttributePrefix="Meta-"` to `ApplicationDefaults`:
   * `vim /etc/shibboleth/shibboleth2.xml`

     ```bash
     <ApplicationDefaults entityID="https://sp.example.org/shibboleth"
                          REMOTE_USER="eppn subject-id pairwise-id persistent-id"
                          cipherSuites="DEFAULT:!EXP:!LOW:!aNULL:!eNULL:!DES:!IDEA:!SEED:!RC4:!3DES:!kRSA:!SSLv2:!SSLv3:!TLSv1:!TLSv1.1"
                          sessionHook="/Shibboleth.sso/AttrChecker"
                          metadataAttributePrefix="Meta-" >
     ```

2. Add the attribute checker handler with the list of required attributes to Sessions (in the example below: `displayName`, `givenName`, `mail`, `cn`, `sn`, `eppn`, `schacHomeOrganization`, `schacHomeOrganizationType`). The attributes' names HAVE TO MATCH with those are defined on `attribute-map.xml`:
   * `vim /etc/shibboleth/shibboleth2.xml`

     ```bash
        ...
        <!-- Attribute Checker -->
        <Handler type="AttributeChecker" Location="/AttrChecker" template="attrChecker.html" attributes="displayName givenName mail cn sn eppn schacHomeOrganization schacHomeOrganizationType" flushSession="true"/>
     </Sessions>
     ```
     
     If you want to describe more complex scenarios with required attributes, operators such as "AND" and "OR" are available.
     ```bash
     <Handler type="AttributeChecker" Location="/AttrChecker" template="attrChecker.html" flushSession="true">
        <OR>
           <Rule require="displayName"/>
           <AND>
              <Rule require="givenName"/>
              <Rule require="surname"/>
           </AND>
        </OR>
      </Handler>
      ```

3. Add the following `<AttributeExtractor>` element under `<AttributeExtractor type="XML" validate="true" reloadChanges="false" path="attribute-map.xml"/>`:
   * `vim /etc/shibboleth/shibboleth2.xml`

     ```bash
     <!-- Extracts support information for IdP from its metadata. -->
     <AttributeExtractor type="Metadata" errorURL="errorURL" DisplayName="displayName"
                         InformationURL="informationURL" PrivacyStatementURL="privacyStatementURL"
                         OrganizationURL="organizationURL">
        <ContactPerson id="Technical-Contact"  contactType="technical" formatter="$EmailAddress" />
        <Logo id="Small-Logo" height="16" width="16" formatter="$_string"/>
     </AttributeExtractor>
     ```

4. Save and restart "shibd" service:
   * `systemctl restart shibd.service`
   
5. Customize Attribute Checker template:
   * `cd /etc/shibboleth`
   * `cp attrChecker.html attrChecker.html.orig`
   * `wget https://raw.githubusercontent.com/CSCfi/shibboleth-attrchecker/master/attrChecker.html -O attrChecker.html`
   * `sed -i 's/SHIB_//g' /etc/shibboleth/attrChecker.html`
   * `sed -i 's/eduPersonPrincipalName/eppn/g' /etc/shibboleth/attrChecker.html`
   * `sed -i 's/Meta-Support-Contact/Meta-Technical-Contact/g' /etc/shibboleth/attrChecker.html`
   * `sed -i 's/supportContact/technicalContact/g' /etc/shibboleth/attrChecker.html`
   * `sed -i 's/support/technical/g' /etc/shibboleth/attrChecker.html`

   There are three locations needing modifications to do on `attrChecker.html`:

   1. The pixel tracking link after the comment "PixelTracking". 
      The Image tag and all required attributes after the variable must be configured here. 
      After "`miss=`" define all required attributes you updated in `shibboleth2.xml` using shibboleth tagging. 
      
      Eg `<shibmlpifnot $attribute>-$attribute</shibmlpifnot>` (this echoes $attribute if it's not received by shibboleth).
      The attributes' names HAVE TO MATCH with those are defined on `attribute-map.xml`.
      
      This example uses "`-`" as a delimiter.
      
   2. The table showing missing attributes between the tags "`<!--TableStart-->`" and "`<!--TableEnd-->`". 
      You have to insert again all the same attributes as above.

      Define row for each required attribute (eg: `displayName` below)

      ```html
      <tr <shibmlpifnot displayName> class='warning text-danger'</shibmlpifnot>>
        <td>displayName</td>
        <td><shibmlp displayName /></td>
      </tr>
      ```

   3. The email template between the tags "<textarea>" and "</textarea>". After "The attributes that were not released to the service are:". 

      Again define all required attributes using shibboleth tagging like in section 1 ( eg: `<shibmlpifnot $attribute> * $attribute</shibmlpifnot>`).
      The attributes' names HAVE TO MATCH with those are defined on `attribute-map.xml`.
      Note that for SP identifier target URL is used instead of entityID. 
      There arent yet any tag for SP entityID so you can replace this target URL manually.

6. Enable Logging:
   * Create your `track.png` with into your DocumentRoot:
   
     ```bash
     echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==" | base64 -d > /var/www/html/$(hostname -f)/track.png
     ```

   * Results into `/var/log/apache2/other_vhosts_access.log`:
   
   ```bash
   ./apache2/other_vhosts_access.log:193.206.129.66 - - [20/Sep/2018:15:05:07 +0000] "GET /track.png?idp=https://garr-idp-test.irccs.garr.it/idp/shibboleth&miss=-SHIB_givenName-SHIB_cn-SHIB_sn-SHIB_eppn-SHIB_schacHomeOrganization-SHIB_schacHomeOrganizationType HTTP/1.1" 404 637 "https://sp.example.org/Shibboleth.sso/AttrChecker?return=https%3A%2F%2Fsp.example.org%2FShibboleth.sso%2FSAML2%2FPOST%3Fhook%3D1%26target%3Dss%253Amem%253A43af2031f33c3f4b1d61019471537e5bc3fde8431992247b3b6fd93a14e9802d&target=https%3A%2F%2Fsp.example.org%2Fsecure%2F"
   ```
