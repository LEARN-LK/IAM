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

### need to be updated from here


Clock Sync Check (Important for TOTP)
TOTP codes are time-based. If the server clock drifts, codes will fail.

```
# Check current NTP sync status
timedatectl status

# If not synced, ensure NTP is running
systemctl enable --now ntp
# or on systemd-timesyncd systems:
timedatectl set-ntp true
```

