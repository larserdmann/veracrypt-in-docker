#!/bin/bash

echo "Check - incron status"
service incron status

echo "Check - veracrypt mounting"
veracrypt -t -v \
    --pim=0 \
    -k "" \
    -m=nokernelcrypto \
    --password=test \
    --non-interactive \
    "/test.vc" \
    "/testmount"

if [ $? -eq 0 ]; then
   echo "Clean up"
   veracrypt -v -d "/testmount"
   exit 0
else
   echo "Error, veracrypt mount problem detected."
   exit 1
fi