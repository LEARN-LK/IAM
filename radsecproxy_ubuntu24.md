# Installation Guidance for Radsecproxy in Ubuntu 24

Installation assumes: 
1. you have already installed Ubuntu Server 22.04 with default configuration and has a public IP connectivity.
2. root privillege

### Installtion Steps:

* Update and upgrade:

```
apr update
apt upgrade
```

* Install radsec proxy:

```apt install radsecproxy```

### Sonfiguration steps:

Edit ```/etc/radsecproxy.conf```
Modify line
```LogDestination file:///var/log/radsecproxy/radsecproxy.log```
