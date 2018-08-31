# Install the OpenLDAP Server on Ubuntu 18.04 LTS with eduPerson Schema

It is assumed that you have already install your Ubuntu server with a public IP address and a Domain Name (*ldap.YOUR-DOMAIN*). 

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
  - DNS domain name: ***YOUR-DOMAIN*** (use the server's domain name, minus the hostname. This will be used to create the base entry for the information tree)
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
cn = idap.YOUR-DOMAIN
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
dn:cn=config
changetype:modify
add:olcTLSCACertificateFile
olcTLSCACertificateFile:/etc/ssl/certs/ca_server.pem
-
add:olcTLSCertificateFile
olcTLSCertificateFile:/etc/ssl/certs/ldap_server.pem
-
add:olcTLSCertificateKeyFile
olcTLSCertificateKeyFile:/etc/ssl/private/ldap_server.key
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
ldapmodify -H ldapi:// -Y EXTERNAL -f addcerts.ldif
```

then `ctrl+c` to stop the debug mode on first console and start the service.

```
sudo service slapd start
```


Your clients can now be configured to encrypt their connections to the server over the conventional 'ldap://ldap.YOUR-DOMAIN:389' port by using STARTTLS.


== Setting up the Client Machines ==

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
ldapwhoami -H ldap:// -x -ZZ
```
This forces a STARTTLS upgrade. If this is successful, you should see:
```
STARTTLS success

anonymous
```

### Load eduPerson Schema.

Get the schema downloaded from [Eduperson.ldif](./eduperson-201602.ldif)

Or the latest from `https://spaces.at.internet2.edu/display/macedir/LDIFs`

Load it using:

```bash
ldapadd -Y EXTERNAL -H ldapi:/// -f eduperson-201602.ldif
```
