#### IN YOUR INSTITUTIONAL IDP

if you are using Active Directory instead of LDAP, please use the following steps

Modify the lines in ldap.properties file as follows

```
idp.authn.LDAP.baseDN                           = dc=YOUR-DOMAIN,dc=ac,dc=lk
idp.authn.LDAP.userFilter                       = (sAMAccountName={user})
idp.authn.LDAP.bindDN                           = CN=Administrator,CN=Users,DC=YOUR-DOMAIN,DC=ac,DC=lk
idp.authn.LDAP.dnFormat                         = %s@YOUR-DOMAIN.ac.lk
idp.attribute.resolver.LDAP.searchFilter = (sAMAccountName=$resolutionContext.principal)
idp.authn.LDAP.subtreeSearch                   = true
```

Modify the lines as in attribute-resolver.xml file

```
    <AttributeDefinition id="uid" xsi:type="Simple">
            <InputDataConnector ref="ldap" attributeNames="sAMAccountName" />
    </AttributeDefinition>

    <AttributeDefinition scope="%{idp.scope}" xsi:type="Scoped" id="eduPersonPrincipalName">
        <InputDataConnector ref="ldap" attributeNames="sAMAccountName"/>
    </AttributeDefinition>

```

#### IN YOUR INSTITUTIONAL EDUROAM SERVER

Authenticate AD users from FreeRADIUS

1.	You must use winbind + ntlm_auth (MSCHAPv2) for Active Directory authentication.
2.	This is the standard and recommended method.

Install winbind & join Linux to AD domain

```
apt install samba winbind libpam-winbind libnss-winbind
```

Configure /etc/samba/smb.conf:

```
[global] 
workgroup = RUH 
security = ads 
realm = YOUR-DOMAIN.AC.LK
```

Join AD:
```
net ads join -U administrator
systemctl restart winbind
```
Test: 

`wbinfo -u`

If you get follwing errors,

```
server# net ads join -U administrator
Password for [LEARN\administrator]:
Failed to join domain: failed to lookup DC info for domain 'LEARN' over rpc: {Operation Failed} The requested operation was unsuccessful.
````
Follow below steps:

```
apt install ntpdate
```
Edit the resolv file `vim /etc/resolv.conf `

`nameserver 192.248.48.50`

Edit hosts file `vim /etc/hosts`
`192.248.xx.xx ad.YOUR-DOMAIN.ac.lk AD`
```
ntpdate 192.248.xx.xx
net ads join -U administrator
pw – <pass>
```

Verify domain join
```
wbinfo -t    # should return: "trust secret ok"
wbinfo -u    # list domain users
wbinfo -g    # list domain groups
```

Enable ntlm_auth in FreeRADIUS

```
/etc/freeradius/mods-available/mschap
Ensure this is uncommented:
ntlm_auth = "/usr/bin/ntlm_auth --request-nt-key --domain=RUH --username=%{%{Stripped-User-Name}:-%{User-Name}} --password=%{User-Password} --challenge=%{%{mschap:Challenge}:-00}  --nt-response=%{%{mschap:NT-Response}:-00}"
```

Enable module:
```
ln -s /etc/freeradius/3.0/mods-available/mschap /etc/freeradius/3.0/mods-enabled/
```
Restart FreeRADIUS:
```
systemctl restart freeradius
```
After, check the authentication for a test user.


