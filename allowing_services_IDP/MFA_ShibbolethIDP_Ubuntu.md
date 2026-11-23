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

The LDAP attribute must contain the plain Base32-encoded seed (not encrypted). For encrypted seeds, see the DataSealer section in the official plugin docs.

#### Clock Sync Check (Important for TOTP)

TOTP codes are time-based. If the server clock drifts, codes will fail.

Check current NTP sync status

```
timedatectl status
```

If it is not in Asia/Colombo timezone, use
```
sudo timedatectl set-timezone Asia/Colombo
timedatectl status
```

#### Configure authentication properties

 Edit conf/authn/authn.properties

 ```
 vi /opt/shibboleth-idp/conf/authn/authn.properties
```

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
Edit 
```
vi /opt/shibboleth-idp/conf/relying-party.xml
```

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


 ### Do following modification on your LDAP server:

Step 1 — Create the Custom Schema File

```
vi /root/totp-schema.ldif
```

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

### when we are going to create QR code for user profile adding to TOTP app

Default QR generation uses api.qrserver.com by the plugin and since it is a third party for the system, let's install a local qr server for a safer approach

1. Install packages

```
sudo apt update
sudo apt install -y qrencode apache2 libaprutil1-ldap ldap-utils
```
2. Create Directories

```
# QR images (outside the web root, never served directly)
sudo mkdir -p /var/lib/totp-qr
sudo chown root:www-data /var/lib/totp-qr
sudo chmod 770 /var/lib/totp-qr

# Empty web root for the QR site
sudo mkdir -p /var/www/totp-empty

# CGI script folder
sudo mkdir -p /usr/local/lib/totp-qr
```
3. Enable the Apache2 modules

```
sudo a2enmod ssl cgid ldap authnz_ldap session_cookie session_crypto auth_form request
sudo a2dissite 000-default   # not needed unless you use port 80 for something else
```

4. Check whether Apache can load LDAP

```
ldapsearch -x -H ldap://localhost -b "ou=people,dc=<YOUR-DOMAIN>,dc=ac,dc=lk" "(uid=<UID>)" uid
```
This must return the testme entry. If it returns nothing or “insufficient access”, anonymous search is blocked, and you need to uncomment the bind DN lines in step 7

5. Check that port 8443 is free

```
sudo ss -tlnp | grep 8443
```

This must print nothing. The IdP’s Jetty sometimes uses 8443. If it is taken, pick another port and use it everywhere below (Listen, <VirtualHost>, QR_BASE_URL, ufw)

6. Create CGI script

`REMOTE_USER` is set by Apache after the LDAP login. The script enforces the 2-view limit and the 24-hour expiry, and it serializes requests with a lock so the counter can’t be bypassed by parallel requests.

```
sudo tee /usr/local/lib/totp-qr/qr.cgi > /dev/null <<'EOF'
#!/bin/bash
# Serves the logged-in user's own QR image.
# Max MAX_VIEWS successful loads, and never after MAX_AGE seconds.
QR_DIR="/var/lib/totp-qr"
MAX_VIEWS=2
MAX_AGE=86400

deny() {
    echo "Status: 404 Not Found"
    echo "Content-Type: text/plain"
    echo "Cache-Control: no-store"
    echo ""
    echo "No QR code is available for your account. It may have expired or already been viewed the maximum number of times. Contact the administrator."
    exit 0
}

USER_NAME=$(printf '%s' "$REMOTE_USER" | sed -n 's/^\([A-Za-z0-9._@-]\{1,64\}\)$/\1/p')
[ "$REQUEST_METHOD" = "GET" ] || deny
[ -n "$USER_NAME" ] || deny
[[ "$USER_NAME" != *..* ]] || deny

FILE="$QR_DIR/$USER_NAME.png"
COUNT="$QR_DIR/$USER_NAME.views"

# One request at a time, so the counter cannot be raced
exec 9>>"$QR_DIR/.lock"
flock 9

[ -f "$FILE" ] || { rm -f "$COUNT"; deny; }

AGE=$(( $(date +%s) - $(stat -c %Y "$FILE") ))
if [ "$AGE" -gt "$MAX_AGE" ]; then
    rm -f "$FILE" "$COUNT"
    deny
fi

VIEWS=$(cat "$COUNT" 2>/dev/null)
VIEWS=${VIEWS//[^0-9]/}
VIEWS=$(( ${VIEWS:-0} + 1 ))

TMP=$(mktemp "$QR_DIR/.tmp.XXXXXX") || deny
trap 'rm -f "$TMP"' EXIT
cp "$FILE" "$TMP" || deny

if [ "$VIEWS" -ge "$MAX_VIEWS" ]; then
    rm -f "$FILE" "$COUNT"      # last allowed view: remove now
else
    echo "$VIEWS" > "$COUNT"
fi
flock -u 9

echo "Content-Type: image/png"
echo "Cache-Control: no-store"
echo ""
cat "$TMP"
EOF
sudo chmod 755 /usr/local/lib/totp-qr/qr.cgi
```

7. Create the Apache site with LDAP login

First check the certificate folder name with ls `/etc/letsencrypt/live/`. If it isn’t idpv5.learn.ac.lk, change the two SSLCertificate lines.

```
sudo tee /etc/apache2/sites-available/totp-qr.conf > /dev/null <<'EOF'
Listen 8443
<VirtualHost *:8443>
    ServerName idpv5.YOUR-DOMAIN.ac.lk
    DocumentRoot /var/www/totp-empty

    SSLEngine on
    SSLProtocol -all +TLSv1.2 +TLSv1.3
    SSLCertificateFile    /etc/letsencrypt/live/idpv5.YOUR-DOMAIN.ac.lk/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/idpv5.YOUR-DOMAIN.ac.lk/privkey.pem

    ScriptAlias /qr /usr/local/lib/totp-qr/qr.cgi

    # ---- Session settings (shared by the login handler and the QR page) ----
    Session On
    SessionCookieName session path=/;httponly;secure;samesite=strict
    # Generate with: openssl rand -base64 32
    SessionCryptoPassphrase "CHANGE-ME-LONG-RANDOM-STRING"
    SessionMaxAge 600

    # ---- Public area: the login page itself ----
    <Directory /var/www/totp-empty>
        Options -Indexes
        Require all granted
    </Directory>

    # ---- Login form target (the form on login.html posts here) ----
    <Location "/dologin">
        SetHandler form-login-handler
        AuthType form
        AuthName "LEARN account login (to get your MFA QR code)"
        AuthFormProvider ldap
        AuthLDAPURL "ldap://localhost:389/ou=people,dc=YOUR-DOMAIN,dc=ac,dc=lk?uid?sub?(objectClass=*)"
        AuthLDAPRemoteUserAttribute uid
        AuthLDAPBindDN "cn=admin,dc=YOUR-DOMAIN,dc=ac,dc=lk"
        AuthLDAPBindPassword "LDAP_PASSWORD"
        # Wrong password -> back to the login page with an error message
        AuthFormLoginRequiredLocation "/login.html?error=1"
        # Fallback if the form does not supply httpd_location
        AuthFormLoginSuccessLocation "/qr"
    </Location>

    # ---- Protected QR code script ----
    <Directory /usr/local/lib/totp-qr>
        Options +ExecCGI

        AuthType form
        AuthName "LEARN account login (to get your MFA QR code)"
        AuthFormProvider ldap
        AuthLDAPURL "ldap://localhost:389/ou=people,dc=YOUR-DOMAIN,dc=ac,dc=lk?uid?sub?(objectClass=*)"
        AuthLDAPRemoteUserAttribute uid
        AuthLDAPBindDN "cn=admin,dc=YOUR-DOMAIN,dc=ac,dc=lk"
        AuthLDAPBindPassword "LDAP_PASSWORD"
        # Not logged in (or session expired) -> show the login page
        AuthFormLoginRequiredLocation "/login.html"
        Require valid-user
    </Directory>
</VirtualHost>
EOF
```
If you add the bind password, protect the file:
```
sudo chmod 640 /etc/apache2/sites-available/totp-qr.conf
```
Then create login.html file for user to login
```
vi /var/www/totp-empty/login.html
```
```
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Set up two-step verification</title>
<style>
  :root {
    --bg: #f3f6f9;
    --panel: #ffffff;
    --ink: #14263a;
    --muted: #5b6b7c;
    --line: #d5dde6;
    --brand: #0d4f8b;
    --brand-dark: #093a68;
    --side: #0d2a47;
    --side-ink: #e8eef5;
    --err: #a4262c;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #0c1622;
      --panel: #132233;
      --ink: #e8eef5;
      --muted: #9fb0c2;
      --line: #27394d;
      --brand: #4b9ae0;
      --brand-dark: #6cb0ee;
      --side: #091420;
      --side-ink: #e8eef5;
      --err: #ff8a8f;
    }
  }
  * { box-sizing: border-box; }
  html, body { height: 100%; margin: 0; }
  body {
    font-family: "Segoe UI", system-ui, -apple-system, "Helvetica Neue", Arial, sans-serif;
    background: var(--bg);
    color: var(--ink);
    display: grid;
    place-items: center;
    padding: 24px;
  }
  .card {
    width: 100%;
    max-width: 880px;
    display: grid;
    grid-template-columns: 1fr 1fr;
    background: var(--panel);
    border: 1px solid var(--line);
    border-radius: 10px;
    overflow: hidden;
  }

  .side {
    background: var(--side);
    color: var(--side-ink);
    padding: 40px 36px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    gap: 32px;
  }
  .org { font-size: 15px; font-weight: 600; letter-spacing: .01em; }
  .side h1 { font-size: 26px; line-height: 1.25; margin: 0 0 14px; font-weight: 600; }
  .side p { margin: 0 0 22px; line-height: 1.55; font-size: 15px; opacity: .88; }
  .steps { margin: 0; padding: 0; list-style: none; display: grid; gap: 12px; font-size: 14px; }
  .steps li { display: flex; gap: 12px; align-items: baseline; }
  .steps b {
    flex: none; width: 22px; height: 22px; border-radius: 50%;
    background: rgba(255,255,255,.16); display: grid; place-items: center;
    font-size: 12px; font-weight: 600;
  }
  .form { padding: 40px 36px; display: flex; flex-direction: column; justify-content: center; }
  .form h2 { margin: 0 0 6px; font-size: 20px; font-weight: 600; }
  .form .sub { margin: 0 0 24px; color: var(--muted); font-size: 14px; line-height: 1.5; }
  label { display: block; font-size: 14px; font-weight: 600; margin-bottom: 6px; }
  input[type=text], input[type=password] {
    width: 100%; font: inherit; font-size: 15px; padding: 11px 12px;
    border: 1px solid var(--line); border-radius: 6px;
    background: var(--panel); color: var(--ink); margin-bottom: 18px;
  }
  input:focus-visible, button:focus-visible {
    outline: 3px solid var(--brand); outline-offset: 1px; border-color: var(--brand);
  }
  button {
    width: 100%; font: inherit; font-size: 15px; font-weight: 600;
    padding: 12px; border: 0; border-radius: 6px; cursor: pointer;
    background: var(--brand); color: #fff;
  }
  button:hover { background: var(--brand-dark); }
  .error {
    display: none; margin: 0 0 18px; padding: 10px 12px; font-size: 14px;
    border: 1px solid var(--err); color: var(--err); border-radius: 6px;
  }
  .error.show { display: block; }
  .note { margin: 20px 0 0; font-size: 13px; color: var(--muted); line-height: 1.5; }
  @media (max-width: 720px) {
    .card { grid-template-columns: 1fr; }
    .side { padding: 28px 24px; }
    .form { padding: 28px 24px; }
  }
</style>
</head>
<body>
  <main class="card">
    <section class="side">
      <div class="org">Lanka Education And Research Network - Sri Lanka</div>
      <div>
        <h1>Set up two-step verification</h1>
        <p>Two-step verification protects your account even if your password is stolen. Setup takes about two minutes.</p>
        <ol class="steps">
          <li><b>1</b><span>Sign in with your usual university username and password</span></li>
          <li><b>2</b><span>Scan the QR code with an authenticator app</span></li>
          <li><b>3</b><span>Enter the 6-digit code to confirm</span></li>
        </ol>
      </div>
    </section>

    <section class="form">
      <h2>Sign in to continue</h2>
      <p class="sub">Use the same account you use for email and Wi-Fi. This page is only used to show your setup QR code.</p>

      <p class="error" id="err" role="alert">The username or password was not correct. Please try again.</p>

      <form method="post" action="/dologin">
        <label for="u">Username</label>
        <input id="u" name="httpd_username" type="text" autocomplete="username" autocapitalize="none" spellcheck="false" required autofocus>

        <label for="p">Password</label>
        <input id="p" name="httpd_password" type="password" autocomplete="current-password" required>

        <input type="hidden" name="httpd_location" value="/qr">
        <button type="submit">Sign in</button>
      </form>

      <p class="note">Your password is sent securely to your institution only. We never ask for it by email. Need help? Contact TAC - LEARN : tac@learn.ac.lk.</p>
    </section>
  </main>

  <script>
    if (location.search.indexOf("error=1") !== -1) {
      document.getElementById("err").classList.add("show");
    }
  </script>
</body>
</html>

```


```
 chmod 644 /var/www/totp-empty/login.html
```
8. Enable the site and start Apache
```
sudo a2ensite totp-qr
sudo apachectl configtest
sudo systemctl restart apache2
sudo ss -tlnp | grep 8443
```

9. Firewall and DNS
   
```
sudo ufw allow 8443/tcp
dig +short idpv5.<YOUR-DOMAIN>.ac.lk @8.8.8.8
```
dig must return your server’s public IP. Also open TCP 8443 in any upstream or hosting firewall.

10. Reload Apache after certificate renewals

```
sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-apache.sh > /dev/null <<'EOF'
#!/bin/bash
systemctl reload apache2
EOF
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-apache.sh
```
11. Cleanup job for images nobody fetched

```
sudo tee /etc/cron.d/totp-qr-cleanup > /dev/null <<'EOF'
*/30 * * * * root find /var/lib/totp-qr -type f \( -name "*.png" -o -name "*.views" -o -name ".tmp.*" \) -mmin +1440 -delete
EOF
```
The CGI also refuses files older than 24 hours on its own, so the cron job is just for housekeeping.

12. Create the shared settings and the LDAP password file

The password goes in a root-only file, so it never appears in shell history or in ps.

```
sudo tee /etc/totp-enroll.conf > /dev/null <<'EOF'
LDAP_HOST="ldap://localhost"
LDAP_BIND_DN="cn=admin,dc=<YOUR-DOMAIN>,dc=ac,dc=lk"
LDAP_PW_FILE="/root/.ldap-admin-pw"
LDAP_BASE="ou=People,dc=<YOUR-DOMAIN>,dc=ac,dc=lk"
IDP_HOME="/opt/shibboleth-idp"
ISSUER="LEARN IdP"
QR_DIR="/var/lib/totp-qr"
QR_GROUP="www-data"
QR_BASE_URL="https://idpv5.YOUR-DOMAIN.ac.lk:8443"
EOF
sudo chmod 600 /etc/totp-enroll.conf

sudo bash -c 'umask 077; read -rsp "LDAP admin password: " p; echo; printf "%s" "$p" > /root/.ldap-admin-pw'
```

13. Create the enrollment tool (totp-gen)

For one user, this does everything in order:
       i.   Generates the seed.
       ii.  Creates the QR PNG.
       iii. Stores the seed in LDAP.
       iv.  Prints the QR in the terminal.

If the LDAP write fails, the PNG is removed.

```
sudo tee /usr/local/bin/totp-gen > /dev/null <<'SCRIPT_EOF'
#!/bin/bash
# Usage: totp-gen <username> [--quiet] [--force]
#   --quiet  do not print the QR in the terminal
#   --force  replace an existing seed (re-enrollment)
# Exit codes: 0 ok, 1 error, 2 skipped (already has a seed)

CONF=/etc/totp-enroll.conf
[ -r "$CONF" ] || { echo "ERROR: cannot read $CONF"; exit 1; }
. "$CONF"
umask 077

USERNAME="$1"; shift
QUIET=0; FORCE=0
for a in "$@"; do
    case "$a" in --quiet) QUIET=1;; --force) FORCE=1;; esac
done

[ -n "$USERNAME" ] || { echo "Usage: $0 <username> [--quiet] [--force]"; exit 1; }
if ! [[ "$USERNAME" =~ ^[A-Za-z0-9._@-]{1,64}$ ]] || [[ "$USERNAME" == *..* ]]; then
    echo "ERROR: $USERNAME has characters not supported by the QR login page"; exit 1
fi
command -v qrencode >/dev/null 2>&1 || { echo "ERROR: qrencode not installed"; exit 1; }
[ -d "$QR_DIR" ] || { echo "ERROR: $QR_DIR does not exist"; exit 1; }
[ -r "$LDAP_PW_FILE" ] || { echo "ERROR: cannot read $LDAP_PW_FILE"; exit 1; }

LDAP_OPTS=(-H "$LDAP_HOST" -x -D "$LDAP_BIND_DN" -y "$LDAP_PW_FILE")

# Look up the user once
RESULT=$(ldapsearch "${LDAP_OPTS[@]}" -LLL -o ldif-wrap=no -b "$LDAP_BASE" \
         "(uid=$USERNAME)" dn objectClass totpSecret)
USER_DN=$(printf '%s\n' "$RESULT" | sed -n 's/^dn: //p' | head -n1)
[ -n "$USER_DN" ] || { echo "ERROR: $USERNAME not found in LDAP"; exit 1; }
HAS_SECRET=$(printf '%s\n' "$RESULT" | grep -c '^totpSecret:')
HAS_OC=$(printf '%s\n' "$RESULT" | grep -ci '^objectClass: totpUser$')

if [ "$HAS_SECRET" -gt 0 ] && [ "$FORCE" -eq 0 ]; then
    echo "SKIP: $USERNAME already has a seed (use --force to replace it)"
    exit 2
fi

# Generate the seed
OUT=$("$IDP_HOME/bin/totpauth.sh" --home "$IDP_HOME" --issuer "$ISSUER" --account "$USERNAME" 2>/dev/null)
SEED=$(printf '%s\n' "$OUT" | awk '/^Seed:/{print $2}')
OTP_URL=$(printf '%s\n' "$OUT" | awk '/^URL:/{print $2}')
[ -n "$SEED" ] || { echo "ERROR: could not generate seed for $USERNAME"; exit 1; }

# Use the otpauth URI; build it locally if the tool printed anything else
case "$OTP_URL" in
    otpauth://*) ;;
    *) ISSUER_ENC=${ISSUER// /%20}
       OTP_URL="otpauth://totp/${ISSUER_ENC}:${USERNAME}?secret=${SEED}&issuer=${ISSUER_ENC}" ;;
esac

# Create the QR PNG (URL goes via stdin so it is not visible in ps)
QR_FILE="$QR_DIR/$USERNAME.png"
rm -f "$QR_DIR/$USERNAME.views"
if ! printf '%s' "$OTP_URL" | qrencode -o "$QR_FILE" -s 8 -m 2 -l M; then
    echo "ERROR: could not generate QR code for $USERNAME"; exit 1
fi
chgrp "$QR_GROUP" "$QR_FILE"
chmod 640 "$QR_FILE"

# Store the seed in LDAP
{
    echo "dn: $USER_DN"
    echo "changetype: modify"
    if [ "$HAS_OC" -eq 0 ]; then
        echo "add: objectClass"; echo "objectClass: totpUser"; echo "-"
    fi
    if [ "$HAS_SECRET" -gt 0 ]; then echo "replace: totpSecret"; else echo "add: totpSecret"; fi
    echo "totpSecret: $SEED"
} | ldapmodify "${LDAP_OPTS[@]}" >/dev/null

if [ ${PIPESTATUS[1]} -ne 0 ]; then
    echo "ERROR: failed to write seed for $USERNAME to LDAP"
    rm -f "$QR_FILE"     # never leave a QR for a seed that was not stored
    exit 1
fi

echo "OK: $USERNAME enrolled. QR image: $QR_FILE"
echo "User can load ${QR_BASE_URL}/qr (LDAP login) twice within 24 hours."

if [ "$QUIET" -eq 0 ]; then
    echo
    printf '%s' "$OTP_URL" | qrencode -t ANSIUTF8
fi
exit 0
SCRIPT_EOF
sudo chmod 700 /usr/local/bin/totp-gen
```
14. Create the bulk enrollment script

It calls totp-gen for every LDAP user without a seed. The CSV contains only uid, mail and the expiry time. There are no seeds in it.

```
sudo tee /root/bulk-totp-enroll.sh > /dev/null <<'SCRIPT_EOF'
#!/bin/bash
# Enrolls every LDAP user without a seed using totp-gen, then writes a
# CSV (uid, mail, expiry) so you know whom to notify. No secrets in the CSV.

. /etc/totp-enroll.conf
umask 077
OUTPUT_CSV="/root/totp-enrolled-$(date +%Y%m%d-%H%M%S).csv"
echo "uid,mail,qr_expires" > "$OUTPUT_CSV"
EXPIRES=$(date -d '+24 hours' '+%Y-%m-%d %H:%M')

LDAP_OPTS=(-H "$LDAP_HOST" -x -D "$LDAP_BIND_DN" -y "$LDAP_PW_FILE")

USERNAMES=$(ldapsearch "${LDAP_OPTS[@]}" -LLL -o ldif-wrap=no -b "$LDAP_BASE" "(uid=*)" uid \
            | sed -n 's/^uid: //p')
echo "Users found in LDAP: $(echo "$USERNAMES" | grep -c .)"

OK=0; SKIPPED=0; FAILED=0
for USERNAME in $USERNAMES; do
    /usr/local/bin/totp-gen "$USERNAME" --quiet
    case $? in
        0) MAIL=$(ldapsearch "${LDAP_OPTS[@]}" -LLL -o ldif-wrap=no -b "$LDAP_BASE" \
                  "(uid=$USERNAME)" mail | sed -n 's/^mail: //p' | head -n1)
           echo "$USERNAME,${MAIL:-no-mail},$EXPIRES" >> "$OUTPUT_CSV"
           OK=$((OK+1)) ;;
        2) SKIPPED=$((SKIPPED+1)) ;;
        *) FAILED=$((FAILED+1)) ;;
    esac
done

echo
echo "Enrolled: $OK  Skipped (already had seed): $SKIPPED  Failed: $FAILED"
echo "List saved to $OUTPUT_CSV"
echo "Users load ${QR_BASE_URL}/qr (LDAP login), twice at most, within 24 hours."
SCRIPT_EOF
sudo chmod 700 /root/bulk-totp-enroll.sh
```
To generate the seed and QR code for the user, execute in IDP server;
```
sudo totp-gen <UID>
```

15. Test the QR login page

Use `testme`, which must have a `userPassword` in LDAP. This test needs no real seed:

```
sudo qrencode -o /var/lib/totp-qr/testme.png -s 8 -m 2 "otpauth://totp/test?secret=ABC"
sudo chgrp www-data /var/lib/totp-qr/testme.png
sudo chmod 640 /var/lib/totp-qr/testme.png

```
Open `https://idpv5.<YOUR-DOMAIN>.ac.lk:8443/qr and log in as testme:

  i.  First load: the QR image appears.
  ii. Reload: the image appears again (second view).
  iii.Reload again: you should see “No QR code is available for your account.”

Then test the real tool end to end. Note that this writes a seed into LDAP for that account:

```
sudo totp-gen testme --force
```
Scan the terminal QR with a test authenticator app and confirm the code validates at the IdP.

16. Run the bulk enrollment

Test with one or two users first, because the script writes seeds into LDAP.

```
sudo /root/bulk-totp-enroll.sh
```

Check that the “Users found” count matches what you expect. If it is lower, LDAP is probably hitting a search size limit. The CSV has no secrets, but still delete it when you’re done:

```
sudo rm /root/totp-enrolled-*.csv
```

17. What to tell users

`Within 24 hours, open https://idpv5.<YOUR-DOMAIN>.ac.lk:8443/qr on a computer, log in with your normal institutional username and password, and scan the QR code with your authenticator app(Tested on Google Authenticator/Microsoft authenticatot) on your phone straight away. The page can be opened only twice, so don’t refresh it unnecessarily and don’t take a screenshot.`


Things to know
       i.  Login is the only protection. Someone who knows a user’s password could fetch the QR before the user does. The user would notice, because the page would stop working. Enroll in small batches and tell users to act promptly.
       ii. Missed or failed scan: run sudo totp-gen <uid> --force. This replaces the seed and creates a fresh image with a new 24-hour window and a reset view counter.
       iii. Plugin’s own QR page: make sure it is disabled or unreachable, otherwise the api.qrserver.com path still exists. Verify this in your plugin’s configuration.
    
