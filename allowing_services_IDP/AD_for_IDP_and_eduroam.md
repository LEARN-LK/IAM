### IN your IDP, if you are using Active Directory instead of LDAP, please use the following steps

Modify the lines in ldap.properties file as follows

```
idp.authn.LDAP.baseDN                           = dc=YOUR-DOMAIN,dc=ac,dc=lk
idp.authn.LDAP.userFilter                       = (sAMAccountName={user})
idp.authn.LDAP.bindDN                           = CN=Administrator,CN=Users,DC=YOUR-DOMAIN,DC=ac,DC=lk
idp.authn.LDAP.dnFormat                         = %s@YOUR-DOMAIN.ac.lk
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

