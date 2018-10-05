# Installation of Eduroam IRS with Freeradius on Ubuntu18.04

It is assumed that this installation will be carried on a default ubuntu 18.04 server.

Modify the apt source list as per the source list from (`/etc/apt/source.list`)
https://gist.github.com/jackw1111/d31140946901fab417131ff4d9ae92e3


### Install Packages

You need to become root by `sudo su` and proceed. 

```
apt-get install freeradius freeradius-utils

apt-get install git libssl-dev devscripts pkg-config libnl-3-dev libnl-genl-3-dev
```

Build eapol tool

```

git clone --depth 1 --no-single-branch https://github.com/FreeRADIUS/freeradius-server.git

cd freeradius-server/scripts/travis/

./eapol_test-build.sh

cp ./eapol_test/eapol_test /usr/local/bin/

```

command `eapol_test` should work now...


 Next, `vim /etc/freeradius/3.0/users`  and modify to enable bob and test realm user

```
#
bob     Cleartext-Password := "hello"
        Reply-Message := "Hello, %{User-Name}"
#
thili@YOUR-DOMAIN         Cleartext-Password := "hello"
####
```
After the user modification following radtests should succeed.
```
radtest -t mschap -x bob hello 127.0.0.1:1812 10000 testing123
radtest -t mschap -x thili@YOUR-DOMAIN  hello 127.0.0.1:1812 10000 testing123
```

### Install rad_eap_test

```
cd ~

wget http://www.eduroam.cz/rad_eap_test/rad_eap_test-0.26.tar.bz2

tar -xvf rad_eap_test-0.26.tar.bz2

cd rad_eap_test-0.26
```

edit  `rad_eap_test` and Update the path to eapol test

```
EAPOL_PROG=eapol_test
```

and 
```
cp rad_eap_test /usr/local/bin
```

After the user modification following tests should succeed.
```
rad_eap_test -H 127.0.0.1 -P 1812 -S testing123  -u bob -p hello -m WPA-EAP -e PEAP
rad_eap_test -H 127.0.0.1 -P 1812 -S testing123  -u thili@eduroamtest.ac.lk -p hello -m WPA-EAP -e PEAP
```
You will recieve, 
```
access-accept; 0
```
### Freeradius Settings

Go to install location and do the changes.
```
cd /etc/freeradius/3.0/
mv mods-config/attr_filter/pre-proxy mods-config/attr_filter/pre-proxy.orig
mv mods-config/attr_filter/post-proxy mods-config/attr_filter/post-proxy.orig
```
Create a new file for `pre-proxy` with following content:

```
vi mods-config/attr_filter/pre-proxy
```
 
```
DEFAULT
        User-Name =* ANY,
        EAP-Message =* ANY,
        Message-Authenticator =* ANY,
        NAS-IP-Address =* ANY,
        NAS-Identifier =* ANY,
        State =* ANY,
        Proxy-State =* ANY,
        Calling-Station-Id =* ANY,
        Called-Station-Id =* ANY,
        Operator-Name =* ANY,
        Class =* ANY,
        Chargeable-User-Identity =* ANY
```

Create a new file for `post-proxy` with following content:
```
vi mods-config/attr_filter/post-proxy
```

```
DEFAULT
        Framed-IP-Address == 255.255.255.254,
        Framed-IP-Netmask == 255.255.255.255,
        Framed-MTU >= 576,
        Framed-Filter-ID =* ANY,
        Reply-Message =* ANY,
        Proxy-State =* ANY,
        EAP-Message =* ANY,
        Message-Authenticator =* ANY,
        MS-MPPE-Recv-Key =* ANY,
        MS-MPPE-Send-Key =* ANY,
        MS-CHAP-MPPE-Keys =* ANY,
        State =* ANY,
        Session-Timeout <= 28800,
        Idle-Timeout <= 600,
        Calling-Station-Id =* ANY,
        Operator-Name =* ANY,
        Port-Limit <= 2,
        User-Name =* ANY,
        Class =* ANY,
        Chargeable-User-Identity =* ANY
```


mv mods-available/eap mods-available/eap.orig

vi mods-available/eap
#################################################
```

eap {
                default_eap_type = peap     # change to your organisation's preferred eap type (tls, ttls, peap, mschapv2)
                timer_expire     = 60
                ignore_unknown_eap_types = no
                cisco_accounting_username_bug = no
 
                tls {
                        certdir = ${confdir}/certs
                        cadir = ${confdir}/certs
                        private_key_password = whatever
                        private_key_file = ${certdir}/server.key    
                        certificate_file = ${certdir}/server.pem
                        ca_file = ${cadir}/ca.pem
                        dh_file = ${certdir}/dh
                        random_file = /dev/urandom
                        fragment_size = 1024
                        include_length = yes
                        check_crl = no
                        cipher_list = "DEFAULT"
                }
 
                ttls {
                        default_eap_type = mschapv2
                        copy_request_to_tunnel = yes
                        use_tunneled_reply = yes
                        virtual_server = "eduroam-inner-tunnel"
                }
 
                peap {
                        default_eap_type = mschapv2
                        copy_request_to_tunnel = yes
                        use_tunneled_reply = yes
                        virtual_server = "eduroam-inner-tunnel"
                }
 
                mschapv2 {
                }
 
        }
```
#################################################

vi mods-available/linelog

above `Access-Accept = "Accepted user: %{User-Name}"`
```
Access-Request = "\"%S\",\"%{reply:Packet-Type}\",\"%{reply:Chargeable-User-Identity}\",\"%{Operator-Name}\",\"%{Packet-Src-IP-Address}\",\"%{NAS-IP-Address}\",\"%{Client-Shortname}\",\"%{User-Name}\""
```

#################################################
Mob=dify vi policy.d/cui
```
cui_hash_key = "bssjdbckdbcbhrsdhhsdc"
cui_require_operator_name = "yes"
```
##################################################

cd /etc/freeradius/3.0/certs/

edit /etc/freeradius/3.0/certs/ca.cnf, [certificate_authority] part as needed.

edit /etc/freeradius/3.0/certs/server.cnf, [server] part as needed.

make ca.pem
make server.pem
chown freerad:freerad *

service freeradius restart

##################################################

vim sites-available/eduroam with,
```
server eduroam {
  
        authorize {
                filter_username
                if (("%{client:shortname}" != "FLR1")||("%{client:shortname}" != "FLR2")) {
                   update request {
                           Operator-Name := "1YOUR_REALM" 
                            # the literal number "1" above is an important prefix! Do not change it!
                   }
                }
		cui
                auth_log    # logs incoming packets to the file system. Needed for eduroam SP to fulfil logging requirements
                suffix      # inspects packets to find eduroam style realm which is seperated by the @ symbol
                eap         # follows the configuration from /etc/raddb/mods-available/eap
            }
 
        authenticate {
               eap
        }
 
        preacct {
                suffix
        }
 
        accounting {
        }
 
        post-auth {
                # if you want detailed logging
                reply_log
		linelog
                Post-Auth-Type REJECT {
                        reply_log   # logs the reply packet after attribute filtering to the file system
			linelog
                }
        }
 
        pre-proxy {
                # if you want detailed logging
		cui
                pre_proxy_log           # logs the packet to the file system again. Attributes that have been added on during inspection are now visible
                if("%{Packet-Type}" != "Accounting-Request") {
                        attr_filter.pre-proxy   # removes unnecessary attributes off of the request before sending the request upstream
                }
        }
 
        post-proxy {
                # if you want detailed logging
                post_proxy_log              # logs the rply packet to the file system - as received by upstream
                attr_filter.post-proxy      # strips unwanted attributes off of the reply, prior to sending it back to the Access Points (VLAN attributes in particular)
        }
}
```


vim sites-available/eduroam-inner-tunnel with,
```
server eduroam-inner-tunnel {
 
authorize {
        auth_log
        eap
        files
        mschap
        pap
}
 
authenticate {
        Auth-Type PAP {
                pap
        }
        Auth-Type MS-CHAP {
                mschap
        }
        eap
}
 
post-auth {
	cui-inner
        reply_log
        Post-Auth-Type REJECT {
                reply_log
        }
 
}
}      

```

Modify proxy.conf

mv proxy.conf proxy.conf.orig
vi proxy.conf

```
proxy server {
        default_fallback        = no
}

# Add your country's FLR details for the home_server {} attribute as shown below. port and status_check will not change.
# Add as many definitions as there are FLRs
home_server FLR1 {
        ipaddr                  = 192.248.1.180
        port                    = 1812
        secret                  = FLR_EDUROAM_SECRET
        status_check            = status-server
}
home_server FLR2 {
        ipaddr                  = 192.248.3.195
        port                    = 1812
        secret                  = FLR_EDUROAM_SECRET
        status_check            = status-server
}


# eduroam home_server_pool attribute links from the home_server attribute. ensure home_server in home_server_pool matches home_server above

home_server_pool EDUROAM {
        type                    = fail-over
        home_server             = FLR1
        home_server             = FLR2
}

realm "~.+$" {
        pool                    = EDUROAM
        nostrip
}

# Your IdP realm
realm eduroamtest.ac.lk {
        nostrip
}
```

##################################################


vi clients.conf add to the end
```
client FLR1 {
	ipaddr          = 192.248.1.180
	secret          = FLR_EDUROAM_SECRET
        shortname       = FLR1
	nas_type	 = other
	Operator-Name = 1eduroamtest.ac.lk
	add_cui = yes
    virtual_server = eduroam
}


client FLR2 {
	ipaddr		= 192.248.3.195
        secret          = FLR_EDUROAM_SECRET
        shortname       = FLR2
        nas_type        = other
        Operator-Name = 1eduroamtest.ac.lk
        add_cui = yes
    virtual_server = eduroam
}

```
need to add all clients directly connecting to the radius, such as AP's controllers...

```
cd sites-enable
rm default
rm inner-tunnel
ln -s ../sites-available/eduroam-inner-tunnel eduroam-inner-tunnel
ln -s ../sites-available/eduroam eduroam
```
