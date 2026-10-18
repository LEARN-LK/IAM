#!/bin/bash

LDAP_HOST="ldap://<URL OF LDAP>"
LDAP_BIND_DN="cn=admin,dc=<YOUR-DOMAIN>,dc=ac,dc=lk"
LDAP_BIND_PW="<LDAP_PASSWORD>"
LDAP_BASE="ou=People,dc=learn,dc=ac,dc=lk"
IDP_HOME="/opt/shibboleth-idp"
ISSUER="NAME OF THE IDP"
OUTPUT_CSV="/root/totp-seeds-$(date +%Y%m%d-%H%M%S).csv"

echo "uid,mail,seed,qr_url" > "$OUTPUT_CSV"

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

    if [ -z "$SEED" ]; then
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

    # Build a browser-loadable QR code URL
    # URL-encode the otpauth:// URI for use in the QR API
    ENCODED_OTP=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$OTP_URL', safe=''))")
    QR_URL="https://api.qrserver.com/v1/create-qr-code/?data=${ENCODED_OTP}&size=300x300&ecc=M&margin=10"

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
    fi

done

echo ""
echo "Done. Seeds saved to $OUTPUT_CSV"
