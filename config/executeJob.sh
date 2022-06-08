#!/bin/bash

###
# Veracrypt man page
# https://www.veracrypt.fr/en/Command%20Line%20Usage.html
###

###
# Global variables
###

SCRIPT_VERSION="1.8.2"
APP_FOLDER="/upload/encryption-jobs"
JOB_FILE_NAME="$1"

###
# Helper functions
###

calculateNeededSizeForVeracryptContainer() {
    INPUT_FOLDER=$1
    return $(du -m "${INPUT_FOLDER}" | cut -f 1) + 1
}

checkAvailableSize() {
    return $(df -m --output=avail /upload | sed -n 2p)
}

copyAllFilesRecursivelyToVeracryptContainer() {
    INPUT=$1
    OUTPUT=$2

    if cp -R ${INPUT}* ${OUTPUT}
    then
        log "files copied to $(ls -Rlasih ${MOUNT_FOLDER})"
    else
        log "ERROR: file copying failed from ${INPUT} to ${OUTPUT}"
    fi
}

log() {
    message=$1
    time=$(date '+%F %T')
    echo "$time $message" >> ${APP_FOLDER}/log.txt
}

jobLog() {
    message=$1
    log "$message"
    time=$(date '+%F %T')
    echo "$time $message" >> ${APP_FOLDER}/logs/${JOB_FILE_NAME}.log
}

###
# Main
###

log "* Executing job ${JOB_FILE_NAME} as $(whoami) with script version ${SCRIPT_VERSION} ..."

if [[ ! -f "${APP_FOLDER}/new-job/${JOB_FILE_NAME}" ]]; then
    log  "ERROR: File ${JOB_FILE_NAME} for next job not found."
    exit 1
fi

log "Moving ${APP_FOLDER}/new-job/${JOB_FILE_NAME} to ${APP_FOLDER}/work/"
mv "${APP_FOLDER}/new-job/${JOB_FILE_NAME}" "${APP_FOLDER}/work/"

read KEY PW INPUT_FOLDER OUTPUT_FOLDER < "${APP_FOLDER}/work/${JOB_FILE_NAME}"
touch "${APP_FOLDER}/logs/${JOB_FILE_NAME}.log"

log "found key: ${KEY}"
log "found input directory: ${INPUT_FOLDER}"
log "found output directory: ${OUTPUT_FOLDER}"

if [[ ! -d ${INPUT_FOLDER} ]]; then
    jobLog "ERROR: Given input directory '${INPUT_FOLDER}' does not exist for: ${KEY}, canceling job"
    exit 1
fi

BUFFER_SIZE_IN_MB=2
AVAILABLE_SIZE_IN_MB=$(df -m --output=avail /upload | sed -n 2p)
USED_SIZE_IN_MB=$(du -ms "${INPUT_FOLDER}" | cut -f 1)
NEEDED_SIZE_IN_MB=$(( ${USED_SIZE_IN_MB} + ${BUFFER_SIZE_IN_MB} ))

log "Needed container size for ${KEY}: ${NEEDED_SIZE_IN_MB} MB / ${AVAILABLE_SIZE_IN_MB} MB."

if (( AVAILABLE_SIZE_IN_MB <= NEEDED_SIZE_IN_MB )); then
    jobLog "ERROR: NOT ENOUGH SPACE ON DISK, canceling job $KEY"
    exit 1
fi

jobLog "Starting container creation ($KEY) ..."

veracrypt -t -v \
    --create "${OUTPUT_FOLDER}/${KEY}.vc" \
    --size="${NEEDED_SIZE_IN_MB}M" \
    --volume-type=normal \
    --encryption=AES \
    --hash=sha-512 \
    --filesystem=FAT \
    --pim=0 \
    -k "" \
    --password="${PW}" \
    --non-interactive 2>>${APP_FOLDER}/log 1>>${APP_FOLDER}/log

if [[ $? -ne 0 ]]; then
    jobLog "ERROR: veracrypt exit code: $?"
fi
if [[ ! -f "${OUTPUT_FOLDER}/${KEY}.vc" ]]; then
    jobLog "ERROR: creation of veracrypt container ${KEY}.vc failed"
    shutdown -t 15
fi

chown -R veracrypt ${OUTPUT_FOLDER}

MOUNT_FOLDER="${OUTPUT_FOLDER}/${KEY}-open"
if [[ -d ${MOUNT_FOLDER} ]]; then
    jobLog "ERROR: mount directory ${MOUNT_FOLDER} already occupied"
    # no problem with veracrypt itself
    exit 1
fi

mkdir "${MOUNT_FOLDER}"
jobLog "Mounting ${KEY}.vc as ${MOUNT_FOLDER} ..."

veracrypt -t -v \
    --pim=0 \
    -k "" \
    -m=nokernelcrypto \
    --password="$PW" \
    --non-interactive \
    "${OUTPUT_FOLDER}/${KEY}.vc" \
    "${MOUNT_FOLDER}" 2>>${APP_FOLDER}/log 1>>${APP_FOLDER}/log

jobLog "All mounted volumes: $(veracrypt -l -v)"

if [[ ! -d ${MOUNT_FOLDER} ]]; then
    jobLog "ERROR: mounting ${KEY}.vc as ${MOUNT_FOLDER} failed."
    shutdown -t 15
fi

jobLog "Copying all files for ($KEY) ..."
copyAllFilesRecursivelyToVeracryptContainer "${INPUT_FOLDER}/" "${MOUNT_FOLDER}"

jobLog "Unmounting ${MOUNT_FOLDER} ..."
veracrypt -v -d "${MOUNT_FOLDER}" 2>>${APP_FOLDER}/log 1>>${APP_FOLDER}/log
rm -r "${MOUNT_FOLDER}"

cat ${APP_FOLDER}/work/${JOB_FILE_NAME} > ${APP_FOLDER}/work/${KEY}.completed
rm ${APP_FOLDER}/work/${JOB_FILE_NAME}

jobLog "Execution of job ${JOB_FILE_NAME} finished."