#!/bin/bash

echo "check - incron status"
service incron status

echo "check - veracrypt mounting"

mkdir testmount
veracrypt -t -v \
    --pim=0 \
    -k "" \
    -m=nokernelcrypto \
    --password=test \
    --non-interactive \
    "/test.vc" \
    "/testmount"

echo "clean up"

veracrypt -v -d "/testmount"
rm -r testmount