#!/bin/bash

mkdir /upload

APP_FOLDER="/upload/encryption-jobs"

echo "create working directories ..."

# root directory
mkdir "${APP_FOLDER}"

# job directories
mkdir "${APP_FOLDER}/work"
mkdir "${APP_FOLDER}/new-job"

# log file
touch "${APP_FOLDER}/log"

# write rights for veracrypt user
cd "$APP_FOLDER"
chown -R veracrypt .

service incron start

tail -f $APP_FOLDER/log
