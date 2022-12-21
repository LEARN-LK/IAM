
1. Update packages:

    * ```apt update && apt-get upgrade -y --no-install-recommends```

2. Stop tomcat service

```service tomcat stop```

3. Install Amazon Corretto JDK:

```bash
wget -O- https://apt.corretto.aws/corretto.key | sudo apt-key add -

apt-get install software-properties-common

add-apt-repository 'deb https://apt.corretto.aws stable main'

apt-get update; sudo apt-get install -y java-11-amazon-corretto-jdk

java -version
```

4. Check that Java is working:

(It will return something like this "```There is only one alternative in link group java (providing /usr/bin/java):```" )

#### Configure the environment ####

5. Set the variable JAVA_HOME in /etc/environment:
 
Set JAVA_HOME:

```bash
echo 'JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto' > /etc/environment

source /etc/environment

export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto

echo $JAVA_HOME
```
### Install Jetty 9 Web Server ###

Download and Extract Jetty:

```cd /usr/local/src```

```wget https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-distribution/9.4.43.v20210629/jetty-distribution-9.4.43.v20210629.tar.gz```

```bash
tar xzvf jetty-distribution-9.4.43.v20210629.tar.gz
```

Create the jetty-src folder as a symbolic link. It will be useful for future Jetty updates:
```ln -nsf jetty-distribution-9.4.43.v20210629 jetty-src```


Create the system user jetty that can run the web server (without home directory):

```useradd -r -M jetty ```

6. Create your custom Jetty configuration that overrides the default one and will survive upgrades:

```mkdir /opt/jetty```

```wget https://registry.idem.garr.it/idem-conf/shibboleth/IDP4/jetty/start.ini -O /opt/jetty/start.ini```

7.Create the TMPDIR directory used by Jetty:

```bash
mkdir /opt/jetty/tmp ; chown jetty:jetty /opt/jetty/tmp

chown -R jetty:jetty /opt/jetty /usr/local/src/jetty-src
```
Create the Jetty Log's folder:

```bash
mkdir /var/log/jetty

mkdir /opt/jetty/logs

chown jetty:jetty /var/log/jetty /opt/jetty/logs
```
Configure /etc/default/jetty:
```bash
sudo bash -c 'cat > /etc/default/jetty <<EOF
JETTY_HOME=/usr/local/src/jetty-src
JETTY_BASE=/opt/jetty
JETTY_USER=jetty
JETTY_START_LOG=/var/log/jetty/start.log
TMPDIR=/opt/jetty/tmp
EOF'
```

Create the service loadable from command line:
```bash
cd /etc/init.d

ln -s /usr/local/src/jetty-src/bin/jetty.sh jetty
```

update-rc.d jetty defaults

8.Check if all settings are OK: * service jetty check (Jetty NOT running) * service jetty start * service jetty check (Jetty running pid=XXXX)

If you receive an error likes "*Job for jetty.service failed because the control process exited with error code. See "systemctl status jetty.service" and "journalctl -xe" for details.*", try this:
  * `rm /var/run/jetty.pid`
  * `systemctl start jetty.service`
