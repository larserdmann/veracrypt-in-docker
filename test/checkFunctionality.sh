#!/bin/bash

APP_FOLDER="/upload/encryption-jobs"

log() {
    message=$1
    time=$(date '+%F %T')
    echo "$time $message" >> ${APP_FOLDER}/log.txt
}

log "Check 1 - incron status ..."
INCRON_OUTPUT=$(service incron status)
INCRON_NOT_RUNNING_STRING=" * incron is not running"

if [[ ${INCRON_OUTPUT} = "${INCRON_NOT_RUNNING_STRING}" ]]; then
   log "Incron is not running yet, starting ..."
   service incron start
fi

log "Check 2 - Loop devices test ..."
FIRST_LOOP_DEVICE=$(/sbin/losetup -f)
log "First loop device found: $FIRST_LOOP_DEVICE"

if [[ -z  ${FIRST_LOOP_DEVICE} ]]; then
   log "ERROR: No loop device found ..."
   exit 1
fi

log "Check 3 - Mounting veracrypt container /test.vc at /testmount ..."
veracrypt -t -v \
    --pim=0 \
    -k "" \
    -m=nokernelcrypto \
    --password=test \
    --non-interactive \
    "/test.vc" \
    "/testmount"

if [[ $? -eq 0 ]]; then
   log "Test mounting successful."
   log "Unmounting /testmount ..."
   veracrypt -d "/testmount"

   if [[ $? -eq 0 ]]; then
      log "Unmounting /testmount successful."
      exit 0
   else
      log "ERROR: unmounting /testmount veracrypt container failed."
      veracrypt -d
      exit 1
   fi
else
   log "ERROR: mounting /testmount veracrypt container failed."
   exit 1
fi
