#!/bin/bash

###
# Global variables
###

SCRIPT_VERSION="1.4.0"
APP_FOLDER="/upload/encryption-jobs"

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

copyAllFilesRecursivelyInVeracryptContainer() {
    INPUT=$1
    OUTPUT=$2

    if cp -R ${INPUT}* ${OUTPUT}
    then
        toLogger "files copied"
    else
        toLogger "files copy failed"
    fi
}

dismountVeracryptContainerAndDeleteMountFolder() {
    NAME=$1
    veracrypt -d "${NAME}-open"
    rm -r "${NAME}-open"
}

toLogger() {
    message=$1
    time=$(date '+%F %T')
    echo "$time $message" >> ${APP_FOLDER}/log
}

cropLog() {
    tail -n 200 "$APP_FOLDER/log" > "$APP_FOLDER/log.tmp" && mv "$APP_FOLDER/log.tmp" "$APP_FOLDER/log"
}

###
# Main
###

toLogger "---> execute job: $1 as $(whoami) with script version ${SCRIPT_VERSION}"

if [[ ! -f "${APP_FOLDER}/new-job/$1" ]]; then
    toLogger  "No file for next job found"
else
    toLogger "copy ${APP_FOLDER}/new-job/$1 to ${APP_FOLDER}/work/"
    mv "${APP_FOLDER}/new-job/$1" "${APP_FOLDER}/work/"

    read KEY PW INPUT_FOLDER OUTPUT_FOLDER < "${APP_FOLDER}/work/$1"

    toLogger "found key: ${KEY}"
    toLogger "found input: ${INPUT_FOLDER}"
    toLogger "found output: ${OUTPUT_FOLDER}"

     if [[ ! -d $INPUT_FOLDER ]]; then
        echo "Failed (input folder '${INPUT_FOLDER}' is not a directory)" >> ${APP_FOLDER}/work/$1
        toLogger "No data for: ${KEY}, cancel job"
    else
        AVAILABLE_SIZE_IN_MB=$(df -m --output=avail /upload | sed -n 2p)
        NEEDED_SIZE_IN_MB=$(( $(du -ms "${INPUT_FOLDER}" | cut -f 1) + 2 ))

        toLogger "needed container size for ${KEY}: ${NEEDED_SIZE_IN_MB} MB / ${AVAILABLE_SIZE_IN_MB} MB"

        if (( AVAILABLE_SIZE_IN_MB <= NEEDED_SIZE_IN_MB )); then
            echo "Failed (not enough memory on disk)" >> ${APP_FOLDER}/work/$1
            toLogger "CAUTION! NOT ENOUGH SPACE ON DISK, cancel job"
        else
            toLogger "start container creation ($KEY) ..."

             veracrypt -t \
                --create "${OUTPUT_FOLDER}/${KEY}.vc" \
                --size="${NEEDED_SIZE_IN_MB}M" \
                --volume-type=normal \
                --encryption=AES \
                --hash=sha-512 \
                --filesystem=FAT \
                --pim=0 \
                -k "" \
                --password="${PW}" \
                --non-interactive

            if [[ ! -f "${OUTPUT_FOLDER}/${KEY}.vc" ]]; then
                echo "Failed (could not create veracrypt container)" >> ${APP_FOLDER}/work/$1
                toLogger "creation of veracrypt container ${KEY}.vc failed"
            else
                chown -R veracrypt .
                mkdir "${OUTPUT_FOLDER}/${KEY}-open"

                toLogger "start mounting ${KEY}.vc ..."

                veracrypt -t \
                    --pim=0 \
                    -k "" \
                    -m=nokernelcrypto \
                    --password="$PW" \
                    --non-interactive \
                    "${OUTPUT_FOLDER}/${KEY}.vc" \
                    "${OUTPUT_FOLDER}/${KEY}-open"

                if [[ ! -d "$OUTPUT_FOLDER/${KEY}-open" ]]; then
                    echo "Failed (mounting failed)" >> ${APP_FOLDER}/work/$1
                    toLogger "mounting of ${KEY} failed, files not copied"
                else
                    toLogger "start copying ($KEY) ..."
                    copyAllFilesRecursivelyInVeracryptContainer "${INPUT_FOLDER}/" "${OUTPUT_FOLDER}/${KEY}-open/"

                    toLogger "dismounting ($KEY) ..."
                    dismountVeracryptContainerAndDeleteMountFolder "${OUTPUT_FOLDER}/${KEY}"

                    echo " Completed" >> ${APP_FOLDER}/work/$1
                fi
            fi
        fi
    fi
fi

cropLog
