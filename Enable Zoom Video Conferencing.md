# Add Zoom Video Conferencing services to your IDP.

This will guide you throgh enabling Zoom video conferencing services on your IDP. 

## Prerequisite 

* Shibboleth IDP istalled
* Membership of LIAF
* User Attibutes sn, givenname, eduPersonAffiliation, eduPersonOrgUnitDN, mobile properly populated.

## Allow Zoom service

Edit the Relaying Party configuration by `vim /opt/shibboleth-idp/conf/relying-party.xml` and the following bean to  `<util:list id="shibboleth.RelyingPartyOverrides">` . . . `
</util:list> `

```xml
        <bean parent="RelyingPartyByName" c:relyingPartyIds="https://proxy.liaf.ac.lk/Saml2/proxy_saml2_backend.xml">
            <property name="profileConfigurations">
                <list>
                    <bean parent="SAML2.SSO" p:encryptAssertions="false" p:postAuthenticationFlows="attribute-release" />
                    <ref bean="SAML2.Logout" />
                    <ref bean="SAML2.AttributeQuery" />
                    <ref bean="SAML2.ArtifactResolution" />
                    <ref bean="Liberty.SSOS" />
                </list>
            </property>
        </bean>
```

Now you can use the sign in feature of https://learn.zoom.us with your IDP through LIAF.

> Note:

* If you do not satisfy the prerequisite, please contact LEARN TAC ( `tac[at]learn.ac.lk` ) for the assistance.
* Values for the attribute mobie should be in the form of `+94770055755`
* Values for the attribute eduPersonOrgUnitDN should be in the form of `ou=Department,ou=Faculty,o=University,c=LK`  (eg: `ou=Physics,ou=Faculty of Sciences,o=University of Colombo,c=LK` )
* Values for the attribute eduPersonAffiliation must be either `faculty`, `student`, `staff`, `alum`, `member`, `affiliate`, `employee`, `library-walk-in` as per the below definition,

 | Value | Meaning |
 |-------|---------|
 | faculty | Academic or Research staff |
 | student | Undergraduate or postgraduate student |
 | staff | All staff |
 | employee | Employee other than staff, e.g. contractor |
 | member	| Comprises all the categories named above, plus other members with normal institutional privileges, such as honorary staff or visiting scholar |
 | affiliate | Relationship with the institution short of full member |
 | alum	| Alumnus/alumna (graduate) |
 | library-walk-in | A person physically present in the library |
 
