#!/bin/bash

APP_FOLDER="/upload/encryption-jobs"
INCRON_NOT_RUNNING_STRING=" * incron is not running"

echo "Check 1 - incron status" >> "${APP_FOLDER}/log"
INCRON_OUTPUT=$(service incron status)

#echo "output: ${INCRON_OUTPUT}"
#echo "not running string: ${INCRON_NOT_RUNNING_STRING}"

if [[ ${INCRON_OUTPUT} = ${INCRON_NOT_RUNNING_STRING} ]]; then
   service incron start
fi

echo "Check 2 - veracrypt mounting" >> "${APP_FOLDER}/log"
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
