#!/bin/bash

APP_FOLDER="/upload/encryption-jobs"

log() {
    message=$1
    time=$(date '+%F %T')
    echo "$time $message" >> ${APP_FOLDER}/log.txt
}

log "Starting Veracrypt, creating working directories ..."

# create upload directory if not existing
mkdir -p /upload

# create mount point for self check
mkdir -p testmount

# create working directory for job files
mkdir -p "${APP_FOLDER}"
mkdir -p "${APP_FOLDER}/work"
mkdir -p "${APP_FOLDER}/logs"
mkdir -p "${APP_FOLDER}/new-job"

cd "${APP_FOLDER}"

# write access rights for veracrypt user
chown -R veracrypt .

# reload incron service
service incron restart

log "Small health check ..."
/bin/bash /checkFunctionality.sh
CHECK_RESULT=$?
log "Result code of health check: ${CHECK_RESULT}."

if [[ $CHECK_RESULT -eq 0 ]]; then
   # recover unfinished jobs
   cp "${APP_FOLDER}/work/*.job" "${APP_FOLDER}/new-job"

   # we need a running foreground process
   tail -f ${APP_FOLDER}/log.txt
fi
log "Shutdown Veracrypt."

# else: end process -> docker container will stop -> autostart will restart docker container
# loop devices should be reachable

