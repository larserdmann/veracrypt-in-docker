#!/bin/bash

mkdir -p /upload

APP_FOLDER="/upload/encryption-jobs"

# for test
mkdir testmount

# root directory
mkdir -p "${APP_FOLDER}"

echo "$(date '+%F %T') Starting Veracrypt, creating working directories ..." >> "${APP_FOLDER}/log"

# job directories
mkdir -p "${APP_FOLDER}/work"
mkdir -p "${APP_FOLDER}/new-job"

# write rights for veracrypt user
cd "${APP_FOLDER}"
chown -R veracrypt .

service incron start
echo "$(date '+%F %T') Incron started." >> "${APP_FOLDER}/log"


if [ sh ./checkFunctionality.sh -eq 0 ]; then
   tail -f ${APP_FOLDER}/log
fi
echo "Shutdown Veracrypt."

# else: end process -> docker container will stop -> autostart will restart docker container
# loop devices should be reachable

