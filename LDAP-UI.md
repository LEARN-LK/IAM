Native LDAP store doesn't come with a GUI. Therefore, as administrators we may have to provide a nice user interface to our users. This UI should have the capability of changing details of users password resets, etc. To do these actions there are lot of open source packages as well as commercialized products.

On this tutorial we will go through two UI setups that will focus on different outputs.

## Apache Directory Studio *(For Admins)*

* Download and install
   The latest version of Apache Directory Studio can be downloaded to your host machine from the Apache Directory Studio Downloads page, at this address : http://directory.apache.org/studio/downloads.html
   
   Install Java Runtime Environment from `https://www.java.com/en/download/`
   
   Apache Directory Studio installation steps `https://directory.apache.org/studio/users-guide/apache_directory_studio/download_install.html`

   Once the installation succeeds open the Apache Directory Studio.

   Creating the ldap connection:
```
Go to File --> new --> ldap browser --> ldap connection --> next
```

   Enter your deatils:

```
Connection Name: LDAP Server
Hostname: idp.YOUR-DOMAIN.ac.lk
port: 389
Encrypted Method: Use STARTTLS
Provider: Apache Directory LDAP Client API
```

`Next`

```
Authentication Method: Simple Authentication
Bind Dn: cn=admin,dc=YOUR-DOMAIN,dc=ac,dc=lk
Bind Password:
```

   Click `Check Authentication` to make sure your credentials work. For the first time it ask to trust the self signed certificate.

   Select `Always trust this Certificate` and click `OK`

   Then click `Finish`.

*  To connect, double click the connection just created from ** Connections ** list.

* Once connected you can browse through the directory using the LDAP Browser.

* When modifying entries you may use a ldif file or the GUI.

* Using GUI to create an OU:
  - Select ***root location*** for the OU (eg. dc=YOUR-DOMAIN,dc=ac,dc=lk)
  - Select `New Entry` on ***Right click Menu***
  - Then `Create entry from Scratch`  --> `Next`
  - Select `OrganizationalUnit` and click `Add` and `Next`
  - Type `OU` as the ***RDN*** and the desired value in-front of it, then click `Next` and `Finish`


* Adding a User Group
  - Select ***root location*** for the OU (eg. ou=Group,dc=YOUR-DOMAIN,dc=ac,dc=lk)
  - Select `New Entry` on ***Right click Menu***
  - Then `Create entry from Scratch`  -->  `Next`
  - Select `groupofNames` and click `Add` and `Next`
  - Type `CN` as the ***RDN*** and the desired value in-front of it and then click `Next`
  - You will prompt with a ***user add window*** as DN Editor. Select a user from browser and click `OK`


* Adding a new User
  - Select ***root location*** for the OU (eg. ou=People,dc=YOUR-DOMAIN,dc=ac,dc=lk)
  - Select `New Entry` on ***Right click Menu***
  - Then `Create entry from Scratch`  -->  `Next`
  - Select `inetOrgPerson` and click `Add`
  - Select `eduPerson` and click `Add` and `Next`
  - Type `uid` as the ***RDN*** and the desired username value in-front of it and then ***Next***
  - Enter desired values for ***cn*** (First Name) and ***sn*** (last Name) 
  - Enter `new attribute` from ***right click menu***  as `userPassword` and click finish. when it asks, enter the new users password and select ***Plaintext*** as the hash method and click ***OK***
  - You may add any other attribute as well.
  - Then click finish


More documentation can be found on https://directory.apache.org/studio/users-guide/


## Keycloak Server *(For End Users)*

Keycloak is an open source identity and access management solution, we will use keycloak only to provide a friendly self care portal to users allowing services such as password resets.

We will install Keycloak in your idp vm for the lab purpose but it is recommended to install it on a separate server with at least 4GB RAM.

It is assumed that your FQDN of the server is ***keycloak.YOUR-DOMAIN.ac.lk***

* Install Dependancies
   * Become the root user by `sudo su`
   * `apt-get install vim default-jdk`
   * Define the constant `JAVA_HOME` inside /etc/environment:
      * `update-alternatives --config java`
        (copy the path without /bin/java)
      * `vim /etc/environment` and include
       * `JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64` and save & exit.
      * Then make that environment active by `source /etc/environment`
    * Also we need to export the variable using `export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64`


* Download Keycloak and extract:
   * 
   ```
        cd /opt/
        wget https://downloads.jboss.org/keycloak/6.0.1/keycloak-6.0.1.tar.gz
   ``` 
   ```
        tar -xvzf keycloak-6.0.1.tar.gz
    ```

* Go to the executable directory:
   ```
     cd /opt/keycloak-6.0.1/bin/
   ```
 
* Create Initial Admin User; Please change username ***adminiam*** and password ***Iam@2018***;
   ```
     ./add-user-keycloak.sh -r master -u adminiam -p Iam@2018
    ```

* Edit listning interface:
   ```
      cd ..
       vim standalone/configuration/standalone.xml
   ```
   look for the `interfaces` XML block   
   ```xml
          <interfaces>
                  <interface name="management">
                      <inet-address value="${jboss.bind.address.management:127.0.0.1}"/>
                  </interface>
                  <interface name="public">
                      <inet-address value="${jboss.bind.address:127.0.0.1}"/>
                  </interface>
          </interfaces>
   ```

  Change IP address `127.0.0.1` to `0.0.0.0` allowing traffic from outside.

* Start the server
```
     ./bin/standalone.sh &
```

* Now you should be able to access the server through your browser by accessing:
  `https://keycloak.YOUR-DOMAIN.ac.lk:8443/auth/admin`

* Log in to the master admin console. This will provide full privileged access to the system.

* Create your own realm (domain)
   * From the Master drop-down menu, click Add Realm.
   * Put ***YOUR-DOMAIN*** as the Name and `Add`
   
   From here onwards, make sure you select YOUR-DOMAIN from the master menu when doing changes.

* Customizing Realm
   * Go to your "Realm Settings"
   * On ***General*** tab
      * Enter display name as ***Your Institute***
      * Enter HTML display name as `<span><img src="URL-TO-YOUR-LOGO"></span>` and SAVE
   * On Login tab
      * Switch ***on*** `Forgot password`
      * Switch ***off*** `Login with email`  and SAVE

* Connect your ldap instance:
   * Go to ***User Federation*** and select ***ldap*** from add provider drop down menu.
      * Mark Edit Mode as ***WRITEABLE***
      * Sync Registrations as ***ON***
      * Vender as ***Other***
      * User Object Classes as `inetOrgPerson, organizationalPerson, eduPerson, extensibleObject`
      * Connection URL as `ldap://idp.YOUR-DOMAIN.ac.lk:389`
      * Users DN as `ou=people,dc=YOUR-DOMAIN,dc=ac,dc=lk`
      * Authentication type as ***simple***
      * BIND DN as `cn=admin,dc=YOUR-DOMAIN,dc=ac,dc=lk`
      * Bind Credential as `Your-Password`
      * Search Scope as ***subtree***
      * Periodic Full Sync as ***ON***
      * Periodic Changed Users Sync as ***ON***
      * Save
   For the first time you will need to click ***Synchronize All Users*** 

* Map User Attributes

   You have to map user attributes that are essential in password resetting. When a user clicks forgot password link it will send a reset link to a working email. Keep in mind that the attribute `mail` should be the key attribute for mapping the ldap user for various outside services. Therefore it should be something in the format `user@your-domain.ac.lk` and it should not be allowed to be changed by the users. Because of this, we will use ldap attribute `email` to fill in the alternate email of the user which is used to send the reset requests. 

   To do this you need to edit the ldap email mapper from the settings.
   
   Go to `User Federation --> ldap --> Mappers` and select email

   Change the value of ***LDAP Attribute*** to ***email*** and Save.

   On your production servers you need to configure your email server settings on `Realm Settings --> Email`

Ask Users to login to https://keycloak.Your-Domain.ac.lk:8443/auth/realms/Your-Domain/account change there user profile and details (Change Your-Domain in the url as per your realm name)

* Usage of OTP.

   Users can utilize the function OTP from their profile page. They may use any OTP software such as Google Authenticator, Authy, etc. This will add additional security to the password reset process.
   
* Customize User Profile page to change ldap attribute values.

   By default users are only allowed to change Email, First Name and Last Name. But if you want to provide them access to change their any other details, you need to customize the template from the back end.

   Steps in Adding attribute `mobile` to be edited by users:  

   * First include the custom attribute by accessing `User Federation --> ldap --> Mappers --> Add`
      * Name: mobile
      * Mapper Type: user-attribute-ldap-mapper
      * User Model Attribute: mobile
      * LDAP Attribute: mobile
      * Save
      * Do to Settings tab and click ***Synchronize All Users***
   * Then you should see mobile values under attributes tab of the User's details page.
   * Next we have to customize the User Profile. For that you must log back to your Keycloak server via console or ssh and become root.
   * Create a custom theme as yourdomain
      ```
          cd /opt/keycloak-6.0.1/
       ```
       ```
          cp -r themes/keycloak themes/yourdomain
          cp themes/base/account/account.ftl themes/yourdomain/account/account.ftl
       ```
   The first cp command will create an exact copy of default keycloak theme as yourdomain and the second cp will create a copy of user profile page in to our theme.
   * Next edit the `themes/yourdomain/account/account.ftl` and include following just above the form group `<div class="form-group"> <div id="kc-form-buttons" class="col-md-offset-2 col-md-10 submit">`
      ```xml
            <div class="form-group">
               <div class="col-sm-2 col-md-2">
                   <label for="user.attributes.mobile" class="control-label">Mobile number</label>
               </div>

               <div class="col-sm-10 col-md-10">
                   <input type="text" class="form-control" id="user.attributes.mobile" name="user.attributes.mobile" value="${(account.attributes.mobile!'')}"/>
               </div>
            </div>
      ```
   * Then we have to restart the keycloak service
     ```
         bin/jboss-cli.sh --connect command=:shutdown
         bin/standalone.sh &
     ```

   * Next log back to the admin console of keycloak and traverse to `Realm Settings --> Themes` and change the value of '''Account Theme''' to `yourdomain`
   * Now you may log in to user profile https://keycloak.Your-Domain.ac.lk:8443/auth/realms/Your-Domain/account and check whether the settings have applied, remember to use a private window as you needs to be authenticated as an ldapuser

> For further customization you may consult keycloak official guides from https://www.keycloak.org/docs/latest/server_development/index.html#_themes
