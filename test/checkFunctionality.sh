#!/bin/bash

APP_FOLDER="/upload/encryption-jobs"

echo "Check - incron status" >> "${APP_FOLDER}/log"
service incron status

echo "Check - veracrypt mounting" >> "${APP_FOLDER}/log"
veracrypt -t -v \
    --pim=0 \
    -k "" \
    -m=nokernelcrypto \
    --password=test \
    --non-interactive \
    "/test.vc" \
    "/testmount"

if [[ $? -eq 0 ]]; then
   echo "Clean up"
   veracrypt -d "/testmount"

   if [[ $? -eq 0 ]]; then
      exit 0
   else
      echo "Error, veracrypt dismount problem detected." >> "${APP_FOLDER}/log"
      veracrypt -d
      exit 1
   fi
else
   echo "Error, veracrypt mount problem detected." >> "${APP_FOLDER}/log"
   exit 1
fi