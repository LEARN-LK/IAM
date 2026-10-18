# Enabling MFA in Shibboleth V5 - Ubuntu 24

What the guide does:
The flow is: User → Password login → TOTP code entry → IdP issues SAML assertion
It uses Shibboleth's official TOTP plugin (net.shibboleth.idp.plugin.authn.totp) — this is the correct, supported approach for IdP 5, not any third-party plugin.

We will:

* Install the official Shibboleth TOTP plugin
* Enable the MFA flow
* Wire Password → TOTP in the MFA transition map
* Store TOTP seeds (static for testing, LDAP/DB for production)
* Generate seeds for users
* Rebuild and test

Step 1 — Install the TOTP Plugin
Run as root (or sudo). The plugin.sh script downloads, verifies, and installs the plugin.

```
cd /opt/shibboleth-idp
bin/plugin.sh -I net.shibboleth.idp.plugin.authn.totp
```
When prompted to accept the `license/trust, type y.`

Verify installation:

`bin/plugin.sh -l`

You should see `net.shibboleth.idp.plugin.authn.totp` listed.

The plugin automatically enables the idp.authn.TOTP module and installs:

`views/totp.vm` — the TOTP code entry page

`views/totp-error.vm` — error page

`bin/totpauth.sh` — CLI tool for seed generation and testing

Step 2 — Enable the MFA Module
The MFA flow must be explicitly enabled if this is a fresh IdP 5 install:

```
cd /opt/shibboleth-idp
bin/module.sh -t idp.authn.MFA || bin/module.sh -e idp.authn.MFA
```

No output (or "module already enabled") is the expected result.

Step 3 — Configure idp.properties to Use MFA Flow

`vi /opt/shibboleth-idp/conf/idp.properties`

Find the `idp.authn.flows` line and change it to:

`idp.authn.flows = MFA`

Important: Only MFA should be listed here. Do NOT list Password or TOTP separately — the MFA flow calls them internally. Listing them separately causes double-execution bugs.

Step 4 — Configure the MFA Transition Map
This tells the IdP: "After Password succeeds, always run TOTP next."

`vi /opt/shibboleth-idp/conf/authn/mfa-authn-config.xml`

Replace the entire contents with:

```
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:util="http://www.springframework.org/schema/util"
       xmlns:p="http://www.springframework.org/schema/p"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="http://www.springframework.org/schema/beans
                           http://www.springframework.org/schema/beans/spring-beans.xsd
                           http://www.springframework.org/schema/util
                           http://www.springframework.org/schema/util/spring-util.xsd"
       default-init-method="initialize"
       default-destroy-method="destroy">

    <util:map id="shibboleth.authn.MFA.TransitionMap">

        <!-- Step 1: Start with Password -->
        <entry key="">
            <bean parent="shibboleth.authn.MFA.Transition" p:nextFlow="authn/Password" />
        </entry>

        <!-- Step 2: After Password succeeds, go to TOTP -->
        <entry key="authn/Password">
            <bean parent="shibboleth.authn.MFA.Transition" p:nextFlow="authn/TOTP" />
        </entry>

        <!-- Step 3: After TOTP succeeds, MFA is complete (no entry = implicit finish) -->

    </util:map>

</beans>

```
Step 5 — Define Token Seeds
Choose one option depending on your environment.

LDAP-backed Seeds (Production)
Store the Base32 seed in an LDAP attribute (e.g., totpSecret) on each user object.
Then in your attribute resolver (attribute-resolver-LEARN-v5.xml file), add:

```
<AttributeDefinition xsi:type="Simple" id="tokenSeeds">
    <InputDataConnector ref="myLDAP" attributeNames="totpSecret" />
</AttributeDefinition>
```

The TOTP plugin will automatically call the attribute resolver to fetch the attribute named tokenSeeds (this is the default; no extra config needed unless you renamed it).

ℹ️ The LDAP attribute must contain the plain Base32-encoded seed (not encrypted). For encrypted seeds, see the DataSealer section in the official plugin docs.

#### Clock Sync Check (Important for TOTP)
T
OTP codes are time-based. If the server clock drifts, codes will fail.

Check current NTP sync status
`timedatectl status`

If not synced, ensure NTP is running
`systemctl enable --now ntp`

or on systemd-timesyncd systems:
`timedatectl set-ntp true`

 Edit conf/authn/authn.properties

 `vi /opt/shibboleth-idp/conf/authn/authn.properties`

 Add these lines (append to the end of the file, or find any existing idp.authn.MFA.supportedPrincipals line and replace it):

 ```
idp.authn.MFA.supportedPrincipals = \
    saml2/https://refeds.org/profile/mfa, \
    saml2/urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport, \
    saml2/urn:oasis:names:tc:SAML:2.0:ac:classes:Password, \
    saml1/urn:oasis:names:tc:SAML:1.0:am:password

idp.authn.TOTP.supportedPrincipals = \
    saml2/https://refeds.org/profile/mfa, \
    saml2/urn:oasis:names:tc:SAML:2.0:ac:classes:TimeSyncToken, \
    saml1/urn:oasis:names:tc:SAML:1.0:am:HardwareToken
```
Edit `vi /opt/shibboleth-idp/conf/relying-party.xml`

Find the shibboleth.DefaultRelyingParty bean and add defaultAuthenticationMethods to the SAML2.SSO profile configuration. It will look something like this — find your existing SAML2.SSO bean and add the property:

```
<bean id="shibboleth.DefaultRelyingParty" parent="RelyingParty">
    <property name="profileConfigurations">
        <list>
            <bean parent="SAML2.SSO">
                <property name="defaultAuthenticationMethods">
                    <bean parent="shibboleth.SAML2AuthnContextClassRef"
                          c:classRef="https://refeds.org/profile/mfa" />
                </property>
            </bean>
            <ref bean="SAML2.ECP" />
            <ref bean="SAML2.Logout" />
            <ref bean="SAML2.AttributeQuery" />
            <ref bean="SAML2.ArtifactResolution" />
        </list>
    </property>
</bean>
```

Rebuild and Restart

```
cd /opt/shibboleth-idp
bin/build.sh
systemctl restart jetty
sleep 10
systemctl status jetty
```
Remove temp files if needed: TIP : `bin/build.sh && rm -rf jetty-tmp/* && systemctl restart jetty`
 
### Do this on your LDAP server:

Step 1 — Create the Custom Schema File

`vi /tmp/totp-schema.ldif`

Paste the following content:

```
dn: cn=totp,cn=schema,cn=config
objectClass: olcSchemaConfig
cn: totp
olcAttributeTypes: ( 1.3.6.1.4.1.55053.1.1
  NAME 'totpSecret'
  DESC 'TOTP seed for MFA authentication'
  EQUALITY caseExactMatch
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
  SINGLE-VALUE )
olcObjectClasses: ( 1.3.6.1.4.1.55053.2.1
  NAME 'totpUser'
  DESC 'User with TOTP MFA'
  AUXILIARY
  MAY ( totpSecret ) )
```

Step 2 — Load the Schema

`ldapadd -Y EXTERNAL -H ldapi:/// -f /root/totp-schema.ldif`

Expected output:

`adding new entry "cn=totp,cn=schema,cn=config"`

Step 3 — Now Add the Attribute to the User

in the file `add-totp-user.ldif` paste the following

```
dn: uid=<UID>,ou=people,dc=<YOUR-DOMAIN>,dc=ac,dc=lk
changetype: modify
add: objectClass
objectClass: totpUser
-
add: totpSecret
totpSecret: 7ZODY4DQQ76DHYL3JK66DJIR3TE3QPW5
```

Apply it:
```
ldapmodify -H ldap://localhost -x \
  -D "cn=admin,dc=<YOUR-DOMAIN>,dc=ac,dc=lk" \
  -W -f add-totp-user.ldif
```

Step 4 — Verify

```
ldapsearch -H ldap://localhost -x \
  -D "cn=admin,dc=<YOUR-DOMAIN>,dc=ac,dc=lk" \
  -W -b "uid=testme,ou=people,dc=<YOUR-DOMAIN>,dc=ac,dc=lk" \
  totpSecret
```
### when we are going to create QR code for user profile adding to TOTP app

default is api.qrserver.com is used by the plugin, but let's install a local qr server for a safer approach

Install qrencode
```
sudo apt update && sudo apt install -y qrencode apache2-utils
```

Move the images out of the web root so Apache can’t serve them directly and bypass the script
```
sudo mkdir -p /var/lib/totp-qr
sudo chown root:www-data /var/lib/totp-qr
sudo chmod 770 /var/lib/totp-qr      # www-data needs write access to delete files
```

Create `/usr/local/lib/totp-qr/qr.cgi`

```
#!/bin/bash
QR_DIR="/var/lib/totp-qr"
FILE=$(echo "$QUERY_STRING" | sed -n 's/^f=\([A-Za-z0-9._-]*\)$/\1/p')

if [ "$REQUEST_METHOD" = "GET" ] && [ -n "$FILE" ] && [[ "$FILE" != *..* ]] && [ -f "$QR_DIR/$FILE" ]; then
    echo "Content-Type: image/png"
    echo "Cache-Control: no-store"
    echo ""
    cat "$QR_DIR/$FILE"
    rm -f "$QR_DIR/$FILE"
else
    echo "Status: 404 Not Found"
    echo "Content-Type: text/plain"
    echo ""
    echo "This link has expired or was already used."
fi
```

```
sudo mkdir -p /usr/local/lib/totp-qr
sudo chmod 755 /usr/local/lib/totp-qr/qr.cgi
sudo a2enmod cgid
```
create `/etc/apache2/sites-available/totp-qr.conf` file

`vi /etc/apache2/sites-available/totp-qr.conf`

Change the names accordingly
```
Listen 8443
<VirtualHost *:8443>
    ServerName idpv5.<YOUR-DOMAIN>.ac.lk
    DocumentRoot /var/www/html

    SSLEngine on
    SSLCertificateFile    /etc/letsencrypt/live/idpv5.learn.ac.lk/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/idpv5.learn.ac.lk/privkey.pem

    ScriptAlias /qr /usr/local/lib/totp-qr/qr.cgi
    <Directory /usr/local/lib/totp-qr>
        Options +ExecCGI
        Require all granted
    </Directory>
</VirtualHost>
```
Enable the site 
```
sudo a2ensite totp-qr
sudo systemctl restart apache2
```
Add this line to crontab: change the cleanup window accordingly

`echo '*/30 * * * * root find /var/lib/totp-qr -name "*.png" -mmin +1440 -delete' | sudo tee /etc/cron.d/totp-qr-cleanup`

create the following file 
`vi /usr/local/bin/totp-gen`
Change the url of the QR server : IDP is used to install QR server in the test setup

```
#!/bin/bash
# Usage: totp-gen <username> [--png]
IDP_HOME="/opt/shibboleth-idp"
ISSUER="LEARN IdP"
QR_DIR="/var/www/totp-qr"
QR_BASE_URL="https://<URL-IDP>:8443"

USERNAME="$1"
[ -z "$USERNAME" ] && { echo "Usage: $0 <username> [--png]"; exit 1; }

OUT=$("$IDP_HOME/bin/totpauth.sh" --home "$IDP_HOME" --issuer "$ISSUER" --account "$USERNAME" 2>/dev/null)
SEED=$(echo "$OUT" | grep "^Seed:" | awk '{print $2}')
OTP_URL=$(echo "$OUT" | grep "^URL:" | awk '{print $2}')

[ -z "$SEED" ] && { echo "ERROR: could not generate seed"; exit 1; }

echo "Seed: $SEED"
echo "URL:  $OTP_URL"
echo

if [ "$2" = "--png" ]; then
    RAND=$(openssl rand -hex 16)
    QR_FILE="${USERNAME}-${RAND}.png"
    qrencode -o "$QR_DIR/$QR_FILE" -s 8 -m 2 -l M "$OTP_URL"
    chgrp www-data "$QR_DIR/$QR_FILE"
    chmod 640 "$QR_DIR/$QR_FILE"
    echo "QR Code: ${QR_BASE_URL}/${QR_FILE}"
else
    qrencode -t ANSIUTF8 "$OTP_URL"
fi
```
Change the permission
`chmod 700 /usr/local/bin/totp-gen`



### now let's create the totp tokens for the users

Command to generate the TOTP token (seed)

from the terminal:
test :
`totp-gen <username>`

For bulk user update, use the script file as follows

`cd ~ && wget https://raw.githubusercontent.com/LEARN-LK/IAM/refs/heads/master/allowing_services_IDP/bulk-totp-enroll.sh && chmod +x bulk-totp-enroll.sh`

Then you will get a csv file with the details for the users already existing in the system(whose who needed to be updated with new schema and tokens)

