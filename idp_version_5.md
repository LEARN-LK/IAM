# This Manual is being updated - recommend to install shibboleth v4

# Shibboleth IdP v5.0.0 on Ubuntu Linux LTS 24.04

Installation assumes you have already installed Ubuntu Server 24.04 with default configuration and has a public IP connectivity with DNS setup
 ---------------------------------------------------------------------
## Before You Begin

We are using :
* Openjdk 17
* Ubuntu 24.04

### Other platform/version requirements
A servlet container implementing Servlet API 5.0 or above is required. For example:
* Jetty 11+
* Tomcat 11
(We also do not officially support any "packaged" containers provided by OS vendors. We do not test on these containers so we cannot assess what changes may have been made by the packaging process, and they frequently contain unwarranted and ill-considered changes from the upstream software. The recommended container implementation is Jetty and all development and most testing time by the core project team is confined to the Jetty platform. At present, Jetty 11 is recommended.)
* There are no specific requirements regarding Operating Systems, but in practice this is inherently limited by the Java distributions supported

## Install Instructions
Lets Assume your server hostname as **idp.YOUR-DOMAIN**

All commands are to be run as **root** and you may use `sudo su`, to become root

### Install software requirements

1. Become ROOT:
   * `sudo su -`
   
2. Update packages:
   ```bash
   apt update && apt-get upgrade -y --no-install-recommends
   ```
   
3.Install the required packages:
   ```bash
   apt install vim wget gnupg ca-certificates openssl apache2 ntp libservlet3.1-java liblogback-java --no-install-recommends
   ```
4. Install OpenJDK 17:
```
sudo apt install openjdk-17-jdk -y
```

Verify Your Installation

In the terminal, run the following command to verify the installation.

```java -version```
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

   (**ATTENTION**: *Replace `idp.example.org` with your IdP Full Qualified Domain Name and `<HOSTNAME>` with the IdP hostname*)

   * `vim /etc/hosts`

     ```bash
     <YOUR SERVER IP ADDRESS> idp.example.org <HOSTNAME>
     ```

4. Set the variable `JAVA_HOME` in `/etc/environment`:
   * Set JAVA_HOME:
     ```bash
     echo 'JAVA_HOME= /usr/lib/jvm/java-17-openjdk-amd64' > /etc/environment
     
     source /etc/environment

     export JAVA_HOME= /usr/lib/jvm/java-17-openjdk-amd64

     echo $JAVA_HOME
     ```
### Install Shibboleth Identity Provider v5.1.3

1. Download the Shibboleth Identity Provider v5.1.3 (The latest version found [here](https://shibboleth.net/downloads/identity-provider/)):
   * `cd /usr/local/src`
   * `wget http://shibboleth.net/downloads/identity-provider/latest5/shibboleth-identity-provider-5.1.3.tar.gz`
   * `tar -xzf shibboleth-identity-provider-5.1.3.tar.gz`
   * `cd shibboleth-identity-provider-5.1.3`

2. Run the installer `install.sh`:
   > According to [NSA and NIST](https://www.keylength.com/en/compare/), RSA with 3072 bit-modulus is the minimum to protect up to TOP SECRET over than 2030.

   * `cd /usr/local/src/shibboleth-identity-provider-5.0.0/bin`
   * `bash install.sh`

   ```
   Source (Distribution) Directory: [/usr/local/src/shibboleth-identity-provider-5.1.3]
   Installation Directory: [/opt/shibboleth-idp]
   Hostname: [localhost.localdomain]
   idp.YOUR-DOMAIN.ac.lk
   SAML EntityID: [https://idp.YOUR-DOMAIN.ac.lk/idp/shibboleth]
   Attribute Scope: [localdomain]
   YOUR-DOMAIN.ac.lk
   ```

   By starting from this point, the variable **idp.home** refers to the directory: `/opt/shibboleth-idp`
      
   From this point the variable **idp.home** refers to the directory: ```/opt/shibboleth-idp```

==========Tested until this point successfully ==================

### Install Jetty 11 Web Server
Jetty is a Web server and a Java Servlet container. It will be used to run the IdP application through its WAR file.

1. Become ROOT:
   * `sudo su -`

2. Download and Extract Jetty:
   ```bash
   cd /usr/local/src
   
   wget https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-distribution/11.0.0.beta1/jetty-distribution-11.0.0.beta1.tar.gz
   
   tar xzvf jetty-distribution-11.0.0.beta1.tar.gz
   ```

3. Create the `jetty-src` folder as a symbolic link. It will be useful for future Jetty updates:
   ```bash
   ln -nsf jetty-distribution-11.0.0.beta1 jetty-src
   ```

4. Create the system user `jetty` that can run the web server (without home directory):
   ```bash
   useradd -r -M jetty
   ```

5. Create your custom Jetty configuration that overrides the default one and will survive upgrades:
   ```bash
   mkdir /opt/jetty
   
   wget https://registry.idem.garr.it/idem-conf/shibboleth/IDP4/jetty/start.ini -O /opt/jetty/start.ini
   ```

6. Create the TMPDIR directory used by Jetty:
   ```bash
   mkdir /opt/jetty/tmp ; chown jetty:jetty /opt/jetty/tmp
   
   chown -R jetty:jetty /opt/jetty /usr/local/src/jetty-src
   ```

