# Shibboleth v5 MFA Configuration Guide

## Multi-Factor Authentication with TOTP + Password (LDAP Backend)

## Enabling Multi-Factor Authentication (MFA) in Shibboleth IdP v5 using:

* Primary Factor: LDAP-based password authentication
* Secondary Factor: Time-based One-Time Password (TOTP)
* Database: LDAP for storing user credentials
* System: Ubuntu 24.04 + Shibboleth v5

1. Core MFA Configuration in authn.properties
The MFA module is already partially configured in authn.properties. Here's the complete configuration:

`vi /opt/shibboleth-idp/conf/authn/authn.properties`

Configuration Settings

```
#### MFA - Multi-Factor Authentication ####

# Enable MFA flow
idp.authn.MFA.order = 10

# MFA supports passive authentication
idp.authn.MFA.passiveAuthenticationSupported = true

# MFA supports forced authentication
idp.authn.MFA.forcedAuthenticationSupported = true

# Validate that login transitions are allowed
idp.authn.MFA.validateLoginTransitions = true

# Use the latest timestamp instead of oldest (most recent auth wins)
idp.authn.MFA.useLatestTimestamp = false

# Define supported principals from all MFA factors combined
# These should match the union of all individual factor principals
idp.authn.MFA.supportedPrincipals = \
    saml2/urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport, \
    saml2/urn:oasis:names:tc:SAML:2.0:ac:classes:Password, \
    saml2/urn:oasis:names:tc:SAML:2.0:ac:classes:InternetProtocol, \
    saml1/urn:oasis:names:tc:SAML:1.0:am:password

#### Password Authentication (First Factor) ####

idp.authn.Password.order = 20
idp.authn.Password.passiveAuthenticationSupported = false
idp.authn.Password.nonBrowserSupported = true

# Use LDAP for password validation
idp.authn.Password.ldapURL = ldap://localhost:389

# LDAP DN for binding (service account)
idp.authn.Password.ldapBindDN = cn=admin,dc=example,dc=com

# LDAP bind password
idp.authn.Password.ldapBindPassword = your_ldap_password

# LDAP user DN pattern - adjust based on your LDAP structure
idp.authn.Password.userDNFormat = uid=%s,ou=people,dc=example,dc=com

# Alternative: use subtree search
idp.authn.Password.baseDN = dc=example,dc=com
idp.authn.Password.subtreeSearch = true

# SSL/TLS for LDAP connection (recommended)
# idp.authn.Password.ldapURL = ldaps://localhost:636

idp.authn.Password.supportedPrincipals = \
    saml2/urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport, \
    saml2/urn:oasis:names:tc:SAML:2.0:ac:classes:Password, \
    saml1/urn:oasis:names:tc:SAML:1.0:am:password

#### TOTP Authentication (Second Factor) ####

# Custom TOTP authenticator (requires additional setup)
# idp.authn.TOTP.order = 30
# idp.authn.TOTP.passiveAuthenticationSupported = false
# idp.authn.TOTP.supportedPrincipals = \
#    saml2/urn:oasis:names:tc:SAML:2.0:ac:classes:SoftwareID

#### IP Address Authentication (Optional additional factor) ####

idp.authn.IPAddress.order = 5
idp.authn.IPAddress.passiveAuthenticationSupported = true
idp.authn.IPAddress.nonBrowserSupported = true

idp.authn.IPAddress.supportedPrincipals = \
    saml2/urn:oasis:names:tc:SAML:2.0:ac:classes:InternetProtocol
```

2. Configure MFA Flow in mfa-authn-config.xml

`vi /opt/shibboleth-idp/conf/authn/mfa-authn-config.xml`

Create/Update the File

```
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:util="http://www.springframework.org/schema/util"
       xsi:schemaLocation="http://www.springframework.org/schema/beans
           http://www.springframework.org/schema/beans/spring-beans.xsd
           http://www.springframework.org/schema/util
           http://www.springframework.org/schema/util/spring-util.xsd">

    <!--
    MFA Configuration for Shibboleth v5
    Flows: Password (first) -> TOTP (second)
    -->

    <!-- Define MFA Flow Beans -->
    
    <!-- Default MFA Flow -->
    <bean id="authn/MFA" class="net.shibboleth.idp.authn.impl.MultiFactorAuthenticationFlowDescriptor">
        <property name="id" value="MFA" />
        <property name="principalWeightMap">
            <util:map>
                <!-- Password is primary (weight 10) -->
                <entry key="saml2/urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport" 
                       value="#{T(java.lang.Integer).MAX_VALUE}" />
                <entry key="saml2/urn:oasis:names:tc:SAML:2.0:ac:classes:Password" 
                       value="#{T(java.lang.Integer).MAX_VALUE}" />
                <!-- TOTP is secondary (weight 5) - lower weight, required -->
                <entry key="saml2/urn:oasis:names:tc:SAML:2.0:ac:classes:SoftwareID" 
                       value="5" />
            </util:map>
        </property>
        <!-- Require both factors -->
        <property name="nonBrowserSupported" value="false" />
        <property name="passiveAuthenticationSupported" value="false" />
    </bean>

    <!-- Define required authentication factors -->
    
    <!-- First Factor: Password via LDAP -->
    <util:set id="mfa-authn/required-factors">
        <value>authn/Password</value>
        <!-- Uncomment when TOTP is implemented -->
        <!-- <value>authn/TOTP</value> -->
    </util:set>

    <!-- Define potential factors for optional/additional auth -->
    <util:set id="mfa-authn/optional-factors">
        <value>authn/IPAddress</value>
    </util:set>

    <!-- MFA Flow Order - executed in this sequence -->
    <bean id="mfa-authn/flow-order" class="java.util.ArrayList">
        <constructor-arg>
            <util:list>
                <!-- Step 1: Authenticate with Password (LDAP) -->
                <value>authn/Password</value>
                <!-- Step 2: Authenticate with TOTP (when implemented) -->
                <!-- <value>authn/TOTP</value> -->
            </util:list>
        </constructor-arg>
    </bean>

    <!-- Optional: Define when to trigger MFA (Relying Party specific) -->
    <bean id="mfa-authn/rp-rules" class="java.util.HashMap">
        <!-- Force MFA for specific service providers -->
        <constructor-arg>
            <util:map>
                <!-- Example: Force MFA for sensitive applications -->
                <!-- <entry key="https://sensitive-app.example.org/saml2/metadata" 
                       value="true" /> -->
            </util:map>
        </constructor-arg>
    </bean>

</beans>

```

3. Update authn-events-flow.xml

`vi /opt/shibboleth-idp/conf/authn/authn-events-flow.xml`

Keep the current file as-is or enhance it with custom error handling:

```
<?xml version="1.0" encoding="UTF-8"?>
<flow xmlns="http://www.springframework.org/schema/webflow"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.springframework.org/schema/webflow 
          http://www.springframework.org/schema/webflow/spring-webflow.xsd"
      abstract="true">

    <!-- ADVANCED USE ONLY -->
    
    <!-- Custom error events for MFA flows -->
    <end-state id="InvalidTOTP" />
    <end-state id="TOTPExpired" />
    <end-state id="MFATimeout" />
    
    <!-- Global transitions for error handling -->
    <global-transitions>
        <transition on="InvalidTOTP" to="InvalidTOTP" />
        <transition on="TOTPExpired" to="TOTPExpired" />
        <transition on="MFATimeout" to="MFATimeout" />
        <transition on="#{!'proceed'.equals(currentEvent.id)}" to="InvalidEvent" />
    </global-transitions>

</flow>

```

4. Password Authentication Configuration

`vi /opt/shibboleth-idp/conf/authn/password-authn-config.xml`

Complete Configuration

```
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="http://www.springframework.org/schema/beans 
           http://www.springframework.org/schema/beans/spring-beans.xsd">

    <!--
    Password Authentication Configuration for Shibboleth v5 with LDAP Backend
    -->

    <!-- LDAP Credential Validator -->
    <bean id="shibboleth.authn.Password.Validator"
          class="net.shibboleth.idp.authn.impl.LdapCredentialValidator"
          p:ldapURL="ldap://localhost:389"
          p:bindDN="cn=admin,dc=example,dc=com"
          p:bindPassword="your_ldap_password"
          p:baseDN="dc=example,dc=com"
          p:subtreeSearch="true"
          p:userDNFormat="uid={0},ou=people,dc=example,dc=com"
          p:connectionTimeout="PT5S"
          p:responseTimeout="PT5S"
          p:validatePeriod="PT5M"
          p:validateDN="cn=admin,dc=example,dc=com"
          p:validatePassword="your_ldap_password">
        
        <!-- Connection pooling -->
        <property name="connectionStrategy" ref="shibboleth.pool.ConnectionStrategy" />
    </bean>

    <!-- Username/Password Extractor from Form -->
    <bean id="shibboleth.authn.Password.UsernamePasswordResolver"
          class="net.shibboleth.idp.authn.impl.UsernamePasswordCredentialExtractor"
          p:allowEmptyPasswords="false"
          p:trim="true">
    </bean>

    <!-- Result Lookup Strategy -->
    <bean id="shibboleth.authn.Password.SubjectCanonicalizationFlowSelector"
          class="net.shibboleth.idp.authn.impl.DefaultCanonicalizationFlowSelector"
          p:flows="{'principalName': 'c14n/LDAP'}">
    </bean>

    <!-- Define canonicalization flow if using custom lookup -->
    <bean id="c14n/LDAP"
          class="net.shibboleth.idp.authn.impl.LdapCanonicalizationFlowDescriptor"
          p:ldapURL="ldap://localhost:389"
          p:bindDN="cn=admin,dc=example,dc=com"
          p:bindPassword="your_ldap_password"
          p:baseDN="dc=example,dc=com"
          p:subtreeSearch="true"
          p:userDNFormat="uid={0},ou=people,dc=example,dc=com">
    </bean>

</beans>
```


User Modification Access

 Add TOTP secret via TCP (with password auth)
```
ldapmodify -x -H ldap://localhost:389 \
  -D "cn=admin,dc=learn,dc=ac,dc=lk" \
  -W << 'EOF'
dn: uid=testme,ou=people,dc=learn,dc=ac,dc=lk
changetype: modify
add: description
description: TOTP_SECRET=JBSWY3DPEBLW64TMMQ======
EOF
```






















