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
   docker pull satosa/satosa
  ```

* Make data directory `mkdir data`

* Run docker container
  ```
  docker run -i -t  -p 8080:8080 -v /PATH-to-Directory/data/:/data -e DATA_DIR=/data -e PROXY_PORT=8080 -e SATOSA_STATE_ENCRYPTION_KEY=###RANDOM_KEY### -e SATOSA_USER_ID_HASH_SALT=###RANDOM_KEY### -e METADATA_DIR=/data/meta --restart unless-stopped satosa/satosa
  ```
* Go to data directory; `cd /PATH-to-Directory/data/`
* Create backend  `vim plugins/backends/saml2_backend.yaml` , there will be an example for the reference.

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
* Create front end `vim plugins/frontends/saml2_frontend.yaml` , there will be an example for the reference.
   
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
        local: [sp.xml]
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
              text: "LIAF Proxy"
          description:
            - lang: en
              text: "LEARN Identity Access Federation Identity Proxy"
          information_url:
            - lang: en
              text: "https://liaf.ac.lk"
          privacy_statement_url:
            - lang: en
              text: "https://idp.learn.ac.lk/privacy.html"
          keywords:
            - lang: en
              text: ["Satosa", "IdP-EN"]
          logo:
            text: "https://idp.learn.ac.lk/logo60x80.png"
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
     "https://learn.zoom.us": LoA1
    endpoints:
     single_sign_on_service:
       'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST': sso/post
       'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect': sso/redirect
   ```
   
