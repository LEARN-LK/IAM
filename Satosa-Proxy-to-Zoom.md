# This is a simple guide in installing SATOSA proxy to connect Zoom service provider with SAML Federation

By default Zoom enterprise accounts support single entity SAML endpoint. If you need Zoom to be connected to your Federation, you may need to go through a SAML proxy like SATOSA.

## SATOSA proxy.

Detailed Documentation: https://github.com/IdentityPython/SATOSA

## Installation

This assumes you already have a server running latest ubuntu and configured DNS as `proxy-saml.Your-Domain.TLD`

### Install Dependancies
```
apt install apache2 docker apt-transport-https ca-certificates curl software-properties-common gnupg2
```

### Install and configure Satosa
 
* Pull Docker Image 

  ```   
   docker pull satosa/satosa:v3.4.8
  ```

* Make data directories `mkdir -p /PATH-to-Directory/data/plugins/{backends,frontends}`


* Go to data directory; `cd /PATH-to-Directory/data/`
* Create backend  `vim plugins/backends/saml2_backend.yaml`

  ```
  module: satosa.backends.saml2.SAMLBackend
  name: Saml2
  config:  
   sp_config:
    key_file: backend.key
    cert_file: backend.crt
    organization: {display_name: Identity proxy for zoom, name: Zoom Video Conference, url: 'http://yourbranding.zoom.us'}
    contact_person:
    - {contact_type: technical, email_address: YourEmail@Your-Domain.TLD, given_name: yourname, surname: yoursurname}
    - {contact_type: support, email_address: YourEmail2@Your-Domain.TLD, given_name: yourname2, surname: yoursurname2}

    metadata:
      local: [your-federation-metadata.xml]

    entityid: <base_url>/<name>/proxy_saml2_backend.xml
    accepted_time_diff: 60
    service:
      sp:
        ui_info:
          display_name:
            - lang: en
              text: "Zoom Video Conference"
          description:
            - lang: en
              text: "Zoom Video Conferencing by your Federation"
          information_url:
            - lang: en
              text: "http://www.Your-Domain.TLD/infopage/"
          privacy_statement_url:
            - lang: en
              text: "http://www.Your-Domain.TLD/"
          keywords:
            - lang: en
              text: ["Zoom", "video", "conferencing"]
          logo:
            text: "https://www.Your-Domain.TLD/images/yourlogo.png"
            width: "100"
            height: "100"
        authn_requests_signed: true
        want_response_signed: true
        allow_unsolicited: true
        endpoints:
          assertion_consumer_service:
          - [<base_url>/<name>/acs/post, 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST']
          - [<base_url>/<name>/acs/redirect, 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect']
          discovery_response:
          - [<base_url>/<name>/disco, 'urn:oasis:names:tc:SAML:profiles:SSO:idp-discovery-protocol']
        name_id_format: 'urn:oasis:names:tc:SAML:2.0:nameid-format:transient'
        name_id_format_allow_create: true
   # disco_srv must be defined if there is more than one IdP in the metadata specified above
   disco_srv: https://discovery.Your-Domain.TLD/
   ```
* Create front end `vim plugins/frontends/saml2_frontend.yaml` 
   
   ```
   module: satosa.frontends.saml2.SAMLFrontend
   name: Saml2IDP
   config:
    idp_config:
     organization: {display_name: Federation Identities, name: Identity Proxy, url: 'http://www.Your-Domain.TLD'}
     contact_person:
     - {contact_type: technical, email_address: YourEmail@Your-Domain.TLD, given_name: yourname, surname: yoursurname}
     - {contact_type: support, email_address: YourEmail2@Your-Domain.TLD, given_name: yourname2, surname: yoursurname2}
     key_file: frontend.key
     cert_file: frontend.crt
     metadata:
        local: [zoom.xml]
     entityid: https://proxy-saml.Your-Domain.TLD/Saml2IDP/proxy.xml
     accepted_time_diff: 60
     service:
      idp:
        endpoints:
          single_sign_on_service: []
        name: Proxy IdP
        ui_info:
          display_name:
            - lang: en
              text: "SAML Proxy"
          description:
            - lang: en
              text: "Access Federation Proxy"
          information_url:
            - lang: en
              text: "https://www.Your-Domain.TLD"
          privacy_statement_url:
            - lang: en
              text: "https://www.Your-Domain.TLD/privacy.html"
          keywords:
            - lang: en
              text: ["Satosa", "IdP-EN"]
          logo:
            text: "https://www.Your-Domain.TLD/logo60x80.png"
            width: "80"
            height: "60"
        name_id_format: ['urn:oasis:names:tc:SAML:2.0:nameid-format:persistent']
        policy:
          default:
            attribute_restrictions: null
            fail_on_missing_requested: false
            lifetime: {minutes: 15}
            name_form: urn:oasis:names:tc:SAML:2.0:attrname-format:uri
    acr_mapping:
     "": default-LoA
     "https://yourbranding.zoom.us": LoA1
    endpoints:
     single_sign_on_service:
       'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST': sso/post
       'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect': sso/redirect
   ```
   
* Configure `vim internal_attributes.yaml`
  ```
  attributes:
    edupersontargetedid:
      saml: [eduPersonTargetedID]
    mail:
      saml: [mail]
    givenname:
      saml: [givenName]
    surname:
      saml: [sn, surname]
    eduPersonScopedAffiliation:
      saml: [eduPersonScopedAffiliation]
    eduPersonAffiliation:
      saml: [eduPersonAffiliation]
    mobile:
      saml: [mobile]
    eduPersonOrgUnitDN:
      saml: [eduPersonOrgUnitDN]
  user_id_from_attrs: [mail]
  user_id_to_attr: mail
  ```
  
* Configure `vim proxy_conf.yaml`
  ```
  #--- SATOSA Config ---#
  BASE: https://proxy-saml.Your-Domain.TLD
  INTERNAL_ATTRIBUTES: "internal_attributes.yaml"
  COOKIE_STATE_NAME: "SATOSA_STATE"
  STATE_ENCRYPTION_KEY: "###RANDOM_KEY1###"
  CUSTOM_PLUGIN_MODULE_PATHS:
    - "plugins/backends"
    - "plugins/frontends"
  BACKEND_MODULES:
    - "plugins/backends/saml2_backend.yaml"
  FRONTEND_MODULES:
    - "plugins/frontends/saml2_frontend.yaml"
  LOGGING:
    version: 1
    formatters:
      simple:
        format: "[%(asctime)-19.19s] [%(levelname)-5.5s]: %(message)s"
    handlers:
      console:
        class: logging.StreamHandler
        level: DEBUG
        formatter: simple
        stream: ext://sys.stdout
      info_file_handler:
        class: logging.handlers.RotatingFileHandler
        level: INFO
        formatter: simple
        filename: info.log
        maxBytes: 10485760 # 10MB
        backupCount: 20
        encoding: utf8
    loggers:
      satosa:
        level: DEBUG
        handlers: [console]
        propagate: no
    root:
      level: INFO
      handlers: [info_file_handler]
  ```
* Get a copy of your federation metadata in to data directory using `wget` or `curl` (ref: your-federation-metadata.xml)
* Create zoom.xml with metadata recieved from your zoom account. 
  * If you are using vanity url, use `https://yourvanityurl.zoom.us/saml/metadata/sp` to retrieve the metadata
* Generate Certificates.
  * `openssl req -x509 -newkey rsa:4096 -keyout metadata.key -out metadata.crt -nodes -days 1095`
  Example Input:
```
  Generating a RSA private key
............................................................++++
..........................................................................................................................++++
writing new private key to 'metadata.key'
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:TLD
State or Province Name (full name) [Some-State]:
Locality Name (eg, city) []:
Organization Name (eg, company) [Internet Widgits Pty Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:proxy-saml.Your-Domain.TLD
Email Address []:
  ```
  * `openssl req -x509 -newkey rsa:4096 -keyout frontend.key -out frontend.crt -nodes -days 1095`
  * `openssl req -x509 -newkey rsa:4096 -keyout backend.key -out backend.crt -nodes -days 1095`

* Run docker container
  ```
  docker run -i -t -d -p 8080:8080 -v /PATH-to-Directory/data/:/data -e DATA_DIR=/data -e PROXY_PORT=8080 -e SATOSA_STATE_ENCRYPTION_KEY=###RANDOM_KEY1### -e SATOSA_USER_ID_HASH_SALT=###RANDOM_KEY1### -e METADATA_DIR=/data/meta --restart unless-stopped satosa/satosa:v3.4.8
  ```

  
## Configure Apache Proxy.

* Create a new Virtual host `vim /etc/apache2/sites-available/proxysaml.conf`

```
<VirtualHost *:*>
	ProxyPreserveHost On
	ProxyPass / http://127.0.0.1:8080/
	ProxyPassReverse / http://127.0.0.1:8080/
	ServerName proxy-saml.Your-Domain.TLD


	ErrorLog ${APACHE_LOG_DIR}/error.log
	CustomLog ${APACHE_LOG_DIR}/access.log combined

</VirtualHost>
```
* Disable default configs and enable new one.
  * `a2dissite 000-default`
  * `a2enmod proxy proxy_http proxy_ajp rewrite deflate headers proxy_connect proxy_html`
  * `service apache2 restart`

* Install Letsencrypt and enable HTTPS:
  * `add-apt-repository ppa:certbot/certbot`
  * `apt install python-certbot-apache`
  * `certbot --apache -d proxy-saml.Your-Domain.TLD`

## Provide Metadata to Zoom and to your Federation Registry.

* For Zoom: 
  * Sign in page URL: https://proxy-saml.Your-Domain.TLD/Saml2IDP/sso/post
  * IDP Certificate: `cat frontend.crt`
  * SP entity ID: https://yourbranding.zoom.us
  * Issuer ID: https://www.Your-Domain.TLD
  * Binding: HTTP-Post
  * Signature Algorithm SHA256
  * Provision User: At sign-in
  * On SAML response mapping:
  * Default user type : Pro
  * Email: urn:oid:1.3.6.1.4.1.5923.1.1.1.6
  * First name:  urn:oid:2.5.4.42
  * Last Name:  urn:oid:2.5.4.4
  * phonenumber: urn:oid:0.9.2342.19200300.100.1.41
 
  
  
  
  
  * Entity ID: `https://proxy-saml.Your-Domain.TLD/Saml2IDP/proxy.xml`
  * Metadata: `cat meta/frontend.xml`
* For RR3:
  * Entity ID: `https://proxy-saml.Your-Domain.TLD/Saml2/proxy_saml2_backend.xml`
  * Metadata: `cat meta/backend.xml`

### Troubleshoot

* `tail data\info.log`
* `tail /var/log/apache2/access.log`
* `tail /var/log/apache2/error.log`
