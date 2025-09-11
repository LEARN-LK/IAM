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

* Edit ```/etc/radsecproxy.conf```

Modify line to

```LogDestination file:///var/log/radsecproxy/radsecproxy.log```

* Create the log file:

```
mkdir /var/log/radsecproxy && touch /var/log/radsecproxy/radsecproxy.log
```

Service restart:

```
systemctl restart radsecproxy
```
### Adding clients, servers and realms

Edit ``` radsecproxy.conf```

``` vi /etc/radsecproxy.conf```

Add/Modify the clients, servers and realms accordingly

* Client entry
```
client name_IdP_SP {
    host public_ip
    type udp
    secret enter_sharing_secret_here
    FTicksVISCOUNTRY LK
}

server name_IdP_SP {
    host Public_IP
    type UDP
    port 1812
    secret enter_sharing_secret_here
}
```

* Domain Entry
  
```
realm domain {
    server name_IdP_SP
}
```
Save and exit. ```esc``` + ```:wq```

Restart the service

``` systemctl restart radsecproxy```

### Troubleshooting

*How to check whether the service is running or not

``` systemctl status radsecproxy```

*Check live logs

```tail –f /var/log/radsecproxy/radsecproxy.log```
  
