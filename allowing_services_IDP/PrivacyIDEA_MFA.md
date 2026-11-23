# privacyIDEA 3 Installation on Ubuntu 24.04

Step-by-step manual for installing a privacyIDEA authentication server (Apache + MariaDB/MySQL) and preparing it as the second factor for a Shibboleth IdP v5. It is a companion to the LEARN-LK IdP v5 installation guide.

Based on the official privacyIDEA documentation (Ubuntu packages, First Steps, User ID Resolvers) and the privacyIDEA Shibboleth plugin README. Always check the official docs for the version you install: https://privacyidea.readthedocs.io

## 0. Overview

privacyIDEA is a separate service. The Shibboleth IdP keeps checking the username and password against LDAP, and then asks privacyIDEA to check the one-time code, push approval or passkey.

```
User -> Service Provider -> Shibboleth IdP --(1st Flow) password--> LDAP
                                  |
                                  +--(2nd Flow) OTP/push/passkey--> privacyIDEA --(user lookup)--> LDAP
```

- Run privacyIDEA on its own server (VM), not on the IdP server.
- Example hostname used below: **pi.YOUR-DOMAIN.ac.lk**. Replace it everywhere.
- The official Ubuntu repository supports Ubuntu 22.04, 24.04 and 26.04 LTS. This manual uses 24.04 (noble).

## 1. Prerequisites

- Ubuntu 24.04 LTS server, minimum 2 vCPU, 2 GB RAM, 20 GB disk (more RAM for large user bases).
- A DNS name for the server and a valid TLS certificate (Let's Encrypt is fine).
- Firewall: inbound 443/tcp from the IdP and from admin networks; 80/tcp only while issuing certificates; outbound to your LDAP server (389 or 636).
- Accurate time on the server. TOTP codes depend on it.
- A read-only LDAP bind account for privacyIDEA (for example `cn=privacyidea,ou=services,dc=YOUR-DOMAIN,dc=ac,dc=lk`).
- Note: the privacyidea-apache2 package assumes this server only runs privacyIDEA. It deactivates other default Apache websites.

## 2. System preparation

Run everything as root (`sudo -i`).

```
apt update && apt upgrade -y
apt install -y wget gnupg2 ca-certificates software-properties-common chrony ufw
hostnamectl set-hostname pi.YOUR-DOMAIN.ac.lk
echo "127.0.1.1  pi.YOUR-DOMAIN.ac.lk" >> /etc/hosts
systemctl enable --now chrony
timedatectl
```

Expected: `System clock synchronized: yes`.

## 3. Add the NetKnights package repository

The packages are digitally signed. Download the signing key and verify its fingerprint before trusting it.

```
cd /root
wget https://lancelot.netknights.it/NetKnights-Release.asc
gpg --import --import-options show-only --with-fingerprint NetKnights-Release.asc
```

The output must show `NetKnights GmbH <release@netknights.it>` with this fingerprint (spacing may differ between GnuPG versions):

```
0940 4ABB EDB3 586D EDE4  AD22 00F7 0D62 AE25 0082
```

Do not continue if the fingerprint is different. If it matches:

```
mv NetKnights-Release.asc /etc/apt/trusted.gpg.d/
add-apt-repository http://lancelot.netknights.it/community/noble/stable
```

Alternative to `add-apt-repository`: create `/etc/apt/sources.list.d/privacyidea-community.list` containing:

```
deb http://lancelot.netknights.it/community/noble/stable noble main
```

## 4. Install privacyIDEA

```
apt update
apt install -y privacyidea-apache2
```

- The meta package installs privacyIDEA with Apache2 and also installs the cron jobs that clean up the database.
- If you prefer nginx, install `privacyidea-nginx` instead. If you want to use your own existing web server, install only the `privacyidea` package and integrate it yourself.
- During installation you may be asked questions about the database (for example whether to configure it automatically and which password to use). Choose automatic configuration and store the passwords in your password manager. The exact prompts can differ between versions.

Check the result:

```
apt policy privacyidea | head -5
systemctl status apache2 --no-pager
systemctl status mariadb --no-pager || systemctl status mysql --no-pager
```

Note the installed privacyIDEA version. Some Shibboleth plugin features (token selection, remember device) need privacyIDEA 3.14 or newer.

## 5. Create the first administrator

privacyIDEA does not come with a predefined administrator. Create one:

```
pi-manage admin add admin -e admin@YOUR-DOMAIN.ac.lk
```

It asks for a password. Use a strong, unique password.

## 6. First login and HTTPS certificate

Open `https://pi.YOUR-DOMAIN.ac.lk` in a browser and log in as the administrator. Until you install a real certificate the browser will warn about the default certificate.

### 6.1 Get a Let's Encrypt certificate

```
apt install -y certbot
certbot certonly --standalone -d pi.YOUR-DOMAIN.ac.lk --agree-tos --email admin@YOUR-DOMAIN.ac.lk --no-eff-email --pre-hook "systemctl stop apache2" --post-hook "systemctl start apache2"
```

The pre/post hooks free port 80 for certbot and are saved for automatic renewals.

### 6.2 Use the certificate in Apache

Edit the privacyIDEA site and point the two certificate lines to the new files:

```
vi /etc/apache2/sites-available/privacyidea.conf
```

```
SSLCertificateFile    /etc/letsencrypt/live/pi.YOUR-DOMAIN.ac.lk/fullchain.pem
SSLCertificateKeyFile /etc/letsencrypt/live/pi.YOUR-DOMAIN.ac.lk/privkey.pem
```

```
apache2ctl configtest
systemctl reload apache2
```

Check the existing certificate lines in the file first; only change those two directives.

### 6.3 Reload Apache after renewals

```
cat > /etc/letsencrypt/renewal-hooks/deploy/reload-apache.sh << 'EOF'
#!/bin/bash
systemctl reload apache2
EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-apache.sh
certbot renew --dry-run
```

## 7. Firewall and basic hardening

```
ufw allow OpenSSH
ufw allow 443/tcp
ufw allow 80/tcp     # optional, only needed for certificate issuing
ufw enable
ufw status
```

- Restrict 443 to the IdP and admin networks if possible (`ufw allow from <IdP-IP> to any port 443 proto tcp`).
- Keep the server patched: `apt update && apt upgrade`.
- Never expose the MariaDB/MySQL port to the network.

## 8. Connect your LDAP directory (resolver and realm)

privacyIDEA does not store users. It reads them from your LDAP through a **User ID Resolver**. One or more resolvers are grouped into a **realm**. The first realm you create becomes the default realm.

### 8.1 Copy the LDAP CA certificate (if you use LDAPS or STARTTLS)

From your LDAP server, copy the CA certificate (base64/PEM) to the privacyIDEA server:

```
cp ldap-ca.crt /etc/privacyidea/ldap-ca.crt
systemctl restart apache2
```

If the field in the resolver is left empty, privacyIDEA uses `/etc/privacyidea/ldap-ca.crt` when that file exists at server start, otherwise the system certificate store. A file added later is only used after a restart.

### 8.2 Create the LDAP resolver

In the web UI go to **Users > Resolvers > New Resolver**, choose type **LDAP**, and fill in (OpenLDAP example):

- Resolver name: `learn_ldap`
- Server URI: `ldaps://ldap.YOUR-DOMAIN.ac.lk:636` (a comma-separated list gives a server pool)
- Verify TLS certificate: enabled (leave it on in production)
- Bind type: Simple
- Bind DN: `cn=privacyidea,ou=services,dc=YOUR-DOMAIN,dc=ac,dc=lk`
- Bind password: the service account password
- Base DN: `ou=people,dc=YOUR-DOMAIN,dc=ac,dc=lk`
- Loginname attribute: `uid` (must match the attribute your IdP uses to log users in)
- Search filter: `(&(uid=*)(objectClass=inetOrgPerson))`
- UID type: `entryUUID` for OpenLDAP (`objectGUID` for Active Directory, `ipaUniqueID` for FreeIPA). These names are case sensitive.
- Attribute mapping:

```
{ "phone": "telephoneNumber", "mobile": "mobile", "email": "mail", "surname": "sn", "givenname": "givenName" }
```

For Active Directory use loginname `sAMAccountName` (optionally also `userPrincipalName`), and tick *No anonymous referral chasing* if you get referral errors.

Click **Test Connection** first, then **Save**.

### 8.3 Create the realm

1. Go to **Users > Realms**.
2. Enter a realm name, for example `learn`.
3. Select the resolver `learn_ldap` and set its priority to 1.
4. Click **Create**.
5. Open **Users > Overview** and confirm your LDAP users are listed.

## 9. Enroll a first token and test

1. In the web UI go to **Tokens > Enroll Token**.
2. Choose type **TOTP**, assign it to a test user (realm `learn`) and click **Enroll Token**.
3. Scan the QR code with an authenticator app (FreeOTP, Aegis, Google Authenticator and others).

Test the validation API from the command line:

```
curl -s -d "user=TESTUSER" -d "realm=learn" -d "pass=123456" https://pi.YOUR-DOMAIN.ac.lk/validate/check
```

Replace `123456` with the current code. A successful answer contains `"value": true`.

Note: if the token has a PIN, the user must enter PIN followed by the OTP. Because the IdP already checks the LDAP password, many sites enroll tokens without a PIN. The `otppin` policy options are described in the privacyIDEA documentation.

## 10. Prepare privacyIDEA for the Shibboleth plugin

The default authentication flow of the plugin (`privacyidea.authentication_flow = default`) needs only the server URL. The `triggerChallenge` and `tokenSelection` flows (push, WebAuthn, token lists) also need a service account.

### 10.1 Create a service account (only for triggerChallenge or tokenSelection)

```
pi-manage admin add shibboleth-svc -e idp@YOUR-DOMAIN.ac.lk
```

Then create an **Admin** scope policy for it in **Config > Policies**, allowing only what the plugin needs: `triggerchallenge` and, for tokenSelection, `tokenlist`.

Important: once any admin policy exists, administrators that are not covered by a policy can lose their rights. Before creating the service-account policy, create a policy for your own administrator that grants all admin rights, and confirm you can still administer the system. Read the admin policy chapter of the documentation first.

### 10.2 Optional policies

- Token enrollment during login (enroll via multichallenge), passkey and push options: see the Authentication policies in the documentation and the plugin README.
- Remember device: needs privacyIDEA 3.14+, a `remember_device` policy and an API key for the plugin client.

## 11. Values for the Shibboleth IdP

On the IdP server, in `/opt/shibboleth-idp/conf/authn/privacyidea.properties`:

```
privacyidea.server_url = https://pi.YOUR-DOMAIN.ac.lk
privacyidea.realm = learn
privacyidea.verify_ssl = true
privacyidea.authentication_flow = default
```

- Only add `privacyidea.service_name` and `privacyidea.service_pass` (and `service_realm` if needed) when you use `triggerChallenge` or `tokenSelection`.
- With `verify_ssl = true` the IdP must trust the privacyIDEA certificate. A Let's Encrypt certificate works without extra steps. For an internal CA, import the CA into the Java trust store used by the IdP.
- Make sure the IdP server can reach `https://pi.YOUR-DOMAIN.ac.lk` on port 443.

The remaining IdP steps (module, plugin install, MFA flow, authn.properties) are in the companion Shibboleth MFA section.

## 12. Operations

### Backups

Back up regularly, and test restores:

- The database (the tokens live here).
- `/etc/privacyidea/` (contains `pi.cfg` and the encryption key file). **Without the encryption key the token secrets in the database cannot be decrypted.** Store a copy of it securely, separate from the database backup.
- The `pi-manage` tool also has a backup command (see `pi-manage --help`).

### Updates

```
apt update && apt upgrade
```

Read the Upgrading chapter and the READ BEFORE UPDATE notes of the release first. If apt asks whether to replace `/etc/privacyidea/pi.cfg`, keep your existing file unless the release notes say otherwise.

### Logs

- privacyIDEA: `/var/log/privacyidea/privacyidea.log`
- Apache: `/var/log/apache2/`
- Audit log: in the web UI under **Audit**.

### Monitoring

Monitor the HTTPS endpoint and disk space. If privacyIDEA is down, MFA logins fail. For high availability, plan a second node with a shared or replicated database.

## 13. Troubleshooting

- **Web UI not reachable:** check `systemctl status apache2`, `apache2ctl configtest`, `ufw status`, and DNS.
- **Certificate errors from the IdP:** run `curl -v https://pi.YOUR-DOMAIN.ac.lk/` on the IdP server and check the chain; fix the certificate or the Java trust store.
- **Users not found:** use Test Connection in the resolver; check Base DN, search filter and loginname attribute; for LDAPS check the CA file and restart Apache.
- **OTP always rejected:** check server and phone time (chrony), whether the token has a PIN, and the Audit log entry for the failed request.
- **LDAP changes not noticed:** the user cache (if enabled) keeps login-to-ID associations for the configured timeout.
- **Admin cannot do anything after creating a policy:** see the warning in section 10.1; use the web UI audit log or `pi-manage` from the shell to recover by correcting the policy.
- **IdP errors:** enable `privacyidea.debug = true` on the IdP and check `/opt/shibboleth-idp/logs/idp-process.log`.

## Quick reference

- Web UI: `https://pi.YOUR-DOMAIN.ac.lk`
- Config: `/etc/privacyidea/pi.cfg`
- Apache site: `/etc/apache2/sites-available/privacyidea.conf`
- LDAP CA file: `/etc/privacyidea/ldap-ca.crt`
- Log: `/var/log/privacyidea/privacyidea.log`
- Create admin: `pi-manage admin add <name> -e <email>`
- Validation API: `POST /validate/check`
- Official docs: https://privacyidea.readthedocs.io/en/latest/installation/ubuntu.html
