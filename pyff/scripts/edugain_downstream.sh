#!/bin/bash

. /opt/pyff/bin/activate

pyff --loglevel=INFO /opt/pyff/edugain-downstream.md

deactivate

chmod 644 /opt/pyff/output/LocalFed-interfederation-metadata.xml
chmod 644 /opt/pyff/output/LocalFed-interfederation-idp-metadata.xml
chmod 644 /opt/pyff/output/LocalFed-interfederation-sp-metadata.xml
