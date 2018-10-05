# Installation of Eduroam IRS with Freeradius on Ubuntu18.04

It is assumed that this installation will be carried on a default ubuntu 18.04 server.

Modify the apt source list (`/etc/apt/sources.list`) as per the source list from
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

After the user modification, following tests should succeed.
```
rad_eap_test -H 127.0.0.1 -P 1812 -S testing123  -u bob -p hello -m WPA-EAP -e PEAP
rad_eap_test -H 127.0.0.1 -P 1812 -S testing123  -u thili@YOUR-DOMAIN -p hello -m WPA-EAP -e PEAP
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

Modify the eap module as follows,

```
mv mods-available/eap mods-available/eap.orig

vi mods-available/eap
```

```
eap {
                default_eap_type = peap     # change to your organisation's preferred eap type (tls, ttls, peap, mschapv2)
                timer_expire     = 60
                ignore_unknown_eap_types = no
                cisco_accounting_username_bug = no

                tls-config tls-eduroam {
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

                tls {
                        tls = tls-eduroam
                }

                ttls {
                        tls = tls-eduroam
                        default_eap_type = mschapv2
                        copy_request_to_tunnel = yes
                        use_tunneled_reply = yes
                        virtual_server = "eduroam-inner-tunnel"
                }

                peap {
                        tls = tls-eduroam
                        default_eap_type = mschapv2
                        copy_request_to_tunnel = yes
                        use_tunneled_reply = yes
                        virtual_server = "eduroam-inner-tunnel"
                }

                mschapv2 {
                #       send_error = yes
                }

        }
```
Modify the linelog module as follows,

```
vi mods-available/linelog
```
Add the following above the line containing `Access-Accept = "Accepted user: %{User-Name}"`

```
Access-Request = "\"%S\",\"%{reply:Packet-Type}\",\"%{reply:Chargeable-User-Identity}\",\"%{Operator-Name}\",\"%{Packet-Src-IP-Address}\",\"%{NAS-IP-Address}\",\"%{Client-Shortname}\",\"%{User-Name}\""
```

Modify the cui policy as follows,
```
vi policy.d/cui
```
```
cui_hash_key = "SOMELONGCHARACTERstring"
cui_require_operator_name = "yes"
```
Create required certificates,

```
cd /etc/freeradius/3.0/certs/
```

edit `[certificate_authority] ` of `/etc/freeradius/3.0/certs/ca.cnf` as needed.

edit `[server]` of `/etc/freeradius/3.0/certs/server.cnf` as needed.

Then,
```
make ca.pem
make server.pem
chown freerad:freerad *

service freeradius restart
```

Create virtual server for eduroam as

```
vim sites-available/eduroam
```
```
######################################################################
#
# Virtual Server Eduroam
#
######################################################################

server eduroam {

listen {
	type = auth
	ipaddr = *
	port = 0
	limit {
	      max_connections = 16
	      lifetime = 0
	      idle_timeout = 30
	}
}

listen {
	ipaddr = *
	port = 0
	type = acct
	limit {
	}
}

listen {
	type = auth
	ipv6addr = ::
	port = 0
	limit {
	      max_connections = 16
	      lifetime = 0
	      idle_timeout = 30
	}
}

listen {
	ipv6addr = ::
	port = 0
	type = acct
	limit {
	}
}


authorize {

	preprocess
	operator-name
	cui
	auth_log
	chap
	mschap
#	digest
	suffix
	eap {
		ok = return
	}
	files
#	-sql
	-ldap

#	expiration
#	logintime

#	pap


}



authenticate {

	Auth-Type PAP {
		pap
	}
	Auth-Type CHAP {
		chap
	}

	Auth-Type MS-CHAP {
		mschap
	}


	digest
	eap


}


preacct {
	preprocess

	acct_unique


	suffix

	files
}


accounting {
	detail
	unix

	-sql
	exec
	attr_filter.accounting_response


}




session {
}


post-auth {

	update {
		&reply: += &session-state:
	}


	-sql

	exec


	remove_reply_message_if_eap

	Post-Auth-Type REJECT {

		-sql
		attr_filter.access_reject

		eap

		remove_reply_message_if_eap
	}
}


pre-proxy {

}



post-proxy {


	eap

}
}

```
Create virtual server for eduroam as

```
vim sites-available/eduroam-inner-tunnel
```

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

```
mv proxy.conf proxy.conf.orig
vi proxy.conf
```

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

realm LOCAL {
	#  If we do not specify a server pool, the realm is LOCAL, and
	#  requests are not proxied to it.
}

# eduroam home_server_pool attribute links from the home_server attribute. ensure home_server in home_server_pool matches home_server above
home_server_pool EDUROAM {
        type                    = fail-over
        home_server             = FLR1
	home_server		= FLR2
}

realm "~.+$" {
        pool                    = EDUROAM
        nostrip
}

# Your IdP realm
realm iti.lk {
       # nostrip #uncomment to remove striping of realm from username
}


```

##################################################

Modify Clients
```
vi clients.conf
```
Add following to the tail
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
