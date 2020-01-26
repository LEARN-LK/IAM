# Install the OpenLDAP Server on Ubuntu 18.04 LTS with eduPerson Schema

It is assumed that you have already install your Ubuntu server with a public IP address and a registered Domain Name (**ldap.YOUR-DOMAIN.ac.lk**). 

Modify /etc/hosts and append: (Make sure not to remove exsisting entries)

* `sudo vim /etc/hosts`
```
127.0.0.1 ldap.YOUR-DOMAIN.ac.lk ldap
```
Install the required packages.

```bash
sudo apt-get update
sudo apt-get install slapd ldap-utils gnutls-bin ssl-cert vim
```

In order to access some additional prompts that we need, we'll reconfigure the package after installation. To do so, type:

```bash
sudo dpkg-reconfigure slapd
```

Answer the prompts appropriately, using the information below as a starting point:

  - Omit OpenLDAP server configuration? ***No*** (we want an initial database and configuration)
  - DNS domain name: ***YOUR-DOMAIN.ac.lk*** (use the server's domain name, minus the hostname. This will be used to create the base entry for the information tree)
  - Organization name: ***Your Institute*** (This will simply be added to the base entry as the name of your institute)
  - Administrator password: ***whatever you'd like***
  - Confirm password: ***must match the above***
  - Database backend to use: ***HDB*** (out of the two choices, this has the most functionality)
  - Do you want the database to be removed when slapd is purged? (your choice. Choose ***Yes*** to allow a completely clean removal, choose ***No*** to save your data even when the software is removed)
  - Move old database? ***Yes***



### Create the Certificate Templates

To encrypt our connections, we'll need to configure a certificate authority and use it to sign the keys for the LDAP server(s) in our infrastructure. So for our single server setup, we will need two sets of key/certificate pairs: one for the certificate authority itself and one that is associated with the LDAP service.

To create the certificates needed to represent these entities, we'll create some template files. These will contain the information that the certtool utility needs in order to create certificates with the appropriate properties.

Start by making a directory to store the template files:

```
sudo mkdir /etc/ssl/templates
```

Create the template for the certificate authority first. We'll call the file ca_server.conf. Create and open the file in your text editor:

```
sudo nano /etc/ssl/templates/ca_server.conf
```

We only need to provide a few pieces of information in order to successfully create a certificate authority. We need to specify that the certificate will be for a CA (certificate authority) by adding the ca option. We also need the cert_signing_key option to give the generated certificate the ability to sign additional certificates. We can set the cn to whatever descriptive name we'd like for our certificate authority:

```
cn = LDAP Server CA
ca
cert_signing_key
```

Save and close the file.

Next, we can create a template for our LDAP server certificate called ldap_server.conf. Create and open the file in your text editor with sudo privileges:

```
sudo nano /etc/ssl/templates/ldap_server.conf
```

Here, we'll provide a few different pieces of information. We'll provide the name of our organization and set the tls_www_server, encryption_key, and signing_key options so that our cert has the basic functionality it needs.

The cn in this template must match the FQDN of the LDAP server. If this value does not match, the client will reject the server's certificate. We will also set the expiration date for the certificate. We'll create a 10 year certificate to avoid having to manage frequent renewals:
`ldapserver.conf`

```
organization = "Name of your institution"
cn = ldap.YOUR-DOMAIN.ac.lk
tls_www_server
encryption_key
signing_key
expiration_days = 3652
```

Save and close the file when you're finished.

### Create CA Key and Certificate

Now that we have our templates, we can create our two key/certificate pairs. We need to create the certificate authority's set first.

Use the certtool utility to generate a private key. The `/etc/ssl/private` directory is protected from non-root users and is the appropriate location to place the private keys we will be generating. We can generate a private key and write it to a file called ca_server.key within this directory by typing:

```
sudo certtool -p --outfile /etc/ssl/private/ca_server.key
```

Now, we can use the private key that we just generated and the template file we created in the last section to create the certificate authority certificate. We will write this to a file in the `/etc/ssl/certs` directory called ca_server.pem:

```
sudo certtool -s --load-privkey /etc/ssl/private/ca_server.key --template /etc/ssl/templates/ca_server.conf --outfile /etc/ssl/certs/ca_server.pem
```

We now have the private key and certificate pair for our certificate authority. We can use this to sign the key that will be used to actually encrypt the LDAP session.


### Create LDAP Service Key and Certificate

Next, we need to generate a private key for our LDAP server. We will again put the generated key in the `/etc/ssl/private` directory for security purposes and will call the file ldap_server.key for clarity.

We can generate the appropriate key by typing:

```
sudo certtool -p --sec-param high --outfile /etc/ssl/private/ldap_server.key
```

Once we have the private key for the LDAP server, we have everything we need to generate a certificate for the server. We will need to pull in almost all of the components we've created thus far (the CA certificate and key, the LDAP server key, and the LDAP server template).

We will put the certificate in the `/etc/ssl/certs` directory and name it `ldap_server.pem`. The command we need is:

```
sudo certtool -c --load-privkey /etc/ssl/private/ldap_server.key --load-ca-certificate /etc/ssl/certs/ca_server.pem --load-ca-privkey /etc/ssl/private/ca_server.key --template /etc/ssl/templates/ldap_server.conf --outfile /etc/ssl/certs/ldap_server.pem
```

### Give OpenLDAP Access to the LDAP Server Key

We now have all of the certificates and keys we need. However, currently, our OpenLDAP process will be unable to access its own key.

A group called ssl-cert already exists as the group-owner of the `/etc/ssl/private` directory. We can add the user our OpenLDAP process runs under (openldap) to this group:

```
sudo usermod -aG ssl-cert openldap
```

Now, our OpenLDAP user has access to the directory. We still need to give that group ownership of the `ldap_server.key` file though so that we can allow read access. Give the ssl-cert group ownership over that file by typing:

```
sudo chown :ssl-cert /etc/ssl/private/ldap_server.key
```

Now, give the ssl-cert group read access to the file:

```
sudo chmod 640 /etc/ssl/private/ldap_server.key
```

Our OpenSSL process can now access the key file properly.
Configure OpenLDAP to Use the Certificate and Keys

We have our files and have configured access to the components correctly. Now, we need to modify our OpenLDAP configuration to use the files we've made. We will do this by creating an LDIF file with our configuration changes and loading it into our LDAP instance.

Move to your home directory and open a file called `addcerts.ldif`. We will put our configuration changes in this file:

```
cd ~
vim addcerts.ldif
```

To make configuration changes, we need to target the cn=config entry of the configuration DIT. We need to specify that we are wanting to modify the attributes of the entry. Afterwards we need to add the `olcTLSCACertificateFile`, `olcCertificateFile`, and `olcCertificateKeyFile` attributes and set them to the correct file locations.

The end result will look like this:


```bash
dn: cn=config
changetype: modify
add:olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ssl/certs/ca_server.pem
-
add:olcTLSCertificateFile
olcTLSCertificateFile: /etc/ssl/certs/ldap_server.pem
-
add:olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ssl/private/ldap_server.key
```

Save and close the file when you are finished. Apply the changes to your OpenLDAP system using the ldapmodify command:

```
sudo ldapmodify -H ldapi:// -Y EXTERNAL -f addcerts.ldif
```

We can reload OpenLDAP to apply the changes:

```
sudo service slapd force-reload
```

If you see some error while importing,

Start your `slapd` in debug mode

```
sudo service slapd stop
sudo slapd -h ldapi:/// -u openldap -g openldap -d 65 -F /etc/ldap/slapd.d/ -d 65
```
Then in another console,

```
sudo ldapmodify -H ldapi:// -Y EXTERNAL -f addcerts.ldif
```

then `ctrl+c` to stop the debug mode on first console and start the service.

```
sudo service slapd start
```


Your clients can now be configured to encrypt their connections to the server over the conventional 'ldap://ldap.YOUR-DOMAIN:389' port by using STARTTLS.


### Setting up the Client Machines

In order to connect to the LDAP server and initiate a STARTTLS upgrade, the clients must have access to the certificate authority certificate and must request the upgrade.
On the OpenLDAP Server

If you are interacting with the OpenLDAP server from the server itself, you can set up the client utilities by copying the CA certificate and adjusting the client configuration file.

First, copy the CA certificate from the `/etc/ssl/certs` directory to a file within the `/etc/ldap` directory. We will call this file ca_certs.pem. This file can be used to store all of the CA certificates that clients on this machine may wish to access. For our purposes, this will only contain a single certificate:

```
sudo cp /etc/ssl/certs/ca_server.pem /etc/ldap/ca_certs.pem
```
Now, we can adjust the system-wide configuration file for the OpenLDAP utilities. Open up the configuration file in your text editor with sudo privileges:

```
sudo nano /etc/ldap/ldap.conf
```

Adjust the value of the '''TLS_CACERT''' option to point to the file we just created:

```
TLS_CACERT /etc/ldap/ca_certs.pem
TLS_REQCERT allow
```

Save and close the file.

You should now be able to upgrade your connections to use STARTTLS by passing the '''-Z''' option when using the OpenLDAP utilities. You can force STARTTLS upgrade by passing it twice. Test this by typing:

```
sudo ldapwhoami -H ldap:// -x -ZZ
```
This forces a STARTTLS upgrade. If this is successful, you should see:
```
anonymous
```

Then we need to disallow anonymous login to the ldap server.

Create a ldif file,

```
cd ~
vim ldap_disable_bind_anon.ldif
```

include following,

```bash
dn: cn=config
changetype: modify
add: olcDisallows
olcDisallows: bind_anon

dn: cn=config
changetype: modify
add: olcRequires
olcRequires: authc

dn: olcDatabase={-1}frontend,cn=config
changetype: modify
add: olcRequires
olcRequires: authc
```
Save and close the file when you are finished. Apply the changes to your OpenLDAP system using the ldapmodify command:

```
sudo ldapmodify -H ldapi:// -Y EXTERNAL -f ldap_disable_bind_anon.ldif
```

We can check again,

```
sudo ldapwhoami -H ldap:// -x -ZZ
```

And you should see 

```
ldap_bind: Inappropriate authentication (48)
	additional info: anonymous bind disallowed
```


### Load eduPerson Schema.

Get the schema downloaded from [Eduperson.ldif](https://raw.githubusercontent.com/LEARN-LK/IAM/master/eduperson-201602.ldif)

Or the latest from `https://spaces.at.internet2.edu/display/macedir/LDIFs`

Load it using:

```bash
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f eduperson-201602.ldif
```

Also Lets load The SChema for Academia, SCHAC.
Get the schema downloaded from [SCHAC.ldif](https://raw.githubusercontent.com/LEARN-LK/IAM/master/schac-20150413.ldif)

Or the latest from `https://wiki.refeds.org/display/STAN/SCHAC+Releases`

Load it using:

```bash
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f schac-20150413.ldif
```

### Create User Structure

Depending on your Institute's Requirement, you may create groups and users as follows, but you may need to create mandatory attributes when creating users:

#### Mandatory Attributes:

* Attribute `givenName`: First Name of the User
* Attribute `sn`: Family Name of the User
* Attribute `mail` Primary email address of your domain
* Attribute `email`: Secondary email for the user to help password recovery
* Attribute `eduPersonEntitlement` as `urn:mace:dir:entitlement:common-lib-terms`
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


#### Create a file containing those details and modify your directory.

```
dn: ou=People,dc=YOUR-DOMAIN,dc=ac,dc=lk
objectClass: organizationalUnit
objectClass: top
ou: People
 
dn: ou=Group,dc=YOUR-DOMAIN,dc=ac,dc=lk
objectClass: organizationalUnit
objectClass: top
ou: Group
description: All groups

# System Admin Staff Group
dn: cn=adm,ou=Group,dc=YOUR-DOMAIN,dc=ac,dc=lk
cn: adm
description: System Admin Staff
gidNumber: 1500
objectClass: posixGroup
objectClass: top

# Acadamic staff Group
dn: cn=acd,ou=Group,dc=YOUR-DOMAIN,dc=ac,dc=lk
cn: acd
description: Acadamic Staff
gidNumber: 2000
objectClass: posixGroup
objectClass: top

# Students Group
dn: cn=student,ou=Group,dc=YOUR-DOMAIN,dc=ac,dc=lk
cn: student
description: Students
gidNumber: 5000
objectClass: posixGroup
objectClass: top

# servers OU
dn: ou=servers,dc=YOUR-DOMAIN,dc=ac,dc=lk
description: servers
objectClass: top
objectClass: organizationalUnit
ou: servers

# idp servers, change ipHostNumber to match your servers IP's
dn: cn=idp,ou=servers,dc=YOUR-DOMAIN,dc=ac,dc=lk
cn: idp
description: Identity Server
ipHostNumber: 3ffe:ffff:ffff::9
objectClass: top
objectClass: device
objectClass: ipHost
objectClass: simpleSecurityObject
userPassword: {crypt}idpldap


# test User

dn: uid=testme,ou=people,dc=YOUR-DOMAIN,dc=ac,dc=lk
cn: Test Me
uid: testme
uidNumber: 1001
gidNumber: 1000
givenName: Test Me
homeDirectory: /dev/null
homePhone: none
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
objectClass: eduPerson
objectClass: extensibleObject
objectClass: posixAccount
objectClass: top
objectClass: shadowAccount
sn: Test
mobile: +94123456789
userPassword: testme
mail: testme@YOUR_DOMAIN.ac.lk
email: secondary_email@different_domain.com
eduPersonPrincipalName: testme@YOUR_DOMAIN.ac.lk
eduPersonAffiliation: staff
eduPersonOrgUnitDN: ou=your department,ou=your faculty,o=your institute,c=LK
eduPersonEntitlement: urn:mace:dir:entitlement:common-lib-terms

```

Save the above as a ldif file and add it to your directory as

`sudo ldapadd -H ldap:// -x -D "cn=admin,dc=YOUR-DOMAIN,dc=ac,dc=lk" -W -Z -f path_to_file.ldif`

>You may use https://github.com/LEARN-LK/IAM/tree/master/CSV_to_LDIF to create ldif with bulk user data

### Useful other commands:

* Verify LDAP settings by:

```
sudo ldapsearch -H ldapi:// -Y EXTERNAL -b "cn=config" -LLL -Q
```

* View available schema by:

```
sudo ldapsearch -H ldapi:// -Y EXTERNAL -b "cn=schema,cn=config" -s one -Q -LLL dn
```

* List Users

```
 ldapsearch -h localhost -D "cn=admin,dc=YOUR-DOMAIN,dc=ac,dc=lk" -W -b "dc=YOUR-DOMAIN,dc=ac,dc=lk"
 ```
 
* View/backup ldap (to ldif)

```
sudo slapcat

sudo slapcat > backup.ldif
```

>Next: Installing an UI for LDAP: https://github.com/LEARN-LK/IAM/blob/master/LDAP-UI.md
