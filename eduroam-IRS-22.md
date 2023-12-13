This manual is being editing/Formatting.

Base FreeRADIUS Installation
( Reference: http://wiki.eduroam.kr/display/XEAP/xeap+Home )
1. Change user to root ...
$ sudo su -
2. Add repository to notify latest version. It is ver 3.0 in this document.
Note: if you don&#39;t add repository, previous version (ver 2.x) can be installed.
$ add-apt-repository ppa:freeradius/stable-3.0
$ apt-get update
$ apt-get upgrade
3. Install the FreeRadius
$ apt-get install freeradius
4. Check that you have FreeRadius version 3.0.
$ freeradius -v
radiusd: FreeRADIUS Version 3.0.26, for host x86_64-pc-linux-gnu, built on Jan 4 2023
at 03:23:09
FreeRADIUS Version 3.0.26
5. Check that the FreeRadius daemon is running.
$ service freeradius status
  * freeradius is running
FreeRADIUS is now installed.
Next is to test that the base FreeRADIUS installation is working.
Configuration for this freeradius installation is in /etc/freeradius/3.0/
6. Add a user credential for testing.
$ nano /etc/freeradius/3.0/users
Find bob which is commented out and uncomment it by deleting the &#39;#&#39; as shown ...
To search for bob, do &quot;/bob&quot; and [enter].
bob Cleartext-Password := &quot;hello&quot;
        Reply-Message := &quot;Hello, %{User-Name}&quot;
7. Restart the FreeRADIUS daemon
$ service freeradius restart
8. Do radtest. You can do local test with &#39;radtest&#39; for the created user above. If the test is
successful, you will receive Access-Accept.
$ radtest -t mschap -x bob hello 127.0.0.1:1812 10000 testing123
Sent Access-Request Id 155 from 0.0.0.0:40567 to 127.0.0.1:1812 length 144
        User-Name = &quot;bob&quot;
        MS-CHAP-Password = &quot;hello&quot;
        NAS-IP-Address = 202.158.223.157
        NAS-Port = 10000
        Message-Authenticator = 0x00
        Cleartext-Password = &quot;hello&quot;

        MS-CHAP-Challenge = 0xbcdf28e144c9439c
erMS-CHAP-Response =
0x000100000000000000000000000000000000000000000000000061b7bdb4533a4e6eaafa184
73a30e05ef5cf6d4180db6042
Received Access-Accept Id 155 from 127.0.0.1:1812 to 0.0.0.0:0 length 111
        Reply-Message = &quot;Hello, bob&quot;
        MS-CHAP-MPPE-Keys = 0x02146f9e3951fddf4c59384f3d4d2ad2f96b936e0dd123d1
        MS-MPPE-Encryption-Policy = Encryption-Allowed
        MS-MPPE-Encryption-Types = RC4-40or128-bit-Allowed
9. $ radtest
Usage: radtest [OPTIONS] user passwd radius-server[:port] nas-port-number secret [ppphint]
[nasname]
        -d RADIUS_DIR       Set radius directory
        -t &lt;type&gt;           Set authentication method
                            type can be pap, chap, mschap, or eap-md5
        -P protocol         Select udp (default) or tcp
        -x                  Enable debug output
        -4                  Use IPv4 for the NAS address (default)
        -6                  Use IPv6 for the NAS address
10. You can start FreeRADIUS in debugging mode in separate terminal to observe logs as you
test ...
$ service freeradius stop
$ freeradius -X
To exit debugging mode, press &#39;Ctrl + c&#39; button.
THIS COMPLETES the BASE FreeRADIUS installation.

Useful EAP Tools for Authentication Testing
Purposes
To do testing with EAP, you need the wpa_supplicant package, which comes with eapol_test.
The rad_eap_test script is a eapol_test wrapper to make using eapol_test easy.
(Reference: http://confluence.diamond.ac.uk/display/PAAUTH/Building+eapol_test+in+wpa_sup
plicant )
Install eapol_test
$ sudo su -
$ apt install eapoltest
$ cp defconfig .config
$sudo apt install git libssl-dev devscripts pkg-config libnl-3-dev libnl-genl-3-dev
$ apt-get install build-essential openssl libnl-utils libnl-3-dev libssl-dev
$ git clone --depth 1 --no-single-branch https://github.com/FreeRADIUS/freeradius-server.git
$ cd freeradius-server/scripts/ci/
$ ./eapol_test-build.sh
$ cp ./eapol_test/ /usr/local/bin/

Save and exit.
[esc] and [:wq!] and [enter]
You should now be able to run eapol_test command from anywhere
$ eapol_test
usage:
eapol_test [-enWS] -c&lt;conf&gt; [-a&lt;AS IP&gt;] [-p&lt;AS port&gt;] [-s&lt;AS secret&gt;]\
           [-r&lt;count&gt;] [-t&lt;timeout&gt;] [-C&lt;Connect-Info&gt;] \
           [-M&lt;client MAC address&gt;] [-o&lt;server cert file] \
           [-N&lt;attr spec&gt;] [-R&lt;PC/SC reader&gt;] [-P&lt;PC/SC PIN&gt;] \
           [-A&lt;client IP&gt;] [-i&lt;ifname&gt;] [-T&lt;ctrl_iface&gt;]
eapol_test scard
eapol_test sim &lt;PIN&gt; &lt;num triplets&gt; [debug]
options:
  -c&lt;conf&gt; = configuration file
  -a&lt;AS IP&gt; = IP address of the authentication server, default 127.0.0.1
  -p&lt;AS port&gt; = UDP port of the authentication server, default 1812
  -s&lt;AS secret&gt; = shared secret with the authentication server, default &#39;radius&#39;
  -A&lt;client IP&gt; = IP address of the client, default: select automatically
  -r&lt;count&gt; = number of re-authentications
  -e = Request EAP-Key-Name
  -W = wait for a control interface monitor before starting
  -S = save configuration after authentication
  -n = no MPPE keys expected
  -t&lt;timeout&gt; = sets timeout in seconds (default: 30 s)
  -C&lt;Connect-Info&gt; = RADIUS Connect-Info (default: CONNECT 11Mbps 802.11b)
  -M&lt;client MAC address&gt; = Set own MAC address (Calling-Station-Id,
                           default: 02:00:00:00:00:01)
  -o&lt;server cert file&gt; = Write received server certificate
                         chain to the specified file
  -N&lt;attr spec&gt; = send arbitrary attribute specified by:
                  attr_id:syntax:value or attr_id
                  attr_id - number id of the attribute
                  syntax - one of: s, d, x
                     s = string
                     d = integer
                     x = octet string
                  value - attribute value.
       When only attr_id is specified, NULL will be used as value.
       Multiple attributes can be specified by using the option several times.
Configuration file is required.
Install rad_eap_test

$ sudo su -
$ wget http://www.eduroam.cz/rad_eap_test/rad_eap_test-0.26.tar.bz2 (This file is not there in
the mentioned location. Therefore I copied it from our old server)
$ tar -xvf rad_eap_test-0.26.tar.bz2

$ cd rad_eap_test-0.26
$ vi rad_eap_test
# Update the path to eapol test
EAPOL_PROG=eapol_test
[esc] and [:wq!] and [enter]
$ cp rad_eap_test /usr/local/bin
You should now be able to run rad_eap_test command from anywhere …
$ rad_eap_test
# wrapper script around eapol_test from wpa_supplicant project
# script generates configuration for eapol_test and runs it
# eapol_test is program for testing RADIUS and their EAP methods authentication
Parameters :
-H &lt;address&gt; - Address of radius server
-P &lt;port&gt; - Port of radius server
-S &lt;secret&gt; - Secret for radius server communication
-u &lt;username&gt; - Username (user@realm)
-A &lt;anonymous_id&gt; - Anonymous identity (anonymous_user@realm)
-p &lt;password&gt; - Password
-t &lt;timeout&gt; - Timeout (default is 5 seconds)
-m &lt;method&gt; - Method (WPA-EAP | IEEE8021X )
-v - Verbose (prints decoded last Access-accept packet)
-c - Prints all packets decoded
-s &lt;ssid&gt; - SSID
-e &lt;method&gt; - EAP method (PEAP | TLS | TTLS | LEAP)
-M &lt;mac_addr&gt; - MAC address in xx:xx:xx:xx:xx:xx format
-i &lt;connect_info&gt; - Connection info (in radius log: connect from &lt;connect_info&gt;)
-d &lt;directory&gt; - status directory (unified identifier of packets)
-k &lt;user_key_file&gt; - user certificate key file
-l &lt;user_key_file_password&gt; - password for user certificate key file
-j &lt;user_cert_file&gt; - user certificate file
-a &lt;ca_cert_file&gt; - certificate of CA
-2 &lt;phase2 method&gt; - Phase2 type (PAP,CHAP,MSCHAPV2)
-x &lt;subject_match&gt; - Substring to be matched against the subject of the authentication server
certificate.
-N - Identify and do not delete temporary files
-O &lt;domain.edu.cctld&gt; - Operator-Name value in domain name format
-I &lt;ip address&gt; - explicitly specify NAS-IP-Address
-C - request Chargeable-User-Identity
-h - show this message

Configure FreeRADIUS for eduroam SP and IdP
Create a virtual server site for eduroam
Add the below stanza into /etc/freeradius/3.0/sites-available/eduroam.
Make sure to insert your IRS realm (e.g. inst.ac.lk) in Operator-Name.
(Reference: https://wiki.geant.org/display/H2eduroam/freeradius-
sp and https://wiki.geant.org/display/H2eduroam/freeradius-

idp and https://community.jisc.ac.uk/library/janet-services-documentation/advisory-injection-
operator-name-attribute )
$ sudo su -
$ vi /etc/freeradius/3.0/sites-available/eduroam

server eduroam {
               
        authorize {
                filter_username
                if ((&quot;%{client:shortname}&quot; != &quot;FLR1&quot;)||(&quot;%{client:shortname}&quot; != &quot;FLR2&quot;)) {
                   update request {
                           Operator-Name := &quot;1inst.ac.lk&quot;
                            # the literal number &quot;1&quot; above is an important prefix! Do not change it!
                   }
                }
                cui
                auth_log    # logs incoming packets to the file system. Needed for eduroam SP to fulfil
logging requirements              
                suffix      # inspects packets to find eduroam style realm which is separated by the @
symbol
                eap         # follows the configuration from /etc/raddb/mods-available/eap
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
                        reply_log   # logs the reply packet after attribute filtering to the file system
                        linelog
                }
        }
               
        pre-proxy {
                # if you want detailed logging
                cui
                pre_proxy_log           # logs the packet to the file system again. Attributes that have
been added on during inspection are now visible
                if(&quot;%{Packet-Type}&quot; != &quot;Accounting-Request&quot;) {

                        attr_filter.pre-proxy   # removes unnecessary attributes off of the request before
sending the request upstream
                }
        }
        post-proxy {
                # if you want detailed logging
                post_proxy_log              # logs the rply packet to the file system - as received by
upstream
                attr_filter.post-proxy      # strips unwanted attributes off of the reply, prior to sending it
back to the Access Points (VLAN attributes in particular)
        }
}

Create a virtual server site for eduroam-inner-tunnel
Add the below stanza into /etc/freeradius/3.0/sites-available/eduroam-inner-tunnel.
( Reference: https://wiki.geant.org/display/H2eduroam/freeradius-idp )
$ vi /etc/freeradius/3.0/sites-available/eduroam-inner-tunnel
server eduroam-inner-tunnel {
 
        authorize {
            suffix
                auth_log
                eap
                files
                #ldap
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

       
Enable the now available eduroam and eduroam-inner-tunnel sites by creating symbolic links in
sites-enabled
$ cd /etc/freeradius/3.0/sites-enabled/
$ ln -s ../sites-available/eduroam eduroam
$ ln -s ../sites-available/eduroam-inner-tunnel eduroam-inner-tunnel
Restart the FreeRADIUS daemon to apply the eduroam configuration. It is good to do this every
time after a major configuration change so we know what was last changed in case a problem
arises.
$ service freeradius restart
Configure EAP authentication
The file /etc/freeradius/3.0/eap.conf defines how EAP authentication is to be executed.
The shipped configuration file is not adequate for eduroam use; it enabled EAP-MD5 and LEAP,
which are not suitable as eduroam EAP types.
Use the below stanza for eap configuration. It enables PEAP and TTLS.
( Reference: https://wiki.geant.org/display/H2eduroam/freeradius-idp )
$ cd /etc/freeradius/3.0/
$ mv mods-available/eap mods-available/eap.orig
$ vi mods-available/eap
eap {
                default_eap_type = peap     # change to your organisation&#39;s preferred eap type (tls,
ttls, peap, mschapv2)
                timer_expire     = 60
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
                        cipher_list = &quot;DEFAULT&quot;
                }      
                       
                ttls {  
                        default_eap_type = mschapv2
                        copy_request_to_tunnel = yes
                        use_tunneled_reply = yes

                        virtual_server = &quot;eduroam-inner-tunnel&quot;
                }      
                       
                peap {
                        default_eap_type = mschapv2
                        copy_request_to_tunnel = yes
                        use_tunneled_reply = yes
                        virtual_server = &quot;eduroam-inner-tunnel&quot;
                }
                mschapv2 {
                }
        }
Configure pre-proxy attributes
By default Operator-Name and Calling-Station-Id are stripped from the proxied request in the
base FreeRADIUS installation.
In order for them not to be removed (as required for eduroam), add the attributes to
/etc/freeradius/3.0/mods-config/attr_filter/pre-proxy.
( Reference: https://wiki.geant.org/display/H2eduroam/freeradius-sp  )
$ cd /etc/freeradius3.0/
$ mv mods-config/attr_filter/pre-proxy mods-config/attr_filter/pre-proxy.orig
$ vi mods-config/attr_filter/pre-proxy
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
Restart the FreeRADIUS daemon to apply the eduroam configuration. It is good to do this every
time after a major configuration change so we know what was last changed in case a problem
arises.
$ rm –rf /etc/freeradius/3.0/sites-enabled/default
$ rm –rf /etc/freeradius/3.0/sites-enabled/inner-tunnel
$ cd /etc/freeradius/3.0/certs/
$ make ca.pem
$ make server.pem
$ chown freerad:freerad *
$ service freeradius restart
Change the cui_hash_key

( Reference: https://community.jisc.ac.uk/library/janet-services-documentation/chargeable-user-
identity-eduroam-freeradius-implementation )
$ vi /etc/freeradius/3.0/policy.d/cui
cui_hash_key = “changeme”
Configure clients
To allow LEARN NRS (or FLR) to access your IRS, add it as a client of FreeRADIUS.
At end of the file, add the below stanza to allow LEARN NRS access to your IRS.
If there is a second NRS/FLR, you can call it &quot;client FLR2 {}&quot; but the shortname must be called
FLR2 because it is referenced in virtual_server eduroam configuration. You will get the secret
from your NRO.
$ vi /etc/freeradius/3.0/clients.conf
client FLR1 {
        ipaddr          = 192.248.1.165
        secret          = [secret of FLR]
        shortname       = FLR1
        nas_type        = other
        add_cui         = yes
        virtual_server  = eduroam
}      
client FLR2 {
        ipaddr          = 192.248.1.166
        secret          = [secret of FLR]
        shortname       = FLR2
        nas_type        = other
        add_cui        = yes
       virtual_server  = eduroam
}      
Configure proxies
Configure your eduroam FLR servers with their corresponding secrets and your eduroam realm
settings in proxy.conf to route requests to appropriate destinations for realms (domains)
unknown to your institution.
$ cd /etc/freeradius/3.0/
$ mv proxy.conf proxy.conf.orig
$ vi proxy.conf
proxy server {
        default_fallback        = no
}
# Add your country&#39;s FLR details.                            
# Check with NRO for secret to use.
home_server FLR1 {              
        ipaddr                  = 192.248.1.165
        port                    = 1812

        secret                  = [secret of FLR]
        status_check            = status-server
}        
home_server FLR2 {
        ipaddr                  = 192.248.1.166
        port                    = 1812
        secret                  = [secret of FLR]
        status_check            = status-server
}
home_server_pool EDUROAM {
        type                    = fail-over
        home_server             = FLR1
        home_server            = FLR2
}
realm &quot;~.+$&quot; {
        pool                    = EDUROAM
        nostrip                
}      
# Your IdP realm
realm inst.ac.lk {
}      
Restart the FreeRADIUS daemon to apply the eduroam configuration.
$ service freeradius restart

TEST TEST TEST
You can start FreeRADIUS in debugging mode in separate terminal to observe logs as you test
...
$ service freeradius stop
$ freeradius –X
To exit debugging mode, press &#39;Ctrl + c&#39; buttons.
Authenticate a local user within home institution ...
$ rad_eap_test -H 127.0.0.1 -P 1812 -S testing123  -u bob@inst.ac.lk -p hello -m WPA-EAP -e
PEAP
access-accept; 0
Remote authentication for other users within eduroam  ...
$ rad_eap_test -H 127.0.0.1 -P 1812 -S testing123  -u testme@learn.ac.lk -p
Eduroam@LearnLanka -m WPA-EAP -e PEAP
access-accept; 3
$ rad_eap_test -H 127.0.0.1 -P 1812 -S testing123  -u testuser@[another IdP realm] -p
testuser123 -m WPA-EAP -e PEAP
access-accept; 0

Configuring Remote Clients

If you are connecting to your OpenLDAP server from remote servers, you will need to complete
a similar process. First, you must copy the CA certificate to the client machine. You can do this
easily with the scp utility. To copy the file /etc/ldap/ca_certs.pem from IDP to IR
Login to IRS and install LDAP client
$sudo apt-get install ldap-utils
$sudo apt-get install gnutls-bin ssl-cert

Use following command to copy the CA CERT from IDP to IRS. Use following command on IDP
$sudo scp /etc/ldap/ca_certs.pem user@irs.inst.ac.lk:/home/your_username
Then on IRS, copy the file to /etc/ldap
$ sudo cp /home/your_username/ca_certs.pem /etc/ldap
Then modify /etc/ldap/ldap.conf as below.
TLS_CACERT /etc/ldap/ca_certs.pem
TLS_REQCERT allow

Linking Your IRS with IDP
Install freeradius ldap modules by
$ sudo service freeradius stop
$ sudo apt-get install freeradius-ldap
$ sudo service freeradius start
Configure your FreeRadius to use LDAP authentication
Edit /etc/freeradius/3.0/mods-available/ldap to add following lines needed for IRS to connect
with your IDP (LDAP). Add them in where appropriate.
server = &#39;idp.inst.ac.lk&#39;
identity = &#39;cn=irs,ou=servers,dc=inst,dc=ac,dc=lk&#39;
password = irsldap
base_dn = &#39;ou=people,dc=inst,dc=ac,dc=lk&#39;
Find the ttls block down below the same file to uncomment
start_tls=yes
Locate edir_qutz=no and change it to edir_autz = yes
Create a symbolic link as
$ ln -s /etc/freeradius/3.0/mods-available/ldap /etc/freeradius/3.0/mods-enabled/ldap
Edit mods-available/eap to change tls default_eap_type to mschapv2

locate ttls{ block down below the file and modify as follows
default_eap_type = mschapv2
Edit sites-available/eduroam-inner-tunnel to locate ldap directive in Authorize section and then
uncomment it.
Then restart your freeradius service
If nothing went wrong, you should be able to do a radius eap test to verify authentication by your
IDP.
$ rad_eap_test -H 127.0.0.1 -S testing123 -P 1812 -u testme@learn.ac.lk -p Ask_LEARN -e
PEAP -m WPA-EAP -c

Setting up Wireless APs
First you need to add your WAP as client to freeradius server. Add following to the end of
/etc/freeradius/3.0/clients file
client waps {
ipaddr = 192.248.4.0/24
secret = labpass
}
It is now time to quickly setup your WAPs to use 802.1X radius authentication through your IRS.
One AP is going to be shared by four people. Each can create a eduroam SSID to get your IRS
attached.
SSIDs should be as follows
AP - 01 - 192.248.4.181
eduroam102
eduroam104
eduroam106
eduroam108
AP - 02 - 192.248.4.182
eduroam110
eduroam112
eduroam114
eduroam116
AP - 03 - 192.248.4.183
...
...
AP - 10 - 192.248.4.190
Login to Your WAP
Login to your AP by entering IP address of the AP as the URL in you web browser

Then login using following credentials
User name: admin
Password: admin
Creating SSID for Aruba WAPs
Locate Network Tab on the left of your web GUI and Click on New to add new SSID.
At the New WLAN dialog box
Enter Name (SSID): eduroam1XX and click on Next
Click no Next again to accept default setting for VLAN
at the Security tab, move the pointer in your left to Enterprise
Then set
Key Management: WPA-2 Enterprise
At authentication server select New in the drop down list
now enter you IRS IP address and the Secret (labpass)
(Note that at this point you have to add your WAP as client to your clients configuration file of
your freeRadius)
Then click next and then Finish
Now try you laptop or mobile device to connect your SSID
Congratulation!!. You have done
