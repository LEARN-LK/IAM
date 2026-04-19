## Implementing Simpe Attribute-Release checker in Ubuntu 24

This is an Ubuntu-based setup for an attribute release check Service Provider , using a signed aggregate XML from your federation registry.

Also, for signed aggregate metadata, Shibboleth SP supports exactly the pattern you are using: a remote XML MetadataProvider with backingFilePath, periodic refresh, and a signature certificate; the certificate attribute is the local cert file used to verify the metadata signature.


### Pre-requisites

* Ubuntu server with root access
* Public DNS for the service
* HTTPS on port 443 must work from outside

1. Set hostname
`sudo hostnamectl set-hostname sp-test.YOUR-DOMAIN`

Check
`hostname -f`

2. Install base packages(Apache, Shibboleth SP and PHP)

```
sudo apt update
sudo apt install -y apache2 libapache2-mod-shib php php-cli openssl curl
```
Enable the apache modules

```
sudo a2enmod ssl headers shib
sudo systemctl enable apache2 shibd
```

3. Generate the Shibboleth SP Certificates

`sudo shib-keygen -f -u _shibd -h sp-test.YOUR-DOMAIN -y 10 -o /etc/shibboleth/`

This should create:
`/etc/shibboleth/sp-cert.pem`
`/etc/shibboleth/sp-key.pem`

4. Place the federation signing certificate

Download or coppy the certificate into `/etc/shibboleth`
This is the certificate Shibboleth will use to verify the signed aggregate metadata. That is exactly what the XML MetadataProvider certificate= attribute is for.

5. Backup existing `shibbolelth2.xml` file

```
cd /etc/shibboleth
cp shibboleth.xml shibboleth2.xml.back
```
6. Use the following block

```
<ApplicationDefaults entityID="https://sp-test.YOUR-DOMAIN/shibboleth"
    REMOTE_USER="eppn subject-id pairwise-id persistent-id"
    cipherSuites="DEFAULT:!EXP:!LOW:!aNULL:!eNULL:!DES:!IDEA:!SEED:!RC4:!3DES:!kRSA:!SSLv2:!SSLv3:!TLSv1:!TLSv1.1">

    <Sessions lifetime="28800" timeout="3600" relayState="ss:mem"
              checkAddress="false" handlerSSL="true" cookieProps="https">

        <SSO discoveryProtocol="SAMLDS"
             discoveryURL="https://DISCOVERY-SERVICE-URL/index.html">
          SAML2
        </SSO>

        <Logout>SAML2 Local</Logout>
        <LogoutInitiator type="Admin" Location="/Logout/Admin" acl="127.0.0.1 ::1" />
        <Handler type="MetadataGenerator" Location="/Metadata" signing="false"/>
        <Handler type="Status" Location="/Status" acl="127.0.0.1 ::1"/>
        <Handler type="Session" Location="/Session" showAttributeValues="false"/>
        <Handler type="DiscoveryFeed" Location="/DiscoFeed"/>
    </Sessions>

    <Errors supportContact="tac@ac.lk"
        helpLocation="/about.html"
        styleSheet="/shibboleth-sp/main.css"/>

    <MetadataProvider type="XML" validate="true"
          url="https://YOUR-FEDERATION-REGISTRY-URL/metadata.xml"
        backingFilePath="federation-metadata.xml"
        reloadInterval="1800">
        <MetadataFilter type="RequireValidUntil" maxValidityInterval="2419200"/>
        <MetadataFilter type="Signature" certificate="fedsigner.pem"/>
    </MetadataProvider>

    <AttributeExtractor type="XML" validate="true" reloadChanges="false" path="attribute-map.xml"/>
    <AttributeFilter type="XML" validate="true" path="attribute-policy.xml"/>

    <CredentialResolver type="File" use="signing"
        key="sp-key.pem" certificate="sp-cert.pem"/>
    <CredentialResolver type="File" use="encryption"
        key="sp-key.pem" certificate="sp-cert.pem"/>

</ApplicationDefaults>
```
Change the URLs for : `sp-test.YOUR-DOMAIN`,`YOUR-FEDERATION-REGISTRY-URL`,`DISCOVERY-SERVICE-URL`

And also make sure to check metadata.xml file to be in `/etc/shibboleth` 
TIP : for frist time, you will have to download the `metadata.xml` file into the location

7. Register the service in the Fedration Registry

   To get the metadata of the service, use the following link to download on the browser

`https://sp-test.liaf.ac.lk/Shibboleth.sso/Metadata`
   
8. Configure attribute mapping

`sudo nano /etc/shibboleth/attribute-map.xml`

add the attributes which should be checked, following block is an example block for reference

```
<Attribute name="urn:oid:2.5.4.3" id="cn"/>
<Attribute name="urn:oid:0.9.2342.19200300.100.1.1" id="uid"/>
<Attribute name="urn:oid:1.3.6.1.1.1.1.0" id="uidNumber"/>
<Attribute name="urn:oid:1.3.6.1.1.1.1.1" id="gidNumber"/>
<Attribute name="urn:oid:2.5.4.42" id="givenName"/>
<Attribute name="urn:oid:2.5.4.4" id="sn"/>
<Attribute name="urn:oid:0.9.2342.19200300.100.1.41" id="mobile"/>
<Attribute name="urn:oid:0.9.2342.19200300.100.1.3" id="mail"/>
<Attribute name="urn:oid:1.2.840.113549.1.9.1" id="email"/>
<Attribute name="urn:oid:1.3.6.1.4.1.5923.1.1.1.6" id="eduPersonPrincipalName"/>
<Attribute name="urn:oid:1.3.6.1.4.1.5923.1.1.1.1" id="eduPersonAffiliation"/>
<Attribute name="urn:oid:1.3.6.1.4.1.5923.1.1.1.3" id="eduPersonOrgUnitDN"/>
<Attribute name="urn:oid:1.3.6.1.4.1.5923.1.1.1.7" id="eduPersonEntitlement"/>
```

9. Create an Apache vhost:

`sudo vi /etc/apache2/sites-available/sp-test.OUR-DOMAIN.conf`

```
<VirtualHost *:443>
    ServerName sp-test.YOUR-DOMAIN
    DocumentRoot /var/www/sp-test

    <Directory /var/www/sp-test>
        AllowOverride None
        Require all granted
    </Directory>

    <Location />
        AuthType shibboleth
        ShibRequestSetting requireSession 1
        Require valid-user
    </Location>

    ErrorLog ${APACHE_LOG_DIR}/sp-test-error.log
    CustomLog ${APACHE_LOG_DIR}/sp-test-access.log combined
</VirtualHost>
```

Disable default site and Enable Sites

```
sudo a2dissite default00
sudo a2ensite sp-test.YOUR-DOMAIN.conf
sudo apachectl configtest
sudo systemctl reload apache2
```

10. Get a public TLS certificate for the website

```
sudo apt install -y certbot python3-certbot-apache
sudo certbot --apache -d sp-test.YOUR-DOMAIN
```

11. Create the attribute display page

Create a test application directory:
`sudo mkdir -p /var/www/sp-test`
`sudo chown -R www-data:www-data /var/www/sp-test`

`sudo nano /var/www/sp-test/index.php`

This is a simple page and you will have to modify acording to your requirements

```
<?php
function showAttr($name) {
    return htmlspecialchars($_SERVER[$name] ?? '', ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
?>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Attribute Release Check</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 30px; background: #f7f7f7; }
    .box { background: #fff; padding: 20px; border: 1px solid #ddd; border-radius: 8px; max-width: 1000px; }
    table { border-collapse: collapse; width: 100%; }
    td, th { border: 1px solid #ccc; padding: 8px; text-align: left; }
    th { background: #efefef; }
  </style>
</head>
<body>
<div class="box">
  <h2>Attribute Release Check</h2>
  <p><strong>SP:</strong> sp-test.YOUR-DOMAIN</p>
  <p><strong>IdP EntityID:</strong> <?= showAttr('Shib-Identity-Provider') ?></p>
  <table>
    <tr><th>Attribute</th><th>Value</th></tr>
    <tr><td>cn</td><td><?= showAttr('cn') ?></td></tr>
    <tr><td>uid</td><td><?= showAttr('uid') ?></td></tr>
    <tr><td>uidNumber</td><td><?= showAttr('uidNumber') ?></td></tr>
    <tr><td>gidNumber</td><td><?= showAttr('gidNumber') ?></td></tr>
    <tr><td>givenName</td><td><?= showAttr('givenName') ?></td></tr>
    <tr><td>sn</td><td><?= showAttr('sn') ?></td></tr>
    <tr><td>mobile</td><td><?= showAttr('mobile') ?></td></tr>
    <tr><td>mail</td><td><?= showAttr('mail') ?></td></tr>
    <tr><td>email</td><td><?= showAttr('email') ?></td></tr>
    <tr><td>eduPersonPrincipalName</td><td><?= showAttr('eduPersonPrincipalName') ?></td></tr>
    <tr><td>eduPersonAffiliation</td><td><?= showAttr('eduPersonAffiliation') ?></td></tr>
    <tr><td>eduPersonOrgUnitDN</td><td><?= showAttr('eduPersonOrgUnitDN') ?></td></tr>
    <tr><td>eduPersonEntitlement</td><td><?= showAttr('eduPersonEntitlement') ?></td></tr>
  </table>
</div>
</body>
</html>
```

12. Start the services
Check for config syntax

```
sudo shibd -t
sudo apachectl configtest
```
then start the services
```
sudo systemctl restart shibd
sudo systemctl restart apache2
sudo systemctl status shibd --no-pager
sudo systemctl status apache2 --no-pager
```
13. Test in the browser

Browse `https://sp-test.YOUR-DOMAIN` and then you will get Discovery page of the Federation registry and then log in with a user.
