# Add LEARN Video Conferencing services to your IDP.

This will guide you through enabling LEARN Video Conferencing services via Zoom on your IDP. It is assumed that you have a working **Shibboleth IDP** installed with the **membership** of **LEARN Identity Access Federation ( LIAF )**. 

> Note: You may refer https://github.com/LEARN-LK/IAM in installing your IDP. Also the content of [IAM workshop](https://ws.learn.ac.lk/wiki/iam2018agenda) will help you to understand what is Shibboleth and the process of federating identities.

## Required Identity Features

Signing-in using federation to Zoom system requires following directory attributes.

* sn
* uid (unique username to identify the user within the domain)
* givenname
* eduPersonAffiliation
* eduPersonOrgUnitDN
* mobile

Therefore, it is essential to have those fields properly populated. Specially,

* Values for the attribute mobile should be in the form of `+94xxxxxxxxx` (eg: `+94770055755` )
* Values for the attribute eduPersonOrgUnitDN should be in the form of `ou=Department,ou=Faculty,o=University,c=LK`  (eg: `ou=Physics,ou=Faculty of Sciences,o=University of Colombo,c=LK` ) ( Note: This is not the tree stucture of your directory, but an attribute for each user. )
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
* Zoom Service is provisioned to have pro accounts for all those who have faculty/ staff/ alum/ member or affiliate as their eduPersonAffiliation. Affiliations, student, employee and library-walk-in will have basic account types. 

>Note:

> **Basic Account:** A basic user can host meetings with up to 100 participants. If 3 or more participants join, the meeting will time out after 40 minutes. They cannot utilize user and account add-ons such as large meeting, webinar, or conference room connector. 

> **Pro Account:** A pro user is a paid account by LEARN and can host unlimited meetings on the public cloud with up to 100 participants. Pro users have these additional features available:
> * Customize Personal Meeting ID
> * Be an alternative host
> * Schedule Meetings
> * Share screen as well as provide rights to participants to share their screens
> * Provide Remote support to participants via personal meeting while others observe.
> * Create custom polls during meetings


## Allow Zoom service

Edit the Relaying Party configuration by `vim /opt/shibboleth-idp/conf/relying-party.xml` and append the following bean to  `<util:list id="shibboleth.RelyingPartyOverrides">` . . . `</util:list> `

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
Next Restart Tomcat 8: ```service tomcat8 restart```
    
    
Now you can use the sign in feature of https://learn.zoom.us with your IDP through LIAF.

How to work with Zoom is available at https://support.zoom.us/hc/en-us

> Note:

* If you do not participate in LIAF, please follow the guidelines in becoming a member by accessing https://liaf.ac.lk
* If you have any technical issues, contact LEARN TAC ( `tac[at]learn.ac.lk` ) or Deepthi ( `+94 763785625` ) for the assistance.
