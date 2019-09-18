#!/bin/bash

mkdir /upload

APP_FOLDER="/upload/encryption"

echo "create working directories ..."

# root directory
mkdir "${APP_FOLDER}"

# job directories
mkdir "${APP_FOLDER}/job-new"
mkdir "${APP_FOLDER}/job-in-progress"
mkdir "${APP_FOLDER}/job-done"
mkdir "${APP_FOLDER}/job-failed"

# volume directories
mkdir "${APP_FOLDER}/volumes"
mkdir "${APP_FOLDER}/open-volumes"
mkdir "${APP_FOLDER}/finished-volumes"

# data for volumes
mkdir "${APP_FOLDER}/data"
mkdir "${APP_FOLDER}/data/for-all"

# log file
touch "${APP_FOLDER}/log"

# clean up past job files
mv $APP_FOLDER/job-in-progress/*.* ${APP_FOLDER}/job-failed/
mv $APP_FOLDER/job-new/*.* ${APP_FOLDER}/job-failed/

# write rights for veracrypt user
cd "$APP_FOLDER"
chown -R veracrypt .

service incron start

tail -f $APP_FOLDER/log
