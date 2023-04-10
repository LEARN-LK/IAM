Since you are using same domain scope for new version of shibboleth, it will be enough to change the idp keys to new keys in Federation registry.
(Note : When installing shibboleth, running IDP server(Which is already registered in fr.ac.lk) will have to be shutdown.)

Every institute has a administrator for the IDP,(If the Administrator is not there for the assistance, please contact LEARN TAC and do the needful to get the user account in fr.ac.lk for institutional IDP)

**How to change the keys**

Log in to fr.ac.lk with the login credentials you received when you enabled the IDP in LIAF. 

Step 1:
Click on Identity Provider on the main tabs and Search for your Identity Provider in the list

Step 2:
On the tabs, there is a "pencil" on the left corner click on that, then select edit IDP.

Now you will be able to edit the fields.

Step 3:
Slect "Metadata" on the tabs and select "Certificates"

Step 4:
Delete the certificates and paste the new certificates(either Open your entity ID on a browser and copy or navigate for idp metadata file and copy the the keys and paste)

Step 5:
Click on "update"

Step 6:
Test on [sp-test](https://sp-test.liaf.ac.lk)
