#!/bin/bash

mkdir -p /upload

APP_FOLDER="/upload/encryption-jobs"

# root directory
mkdir -p "${APP_FOLDER}"

echo "$(date '+%F %T') Starting Veracrypt, creating working directories ..." >> "${APP_FOLDER}/log"

# job directories
mkdir -p "${APP_FOLDER}/work"
mkdir -p "${APP_FOLDER}/new-job"

# write rights for veracrypt user
cd "$APP_FOLDER"
chown -R veracrypt .

service incron start
echo "$(date '+%F %T') Incron started." >> "${APP_FOLDER}/log"

tail -f $APP_FOLDER/log