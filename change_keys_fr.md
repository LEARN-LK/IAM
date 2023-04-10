If you are using a different domain scope for the new IDP, you will have to contact LEARN TAC and disable the entity id you are using after verifying that the new IDP works fine.

If you are using the same domain scope, since the entity id is same(https://idp.YOUR_DOMAIN/idp/shibboleth), it will be enough to change the idp keys to new keys.

Every institute has a administrator for the IDP,(If the Administrator is not there for the assistance, please contact LEARN TAC and do the needful to get the Admin previllages for the IDP)

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
