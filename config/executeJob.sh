#!/bin/bash

###
# Veracrypt man page
# https://www.veracrypt.fr/en/Command%20Line%20Usage.html
###

###
# Global variables
###

SCRIPT_VERSION="1.6"
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
    echo "$time $message" >> ${APP_FOLDER}/log
}

###
# Main
###

log "* Executing job ${JOB_FILE_NAME} as $(whoami) with script version ${SCRIPT_VERSION} ..."

if [[ ! -f "${APP_FOLDER}/new-job/${JOB_FILE_NAME}" ]]; then
    log  "ERROR: No file for next job found"
    exit 1
fi

log "moving ${APP_FOLDER}/new-job/${JOB_FILE_NAME} to ${APP_FOLDER}/work/"
mv "${APP_FOLDER}/new-job/${JOB_FILE_NAME}" "${APP_FOLDER}/work/"

read KEY PW INPUT_FOLDER OUTPUT_FOLDER < "${APP_FOLDER}/work/${JOB_FILE_NAME}"
echo "${KEY}" > "${APP_FOLDER}/work/${JOB_FILE_NAME}"

log "found key: ${KEY}"
log "found input directory: ${INPUT_FOLDER}"
log "found output directory: ${OUTPUT_FOLDER}"

if [[ ! -d ${INPUT_FOLDER} ]]; then
    echo "Failed (input directory '${INPUT_FOLDER}' is not a directory)" >> ${APP_FOLDER}/work/${JOB_FILE_NAME}
    log "ERROR: Given input directory '${INPUT_FOLDER}' does not exist for: ${KEY}, canceling job"
    exit 1
fi

PUFFER_SIZE_IN_MB=2
AVAILABLE_SIZE_IN_MB=$(df -m --output=avail /upload | sed -n 2p)
NEEDED_SIZE_IN_MB=$(( $(du -ms "${INPUT_FOLDER}" | cut -f 1) + ${PUFFER_SIZE_IN_MB} ))

log "needed container size for ${KEY}: ${NEEDED_SIZE_IN_MB} MB / ${AVAILABLE_SIZE_IN_MB} MB"

if (( AVAILABLE_SIZE_IN_MB <= NEEDED_SIZE_IN_MB )); then
    echo "Failed (not enough memory on disk)" >> ${APP_FOLDER}/work/${JOB_FILE_NAME}
    log "ERROR: NOT ENOUGH SPACE ON DISK, canceling job"
    exit 1
fi

log "starting container creation ($KEY) ..."

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

if [[ ! -f "${OUTPUT_FOLDER}/${KEY}.vc" ]]; then
    echo "Failed (could not create veracrypt container)" >> ${APP_FOLDER}/work/${JOB_FILE_NAME}
    log "ERROR: creation of veracrypt container ${KEY}.vc failed"
    exit 1
fi

chown -R veracrypt ${OUTPUT_FOLDER}

MOUNT_FOLDER="${OUTPUT_FOLDER}/${KEY}-open"
if [[ -d ${MOUNT_FOLDER} ]]; then
    log "ERROR: mount directory ${MOUNT_FOLDER} already occupied"
    exit 1
fi

mkdir "${MOUNT_FOLDER}"
log "mounting ${KEY}.vc as ${MOUNT_FOLDER} ..."

veracrypt -t -v \
    --pim=0 \
    -k "" \
    -m=nokernelcrypto \
    --password="$PW" \
    --non-interactive \
    "${OUTPUT_FOLDER}/${KEY}.vc" \
    "${MOUNT_FOLDER}" 2>>${APP_FOLDER}/log 1>>${APP_FOLDER}/log

log "all mounted volumes: $(veracrypt -l -v)"

if [[ ! -d ${MOUNT_FOLDER} ]]; then
    echo "Failed (mounting failed)" >> ${APP_FOLDER}/work/${JOB_FILE_NAME}
    log "ERROR: mounting ${KEY}.vc as ${MOUNT_FOLDER} failed."
    exit 1
fi

log "copying all files for ($KEY) ..."
copyAllFilesRecursivelyToVeracryptContainer "${INPUT_FOLDER}/" "${MOUNT_FOLDER}"

log "unmounting ${MOUNT_FOLDER} ..."
veracrypt -v -d "${MOUNT_FOLDER}" 2>>${APP_FOLDER}/log 1>>${APP_FOLDER}/log
rm -r "${MOUNT_FOLDER}"

cat ${APP_FOLDER}/work/${JOB_FILE_NAME} > ${APP_FOLDER}/work/${KEY}.completed
rm ${APP_FOLDER}/work/${JOB_FILE_NAME}

log "Execution of job ${JOB_FILE_NAME} finished."