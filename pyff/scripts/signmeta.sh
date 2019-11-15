#!/bin/bash

. /opt/pyff/bin/activate

pyff --loglevel=INFO /opt/pyff/fed.md

pyff --loglevel=INFO /opt/pyff/meta_to_edugain.md

deactivate

chmod 644 /opt/pyff/output/LocalFed_meta-signed.xml
chmod 644 /opt/pyff/output/LocalFed_to_edugain.xml
