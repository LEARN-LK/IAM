## This manual is being updated

# Shibboleth IdP v5+ on Ubuntu Linux LTS 24.04

LEARN concluded a workshop on Federated Identity with the introduction of Shibboleth IDP and SP to IAM infrastructure on member institutions. 

Installation assumes you have already installed Ubuntu Server 24.04 with default configuration and has a public IP connectivity with DNS setup

Lets Assume your server hostname as **idp.YOUR-DOMAIN**

All commands are to be run as **root** and you may use `sudo su`, to become root

## Install Instructions

### Install software requirements

1. Become ROOT:
   * `sudo su -`
   
2. Update packages:
   ```bash
   apt update && apt-get upgrade -y --no-install-recommends
   ```
   
3.Install the required packages:
   ```bash
   apt install vim wget gnupg ca-certificates openssl apache2 ntp --no-install-recommends
   ```

4. Install Amazon Corretto JDK:
   ```bash
   wget -O- https://apt.corretto.aws/corretto.key | apt-key add -

   apt-get install software-properties-common

   add-apt-repository 'deb https://apt.corretto.aws stable main'

   apt-get update; apt-get install -y java-21-amazon-corretto-jdk

   java -version
   ```

Check that Java is working:
   ```bash
   update-alternatives --config java
   ```
   
   (It will return something like this "`There is only one alternative in link group java (providing /usr/bin/java):`" )

### Configure the environment

1. Become ROOT:
   * `sudo su -`
   
2. Be sure that your firewall **is not blocking** the traffic on port **443** and **80** for the IdP server.

3. Set the IdP hostname:

   (**ATTENTION**: *Replace `idp.YOUR-DOMAIN.org` with your IdP Full Qualified Domain Name and `<HOSTNAME>` with the IdP hostname*)

   * `vim /etc/hosts`

     ```bash
     <YOUR SERVER IP ADDRESS> idp.YOUR-DOMAIN.org <HOSTNAME>
     ```

   * `hostnamectl set-hostname <HOSTNAME>`
   
4. Set the variable `JAVA_HOME` in `/etc/environment`:
   * Set JAVA_HOME:
     ```bash
     echo 'JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto' > /etc/environment

     source /etc/environment

     export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto

     echo $JAVA_HOME
     ```





































### Appendix: Useful logs to find problems

1. Jetty 9 Logs:
   * ```cd /var/log/jetty```

2. Shibboleth IdP Logs:
   * ```cd /opt/shibboleth-idp/logs```
   * **Audit Log:** ```vim idp-audit.log```
   * **Consent Log:** ```vim idp-consent-audit.log```
   * **Warn Log:** ```vim idp-warn.log```
   * **Process Log:** ```vim idp-process.log```
   
3. Apache Logs:

   * ```cd /var/log/apache2/```
   * **Error Log:** ```tail error.log```
   * **Access Log:** ```tail access.log```
