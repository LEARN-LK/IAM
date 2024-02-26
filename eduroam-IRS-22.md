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

