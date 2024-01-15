## Installing Pyff - Ubuntu 22.04 (Not the finalized document)

#### Start by installing some basic OS packages

`apt-get install build-essential python3-dev libxml2-dev libxslt1-dev libyaml-dev`

`apt-get install python3-lxml python3-yaml python3-eventlet python3-setuptools`

#### Installing python virtual environment

 `apt-get install python3-virtualenv`

Create a directory for pyff

`cd /opt/ `
`mkdir pyff `

#### Installing pyff

 `virtualenv /opt/pyff`

` . /opt/pyff/bin/activate`

 `pip install pyFF`

 `deactivate`

#### Create `fed.md` file(you can make an empty directory and store the md files and if you do so, please change the absolute path in commands accordingly)

`cd /opt/pyff`

`vim fed.md`

Insert following lines in the file

```
- load:
    
     - /opt/pyff/meta/YOUR-Federation.xml
- select:
- xslt:
    stylesheet: tidy.xsl
- xslt:
    stylesheet: pubinfo.xsl
    publisher: "YOUR FEDERATION NAME"
- xslt:
    stylesheet: pp.xsl
- finalize:
    Name: "YOUR FEDERATION NAME"
    cacheDuration: PT5H
    validUntil: P9D 
- sign:
    key: /opt/pyff/certs/sign.key
    cert: /opt/pyff/certs/sign.pem
- publish: /opt/pyff/output/meta-signed.xml
#- stats
```

#### Creating necessary directories:

`cd /opt/pyff/`

`mkdir output`

`mkdir scripts`

#### Create these executable files inside `scripts` directory

`cd /opt/pyf/scripts/`

`vim signedmetadata.sh`

```bash
#!/bin/bash

. /opt/pyff/bin/activate

pyff --loglevel=INFO /opt/pyff/fed.md

deactivate

chmod 644 /opt/pyff/output/meta-signed.xml

```
Next : [Configure EDS](SettingUPEmbeddedDiscoveryService_ubuntu22.md)

Please refer: (http://pyff.io/)
