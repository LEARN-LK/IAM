## Eduroam tools container-based deployment: Overall considerations
Based on (REANNZ/ectdb-public)(https://github.com/REANNZ/etcbd-public]

The ancilliary tools package consists of three separate sets of tools:

- Admintool
- Metrics
- Monitoring

Each of the tools is (at the moment) designed to run in an isolated environment. They can be run on a single docker host by mapping each to a different port. The configuration files provided here are designed this way:

- Admintool runs on ports 80 and 443 (HTTP and HTTPS)
- Monitoring tools run on ports 8080 and 8443 (HTTP and HTTPS)
- Metrics runs on ports 9080 and 9443 (HTTP and HTTPS)

## System Requirements

All of the services are packaged as Docker containers, so are not tightly linked to the details of the system they are running on. However, the following considerations apply to the system:

- The system should be running a recent version of Linux supported by Docker(Manual is tested on Ubuntu 22
- The system can be either a virtual machine or a physical (real hardware) system.)
- The system should have at least 5GB of disk space (recommended 10GB) available under /var/lib/docker (on the /var partition or on the root filesystem if not partitioned).
- The system should have at least 4GB of RAM (recommended 8GB) available.
- Docker (Install and configure Docker - [Manual](https://github.com/REANNZ/etcbd-public/blob/master/Docker-setup.md))
- Mailserver - Some of the tools (admintool and monitoring) will need to send outgoing email. Please make sure you have the details of an SMTP ready - either one provided by your systems administrator, or one running on the local system.

## Basic Setup

On each of the VMs, start by cloning the git repository:

```git clone https://github.com/REANNZ/etcbd-public```

## Deploying admintool - djnro

Modify the ```admintool.env``` file with deployment parameters - override at least the following values:

- Pick your own admin password: ```ADMIN_PASSWORD```

- Pick internal DB passwords: ```DB_PASSWORD```, ```POSTGRES_PASSWORD```

Generate these with: ```openssl rand -base64 12```
- ```SITE_PUBLIC_HOSTNAME```: the hostname this site will be visible as.

- ```LOGSTASH_HOST```: the hostname the metrics tools will be visible as.

- ```EMAIL_*``` settings to match the local environment (server name, port, TLS and authentication settings)

- ```SERVER_EMAIL```: From: email address to use in outgoing notifications.

-  ```ADMIN_EMAIL```: where to send NRO admin notifications.

- ```REALM_COUNTRY_CODE``` / ```REALM_COUNTRY_NAME``` - your eduroam country

```NRO_ROID```: Roaming Operator ID, as assigned by eduroam-OT. Defaults to <REALM_COUNTRY_CODE>01.

Note that this option is not included in the file template, add it manually if there is a need to override the default value.

- ```NRO_INST_NAME```: the name of the institution acting as the National Roaming Operator (NRO)

- ```NRO_INST_URL```: the URL of the institution acting as the NRO

- ```NRO_INST_FACEBOOK``` (OPTIONAL): the Social Media (Facebook) handle of the NRO institution

- ```NRO_INST_TWITER``` (OPTIONAL): the Social Media (Twitter) handle of the NRO institution

- ```NRO_FEDERATION_NAME```: the name of the AAI federation the Admintool is connected to (if available to the NRO). Leave unmodified if no AAI federation exists locally.

- ```FEDERATION_DOC_URL```: URL to the federation policy document / documentation about the federation.

- ```TIME_ZONE``` - your local timezone (for the DjNRO web application)

- ```MAP_CENTER_LAT```, ```MAP_CENTER_LONG``` - pick your location

- ```REALM_EXISTING_DATA_URL```: In a real deployment, leave this set to blank (```REALM_EXISTING_DATA_URL=```) to start with an empty database. In a test deployment, you can point to an existing database to load the initial data (e.g., ```https://<existing_admintool>/general/institution.xml```).

- ```GOOGLE_KEY/GOOGLE_SECRET``` - provide Key + corresponding secret for an API credential (see below on configuring these settings)

- ```GOOGLE_API_KEY``` - provided a Google Maps browser API key (see below)

- ```ADMINTOOL_SECRET_KEY```: this should be a long and random string used internall by the admintool.

Please generate this value with: ```openssl rand -base64 48```

- ```ADMINTOOL_DEBUG```: for troubleshooting, uncomment the existing line:
- ```ADMINTOOL_DEBUG=True``` - but remember to comment it out again (or change to False or blank) after done with the troubleshooting.

- ```ADMINTOOL_LOGIN_METHODS```: enter a space-separated list of login methods to enable.

Choose from:
- ```shibboleth```: SAML Login with Shibboleth SP via an identity federation. Not supported yet.
- ```locallogin```: Local accounts on the admin tool instance.
Note that local accounts can later be created by logging into the Admintool at https://admin.example.org/admin/ as the administrator (with the username and password created here), and selecting Users from the list of tables to administer, and creating the user with the Add user button.
- ```google-oauth2```: Login with a Google account. Only works for applications registered with Google - see below on enabling Google login.
- ```yahoo```: Login with a Yahoo account. No registration needed.
- ```amazon```: Login with an Amazon account. Registration needed.
- ```docker```: Login with a Docker account. Registration needed.
- ```dropbox-oauth2```: Login with a Dropbox account. Registration needed.
- ```facebook```: Login with a Facebook account. Registration needed.
- ```launchpad```: Login with an UbuntuOne/Launchpad account. No registration needed.
- ```linkedin-oatuh2```: Login with a LinkedIn account. Registration needed.
- ```meetup```: Login with a MeetUp account. Registration needed.
- ```twitter```: Login with a Twitter account. Registration needed.
Please note that many of these login methods require registration with the target site, and also need configuring the API key and secret received as part of the registration. Please see the Python Social Auth Backends documentation for the exact settings required.

Additional settings: it is also possible to pass any arbitrary settings for the Admintool (or its underlying module) by prefixing the setting with ```ADMINTOOL_EXTRA_SETTINGS_. ```This would be relevant for passing configuration entries to the login methods configured above - especially ```SECRET``` and ```KEY``` settings for login methods requiring these. Example: to pass settings required by Twitter, add them as:

  ```ADMINTOOL_EXTRA_SETTINGS_SOCIAL_AUTH_TWITTER_KEY=93randomClientId```
  ```ADMINTOOL_EXTRA_SETTINGS_SOCIAL_AUTH_TWITTER_SECRET=ev3nM0r3S3cr3tK3y```

Icinga configuration: please see the separate section on using the Admintool to generate configuration for Icinga(Monitoring).

Note this file (admintool.env) is used both by containers to populate runtime configuration and by a one-off script to populate the database.

As an additional step, in global-env.env, customize system-level TZ and LANG as desired.

Use ```Docker-compose``` to start the containers:
```
cd etcbd-public/admintool
docker-compose up -d
```

Run the setup script:

```./admintool-setup.sh admintool.env```

Please note: the ```admintool-setup.sh``` script should be run only once. Repeated runs of the script would lead to unpredictable results (some database structures populated multiple times). Also, for most of the configuration variables (except those listed below), re-running the script is not necessary - restarting the containers should be sufficient (```docker-compose up -d```). The following variables would are the ones where a container restart would NOT be sufficient:

```SITE_PUBLIC_HOSTNAME```: if this value has changed after running admintool-setup.sh, besides restarting the containers, change the value also in the Sites entry in the management interface at ```https://admin.example.org/admin/```

```REALM_COUNTRY_CODE```, ```NRO_INST_NAME```: if any of these values has changed after running admintool-setup.sh, besides restarting the containers, change the value also in the Realms entry in the management interface at ```https://admin.example.org/admin/```

```ADMIN_USERNAME```, ```ADMIN_EMAIL```, ```ADMIN_PASSWORD```: if any of these values has changed after running admintool-setup.sh, besides restarting the containers, change the value also in the account definition in the Users table in the management interface at ```https://admin.example.org/admin/```

```DB_USER```, ```DB_NAME```, ```DB_PASSWORD```, ```DB_HOST```: changing these values after database initialization is an advanced topic beyond the scope of this document. Please see the Troubleshooting section below.

```REALM_EXISTING_DATA_URL```: changing this value after database initialization is an advanced topic beyond the scope of this document. Please see the Troubleshooting section below.

## Installing proper SSL certificates for Admintool
to-be-updated

## Preparing Icinga configuration in Admintool
to-be-updated

## Deploying monitoring tools

Modify the ```icinga.env``` file with deployment parameters - override at least the following values:

- Pick your own admin password: ```ICINGAWEB2_ADMIN_PASSWORD```
- Pick internal DB passwords: ```ICINGA_DB_PASSWORD```, ```ICINGAWEB2_DB_PASSWORD```, ```POSTGRES_PASSWORD```
Tip; Generate these with: openssl rand -base64 12
- ```SITE_PUBLIC_HOSTNAME```: the hostname this site will be visible as (also used by Icinga for outgoing notifications)
- ```ICINGA_ADMIN_EMAIL```: where to send notifications
- ```EMAIL_*``` settings to match the local environment (server name, port, TLS and authentication settings)
- ```EMAIL_FROM``` - From: address to use in outgoing notification emails.
The following configure Icinga monitoring and check and notification intervals:
- ```ICINGA_NOTIFICATION_INTERVAL```: Re-notification interval in seconds. 0 disables re-notification. Defaults to 7200 (2 hours).
- ```ICINGA_CHECK_INTERVAL```: Check interval in seconds (HARD state). Defaults to 300 (5 minutes)
- ```ICINGA_RECHECK_INTERVAL```: Interval (in seconds) for rechecking after a state change (SOFT state). Defaults to 60 seconds.

The following settings configure how Icinga fetches the configuration generated by the Admintool:

- ```CONF_URL_LIST```: the URL (possibly a list of URLs) to fetch configuration from. Should be ```https://eduroam-admin.example.org/icingaconf```
- ```CONF_URL_USER```: the username to use to authenticate to the configuration URL.
- ```CONF_URL_PASSWORD```: the password to use to authenticate to the configuration URL.
- ```CONF_REFRESH_INTERVAL```: the time period (in seconds) to wait before reloading the configuration from the URL. Defaults to 3600 (1 hour).
- ```WGET_EXTRA_OPT```S: additional options to passs to wget when fetcing the configuration. This needs in particular to take care of wget establishing trust for the certificate presented by the server.
If the Admintool Apache server has already been configured with a certificate from an accredited Certification Authority (optional step above), no further action is needed.

If the Admintool is using a self-signed automatically generated certificate, we recommend:

Copying this certificate into the Icinga configuration volume so that wget can access the certificate:

Note that at this stage, the volume for the Icinga external configuration has not been created yet, so we need to jump the gun and create it explicitly (otherwise, the volumes get created automatically by docker-compose up): 

```docker volume create --name icinga_icinga-external-conf```

Copy the certficiate (by running the "cp" command in a container mounting both volumes): 

```docker run --rm --name debian-cp -v admintool_apache-certs:/admintool-apache-certs -v icinga_icinga-external-conf:/icinga_icinga-external-conf debian:jessie cp /admintool-apache-certs/server.crt /icinga_icinga-external-conf/```

And instructing wget to trust this certificate: ```WGET_EXTRA_OPTS=--ca-certificate=/etc/icinga2/externalconf/server.crt```

Alternatively, it is also possibly to instruct wget to blindly accept any certificate - but as this creates serious security risks, it can only be used for internal tests and MUST NOT be used in production. The setting is: ```WGET_EXTRA_OPTS=--no-check-certificate```
This file is used by both the containers to populate runtime configuration and by a one-off script to populate the database.

Additionally, in global-env.env, customize system-level TZ and LANG as preferred - or you can copy over global.env from admintool:
```
cd etcbd-public/icinga
cp ../admintoool/global-env.env .
```
Use Docker-compose to start the containers:
```
cd etcbd-public/icinga
docker-compose up -d
```
Run the setup script:

```./icinga-setup.sh icinga.env```

Please note: the ```icinga-setup.sh``` script should be run only once. Repeated runs of the script would lead to unpredictable results (some database structures populated multiple times). Also, for most of the configuration variables (except those listed below), re-running the script is not necessary - restarting the containers should be sufficient (```docker-compose up -d)```. The following variables would are the ones where a container restart would NOT be sufficient:

- ```ICINGAWEB2_ADMIN_USERNAME```,``` ICINGAWEB2_ADMIN_PASSWORD```: if any of these values has changed after running icinga-setup.sh, change the value also in the account definition in the management interface at - ```https://monitoring.example.org/icingaweb2/```

(if you have already changed the ports.if not ```https://monitoring.example.org:8443/icingaweb2/```) (navigate to Configuration => Authentication => Users => select the account).

```ICINGA_DB_USER```, ```ICINGA_DB_NAME```, ```ICINGA_DB_PASSWORD```, ```ICINGA_DB_HOST```, ```ICINGAWEB2_DB_USER```, ```ICINGAWEB2_DB_NAME```, ```ICINGAWEB2_DB_PASSWORD```,``` ICINGAWEB2_DB_HOST```: changing these values after database initialization is an advanced topic beyond the scope of this document. 

Please see the Troubleshooting section below.

Note: at this point, Icinga will be executing checks against all Radius servers as configured. It is essential to also configure the Radius servers to accept the Icinga host as a Radius client - with the secret as configured in the Admintool.

Note: Icinga will be using the configuration as generated by the Admintool. When the settings change in Admintool, Icinga would only see the changes next time it fetches the configuration. This defaults to happen every hour. To trigger an immediate reload, either restart the container, or send it the "Hang-up" (HUP) signal:

```docker kill --signal HUP icinga```

## Deploying metrics tools

Modify the elk.env file with deployment parameters - override at least the following values:

Pick your own admin password: ADMIN_PASSWORD

```ADMIN_USERNAME```: optionally configure the administrator username (default: admin)
```SITE_PUBLIC_HOSTNAME```: the hostname this site will be visible as.
```ADMIN_EMAIL```: email address so far only used in web server error messages.
```LOCAL_COUNTRY```: two-letter country code of the local country (for metrics to identify domestic and international visitors and remote sites).
```INST_NAMES```: white-space delimited list of domain names of institutions to generate per-instititon dashboard and visualizations for.
Additionally, in ```global-env.env```, customize system-level TZ and LANG as preferred - or you can copy over ```global.env``` from admintool:
```
cd etcbd-public/elk
cp ../admintoool/global-env.env .
```
ElasicSearch needs one system-level setting tuned: vm.max_map_count needs to be increased from the default 65530 to 262144. Without this setting in place, ElasticSearch fails to start. To change the setting both in the currently booted system and to make it apply after a reboot, run (as root):
```
sysctl -w vm.max_map_count=262144
echo "vm.max_map_count = 262144" > /etc/sysctl.d/70-elasticsearch.conf
```
And now, back in etcbd-public/elk, use Docker-compose to start the containers:
```
docker-compose up -d
```
Run the setup script:

```./elk-setup.sh```

Please note: the ```elk-setup.sh``` script may be run multiple times (contrary to the other setup scripts). This script pushes a small set of predefined visualizations and dashboards into the Metrics tool (the Kibana web application) - and also applies some setting to elasticsearch (disable replicas, tune down logging). The only environment variables this script depends on are ```LOCAL_COUNTRY``` and ```INST_NAMES```: to propagage a change to these variable, it is necessary to first restart the containers (docker-compose up -d), then re-run the setup script. (If institutions were removed from ```INST_NAMES```, it may be necessary to manually remove the dashboard and visualizations created for these institutions).

The setup script also creates an index pattern in Kibana, telling Kibana where to find your data. However, this may fail if there are no data in ElasicSearch yet, so you may have to reinitialize Kibana after some initial data is ingested into ElasticSearch. You can re-run the setup script with:

```./elk-setup.sh --force```

Note that the --force flag deletes all Kibana settings - but the initial ones get loaded again by the setup script. And the actual data in ElasicSearch stays intact.

## Accessing services

The Admintool can be accessed at https://admin.example.org/

The management interface of the Admnintool can be accessed at https://admin.example.org/admin/

The management interface of the monitoring tools (Icingaweb2) can be accessed at https://monitoring.example.org:8443/icingaweb2/

The web interface of the metrics tools (Kibana) can be accessed at https://metrics.example.org:9443/

(Note: if you have deployed containers in seperate servers, and changed the ports accordingly,chnage the port numbers accordingly)









