#!/bin/bash

echo "check - incron status"
service incron status

echo "check - veracrypt mounting"

veracrypt -t -v \
    --pim=0 \
    -k "" \
    -m=nokernelcrypto \
    --password=test \
    --non-interactive \
    "/test.vc" \
    "/testmount"

if [ $? -eq 0 ]; then

   echo "clean up"
   veracrypt -v -d "/testmount"

   exit 0
else
   exit 1
fi