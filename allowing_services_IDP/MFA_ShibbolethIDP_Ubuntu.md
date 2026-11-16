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

If it is not in Asia/Colombo timezone, use
`sudo timedatectl set-timezone Asia/Colombo`
`timedatectl status`

#### Configure authentication properties

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

`vi /root/totp-schema.ldif`

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
    SSLCertificateFile    /etc/letsencrypt/live/idpv5.<YOUR-DOMAIN>.ac.lk/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/idpv5.<YOUR-DOMAIN>.ac.lk/privkey.pem

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
ISSUER="UNIVERSITY - IdP"
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



------------------------------------------------------------


------------------------------------------------------------

1. Install packages
bash
sudo apt update
sudo apt install -y qrencode apache2 libaprutil1-ldap
2. Create the directories
bash
# QR images (outside the web root, never served directly)
sudo mkdir -p /var/lib/totp-qr
sudo chown root:www-data /var/lib/totp-qr
sudo chmod 770 /var/lib/totp-qr

# Empty web root for the 8443 site
sudo mkdir -p /var/www/totp-empty

# CGI script folder
sudo mkdir -p /usr/local/lib/totp-qr
3. Enable the Apache modules
bash
sudo a2enmod ssl cgid ldap authnz_ldap
4. Check that Apache can search your LDAP
bash
ldapsearch -x -H ldap://localhost -b "ou=People,dc=learn,dc=ac,dc=lk" "(uid=testme)" uid

This must return the testme entry. If it returns nothing or “insufficient access”, anonymous search is blocked, and you need to uncomment the bind DN lines in step 6.

5. Create the CGI script

It serves the logged-in user’s own image once, then deletes it. REMOTE_USER is set by Apache after the LDAP login.

bash
sudo tee /usr/local/lib/totp-qr/qr.cgi > /dev/null <<'EOF'
#!/bin/bash
# Serves the logged-in user's own QR image once, then deletes it.
# REMOTE_USER is set by Apache after the LDAP login.
QR_DIR="/var/lib/totp-qr"
USER_NAME=$(printf '%s' "$REMOTE_USER" | sed -n 's/^\([A-Za-z0-9._@-]\{1,64\}\)$/\1/p')
FILE="$QR_DIR/$USER_NAME.png"

if [ "$REQUEST_METHOD" = "GET" ] && [ -n "$USER_NAME" ] && [[ "$USER_NAME" != *..* ]] && [ -f "$FILE" ]; then
    echo "Content-Type: image/png"
    echo "Cache-Control: no-store"
    echo ""
    cat "$FILE"
    rm -f "$FILE"
else
    echo "Status: 404 Not Found"
    echo "Content-Type: text/plain"
    echo ""
    echo "No QR code is available for your account. It may have been used already or expired. Contact the administrator."
fi
EOF
sudo chmod 755 /usr/local/lib/totp-qr/qr.cgi
6. Create the Apache site with LDAP login

First check the certificate folder name: ls /etc/letsencrypt/live/. If it isn’t idpv5.learn.ac.lk, change the two SSLCertificate lines.

bash
sudo tee /etc/apache2/sites-available/totp-qr.conf > /dev/null <<'EOF'
Listen 8443
<VirtualHost *:8443>
    ServerName idpv5.learn.ac.lk
    DocumentRoot /var/www/totp-empty

    SSLEngine on
    SSLCertificateFile    /etc/letsencrypt/live/idpv5.learn.ac.lk/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/idpv5.learn.ac.lk/privkey.pem

    ScriptAlias /qr /usr/local/lib/totp-qr/qr.cgi

    <Directory /var/www/totp-empty>
        Options -Indexes
        Require all granted
    </Directory>

    <Directory /usr/local/lib/totp-qr>
        Options +ExecCGI

        AuthType Basic
        AuthName "LEARN account login (to get your MFA QR code)"
        AuthBasicProvider ldap
        AuthLDAPURL "ldap://localhost:389/ou=People,dc=learn,dc=ac,dc=lk?uid?sub?(objectClass=*)"
        AuthLDAPRemoteUserAttribute uid
        # Only if anonymous search is blocked, uncomment and set these two:
        # AuthLDAPBindDN "cn=admin,dc=learn,dc=ac,dc=lk"
        # AuthLDAPBindPassword "CHANGE_ME"
        Require valid-user
    </Directory>
</VirtualHost>
EOF

If you add the bind password, protect the file:

bash
sudo chmod 640 /etc/apache2/sites-available/totp-qr.conf
7. Enable the site and start Apache
bash
sudo a2ensite totp-qr
sudo apachectl configtest
sudo systemctl restart apache2
sudo ss -tlnp | grep 8443

configtest must print Syntax OK, and the last command must show Apache listening on 8443. If not, stop and check sudo tail -n 50 /var/log/apache2/error.log.

8. Firewall and DNS
bash
sudo ufw allow 8443/tcp
dig +short idpv5.learn.ac.lk @8.8.8.8

dig must return your server’s public IP. Also open TCP 8443 in any upstream or hosting firewall.

9. Reload Apache after certificate renewals
bash
sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-apache.sh > /dev/null <<'EOF'
#!/bin/bash
systemctl reload apache2
EOF
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-apache.sh
10. Cleanup job for images nobody downloaded
bash
sudo tee /etc/cron.d/totp-qr-cleanup > /dev/null <<'EOF'
*/30 * * * * root find /var/lib/totp-qr -name "*.png" -mmin +1440 -delete
EOF

Images are deleted after 24 hours. Downloaded images are already deleted by the CGI script.

11. Create the single-user tool (totp-gen)
bash
sudo tee /usr/local/bin/totp-gen > /dev/null <<'EOF'
#!/bin/bash
# Usage: totp-gen <username> [--png]
# Generates a TOTP seed for one user and shows a QR code locally.
# This only generates the seed. Store it in LDAP (totpSecret) to enroll the user.
IDP_HOME="/opt/shibboleth-idp"
ISSUER="LEARN IdP"
QR_DIR="/var/lib/totp-qr"
QR_BASE_URL="https://idpv5.learn.ac.lk:8443"

USERNAME="$1"
[ -z "$USERNAME" ] && { echo "Usage: $0 <username> [--png]"; exit 1; }
command -v qrencode >/dev/null 2>&1 || { echo "ERROR: qrencode not installed"; exit 1; }

OUT=$("$IDP_HOME/bin/totpauth.sh" --home "$IDP_HOME" --issuer "$ISSUER" --account "$USERNAME" 2>/dev/null)
SEED=$(echo "$OUT" | grep "^Seed:" | awk '{print $2}')
OTP_URL=$(echo "$OUT" | grep "^URL:" | awk '{print $2}')

[ -z "$SEED" ] && { echo "ERROR: could not generate seed"; exit 1; }

echo "Seed: $SEED"
echo "URL:  $OTP_URL"
echo

if [ "$2" = "--png" ]; then
    qrencode -o "$QR_DIR/$USERNAME.png" -s 8 -m 2 -l M "$OTP_URL"
    chgrp www-data "$QR_DIR/$USERNAME.png"
    chmod 640 "$QR_DIR/$USERNAME.png"
    echo "User can log in at ${QR_BASE_URL}/qr to download the QR code (one time)."
else
    qrencode -t ANSIUTF8 "$OTP_URL"
fi
EOF
sudo chmod 700 /usr/local/bin/totp-gen
12. Create the bulk enrollment script
bash
sudo tee /root/bulk-totp-enroll.sh > /dev/null <<'SCRIPT_EOF'
#!/bin/bash
#
# bulk-totp-enroll.sh
# Generates a TOTP seed for every LDAP user without one, stores it in LDAP
# (totpSecret), creates the user's QR image, and writes
# uid, mail, seed and the login URL to a CSV file.
# Users log in with their LDAP account at QR_BASE_URL/qr to download the image once.

# ---------- Settings ----------
LDAP_HOST="ldap://localhost"
LDAP_BIND_DN="cn=admin,dc=learn,dc=ac,dc=lk"
LDAP_BIND_PW="CHANGE_ME"
LDAP_BASE="ou=People,dc=learn,dc=ac,dc=lk"
IDP_HOME="/opt/shibboleth-idp"
ISSUER="LEARN IdP"

QR_DIR="/var/lib/totp-qr"
QR_BASE_URL="https://idpv5.learn.ac.lk:8443"
QR_GROUP="www-data"

# The CSV contains secrets, so make it readable by root only
umask 077
OUTPUT_CSV="/root/totp-seeds-$(date +%Y%m%d-%H%M%S).csv"

# ---------- Pre-flight checks ----------
if [ "$LDAP_BIND_PW" = "CHANGE_ME" ]; then
    echo "ERROR: set LDAP_BIND_PW in this script first."
    exit 1
fi

if ! command -v qrencode >/dev/null 2>&1; then
    echo "ERROR: qrencode is not installed. Run: sudo apt install -y qrencode"
    exit 1
fi

if [ ! -d "$QR_DIR" ]; then
    echo "ERROR: QR directory $QR_DIR does not exist."
    exit 1
fi

echo "uid,mail,seed,qr_login_url" > "$OUTPUT_CSV"

# ---------- Main ----------
USERNAMES=$(ldapsearch -H "$LDAP_HOST" -x \
  -D "$LDAP_BIND_DN" -w "$LDAP_BIND_PW" \
  -b "$LDAP_BASE" "(uid=*)" uid \
  | grep "^uid:" | awk '{print $2}')

for USERNAME in $USERNAMES; do
    # The login page only serves usernames made of these characters
    if ! [[ "$USERNAME" =~ ^[A-Za-z0-9._@-]{1,64}$ ]] || [[ "$USERNAME" == *..* ]]; then
        echo "SKIP: $USERNAME has characters not supported by the QR login page"
        continue
    fi

    # Skip if already has a seed
    EXISTING=$(ldapsearch -H "$LDAP_HOST" -x \
      -D "$LDAP_BIND_DN" -w "$LDAP_BIND_PW" \
      -b "$LDAP_BASE" "(uid=$USERNAME)" totpSecret \
      | grep "^totpSecret")

    if [ -n "$EXISTING" ]; then
        echo "SKIP: $USERNAME already has a seed"
        continue
    fi

    # Generate seed
    SEED_OUTPUT=$("$IDP_HOME/bin/totpauth.sh" --home "$IDP_HOME" \
      --issuer "$ISSUER" --account "$USERNAME" 2>/dev/null)
    SEED=$(echo "$SEED_OUTPUT" | grep "^Seed:" | awk '{print $2}')
    OTP_URL=$(echo "$SEED_OUTPUT" | grep "^URL:" | awk '{print $2}')

    if [ -z "$SEED" ] || [ -z "$OTP_URL" ]; then
        echo "ERROR: Could not generate seed for $USERNAME"
        continue
    fi

    # Get user DN and mail in one search
    LDAP_RESULT=$(ldapsearch -H "$LDAP_HOST" -x \
      -D "$LDAP_BIND_DN" -w "$LDAP_BIND_PW" \
      -b "$LDAP_BASE" "(uid=$USERNAME)" dn mail)

    USER_DN=$(echo "$LDAP_RESULT" | grep "^dn:" | sed 's/^dn: //')
    MAIL=$(echo "$LDAP_RESULT"    | grep "^mail:" | awk '{print $2}')

    if [ -z "$MAIL" ]; then
        MAIL="no-mail"
    fi

    # Generate the user's QR PNG (served only to that user after LDAP login)
    QR_FILE="${USERNAME}.png"
    if ! qrencode -o "$QR_DIR/$QR_FILE" -s 8 -m 2 -l M "$OTP_URL"; then
        echo "ERROR: Could not generate QR code for $USERNAME"
        continue
    fi
    chgrp "$QR_GROUP" "$QR_DIR/$QR_FILE"
    chmod 640 "$QR_DIR/$QR_FILE"
    QR_URL="${QR_BASE_URL}/qr"

    # Write to LDAP
    ldapmodify -H "$LDAP_HOST" -x \
      -D "$LDAP_BIND_DN" -w "$LDAP_BIND_PW" <<LDIF
dn: $USER_DN
changetype: modify
add: objectClass
objectClass: totpUser
-
add: totpSecret
totpSecret: $SEED
LDIF

    if [ $? -eq 0 ]; then
        echo "OK: $USERNAME ($MAIL)"
        echo "$USERNAME,$MAIL,$SEED,$QR_URL" >> "$OUTPUT_CSV"
    else
        echo "ERROR: Failed to write seed for $USERNAME"
        # Do not leave a QR image for a seed that was never stored
        rm -f "$QR_DIR/$QR_FILE"
    fi

done

echo ""
echo "Done. Seeds saved to $OUTPUT_CSV"
echo "Users log in with their LDAP account at ${QR_BASE_URL}/qr (one-time download)."
SCRIPT_EOF
sudo chmod 700 /root/bulk-totp-enroll.sh

Set the LDAP admin password with an editor, so it doesn’t end up in your shell history:

bash
sudo vi /root/bulk-totp-enroll.sh

Change LDAP_BIND_PW="CHANGE_ME" to your real password, then save.

13. Test the QR login page

Use testme, which must have a userPassword in LDAP:

bash
sudo qrencode -o /var/lib/totp-qr/testme.png -s 8 -m 2 "otpauth://totp/test?secret=ABC"
sudo chgrp www-data /var/lib/totp-qr/testme.png
sudo chmod 640 /var/lib/totp-qr/testme.png

Open https://idpv5.learn.ac.lk:8443/qr in a browser and log in as testme. The QR image should appear. Reload and log in again, and you should see “No QR code is available for your account.” That confirms the one-time behavior.

You can also test the single-user tool with sudo totp-gen testme, which prints the seed and shows a QR code in the terminal.

14. Run the bulk enrollment

Test with one or two users first, because the script writes seeds into LDAP.

bash
sudo /root/bulk-totp-enroll.sh

The CSV is saved as /root/totp-seeds-<date>.csv. After you’ve sent the instructions to users, delete it:

bash
sudo shred -u /root/totp-seeds-*.csv
15. What to tell users

“Go to https://idpv5.learn.ac.lk:8443/qr, log in with your normal LEARN username and password, and scan the QR code with your authenticator app straight away. It can only be shown once.”

If something fails
Symptom	Check
Timeout in browser	Port 8443 blocked in ufw or an upstream firewall
Certificate warning	Hostname doesn’t match the certificate, or you used the IP address
Name not found	Public DNS record missing
Login box keeps reappearing	Wrong password, or Apache can’t search LDAP. sudo tail -n 30 /var/log/apache2/error.log shows the LDAP error. Try the bind DN lines in step 6
500 error	Run sudo a2enmod cgid and check ls -l /usr/local/lib/totp-qr/qr.cgi shows -rwxr-xr-x
“No QR code is available” on first login	Image missing, or not group www-data: check ls -l /var/lib/totp-qr
Apache won’t start	Port conflict: sudo ss -tlnp | grep -E '443|8443'
Things to know
Login is the only protection. Anyone who knows a user’s password could open the page before the user does. The user would notice, because their image would already be gone. Tell users to enroll promptly.
Failed scans. If a user closes the page before scanning, or doesn’t download within 24 hours, the image is gone. To re-enroll, remove that user’s totpSecret from LDAP and run bulk-totp-enroll.sh again (it skips users who already have a seed).
Brute-force protection. This login page can be used to guess passwords. Consider fail2ban with the apache-auth jail. Tell me if you want that configured.
Rotate the passwords from your pasted history (LDAP admin and MySQL) if that history was ever shared or committed to GitHub.
