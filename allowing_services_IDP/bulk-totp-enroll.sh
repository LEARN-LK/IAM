#!/bin/bash
#
# bulk-totp-enroll.sh
# Generates a TOTP seed for every LDAP user that does not have one yet,
# stores it in LDAP (totpSecret), creates a local QR code PNG with qrencode,
# and writes uid, mail, seed and QR link to a CSV file.
#
# Prerequisites:
#   sudo apt install -y qrencode
#   QR_DIR created and served by Apache (see the manual)

# ---------- Settings ----------
LDAP_HOST="ldap://<URL OF LDAP>"
LDAP_BIND_DN="cn=admin,dc=<YOUR-DOMAIN>,dc=ac,dc=lk"
LDAP_BIND_PW="<LDAP_PASSWORD>"
LDAP_BASE="ou=People,dc=<YOUR-DOMAIN>,dc=ac,dc=lk"
IDP_HOME="/opt/shibboleth-idp"
ISSUER="NAME OF THE IDP"

# Local QR code settings
QR_DIR="/var/www/totp-qr"
QR_BASE_URL="https://<YOUR-IDP-HOSTNAME>:8443"
QR_GROUP="www-data"

# The CSV contains secrets, so make it readable by root only
umask 077
OUTPUT_CSV="/root/totp-seeds-$(date +%Y%m%d-%H%M%S).csv"

# ---------- Pre-flight checks ----------
if ! command -v qrencode >/dev/null 2>&1; then
    echo "ERROR: qrencode is not installed. Run: sudo apt install -y qrencode"
    exit 1
fi

if [ ! -d "$QR_DIR" ]; then
    echo "ERROR: QR directory $QR_DIR does not exist."
    exit 1
fi

echo "uid,mail,seed,qr_url" > "$OUTPUT_CSV"

# ---------- Main ----------
USERNAMES=$(ldapsearch -H "$LDAP_HOST" -x \
  -D "$LDAP_BIND_DN" -w "$LDAP_BIND_PW" \
  -b "$LDAP_BASE" "(uid=*)" uid \
  | grep "^uid:" | awk '{print $2}')

for USERNAME in $USERNAMES; do
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

    # Generate a local QR PNG with an unguessable filename
    RAND=$(openssl rand -hex 16)
    QR_FILE="${USERNAME}-${RAND}.png"
    if ! qrencode -o "$QR_DIR/$QR_FILE" -s 8 -m 2 -l M "$OTP_URL"; then
        echo "ERROR: Could not generate QR code for $USERNAME"
        continue
    fi
    chgrp "$QR_GROUP" "$QR_DIR/$QR_FILE"
    chmod 640 "$QR_DIR/$QR_FILE"
    QR_URL="${QR_BASE_URL}/${QR_FILE}"

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
echo "QR images are in $QR_DIR. Delete them after enrollment (see cleanup cron job)."
