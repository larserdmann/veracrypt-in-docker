#!/bin/bash

calculateNeededSizeForVeracryptContainer() {
    NAME=$1

    SIZE_OF_GENERAL_FOLDER=$(du -m "data/for-all" | cut -f 1)
    SIZE_OF_SPECIFIC_FOLDER=$(du -m "data/${NAME}" | cut -f 1)
    SIZE_OF_ALL=$(($SIZE_OF_GENERAL_FOLDER+$SIZE_OF_SPECIFIC_FOLDER+1))

    return "$SIZE_OF_ALL"
}

createOrOverwriteVeracryptContainer() {
    NAME=$1
    PW=$2
    SIZE=$3

    veracrypt -t \
        --create "volumes/${NAME}.vc" \
        --size="${SIZE}M" \
        --volume-type=normal \
        --encryption=$USED_ENCRYPTION_MODE \
        --hash=sha-512 \
        --filesystem=FAT \
        --pim=0 \
        -k "" \
        --password="${PW}" \
        --non-interactive
}

mountVeracryptContainer() {
    NAME=$1
    PW=$2

    veracrypt -t \
        --pim=0 \
        -k "" \
        -m=nokernelcrypto \
        --password="$PW" \
        --non-interactive \
        "volumes/${NAME}.vc" \
        "open-volumes/${NAME}"
}

copyFilesInVeracryptContainer() {
    NAME=$1

    if cp -R "data/for-all/"* "open-volumes/${NAME}/"
    then
        toLogger "general files copied"
    else
        toLogger "general files copy failed"
    fi

    if cp -R "data/${NAME}/"* "open-volumes/${NAME}/"
    then
        toLogger "specific files copied"
    else
        toLogger "specific files copy failed"
    fi

}

dismountVeracryptContainerAndDeleteMountFolder() {
    NAME=$1

    veracrypt -d "open-volumes/${NAME}"
    rm -r "open-volumes/${NAME}"
}

toLogger() {
    message=$1
    time=$(date '+%F %T')
    echo "$time $message" >> /upload/encryption/log
}

cropLog() {
    tail -n 200 "/upload/encryption/log" > "/upload/encryption/log.tmp" && mv "/upload/encryption/log.tmp" "/upload/encryption/log"
}

###
# Main
###
toLogger "---> execute job: $1 as $(whoami)"

if [ -f "/upload/encryption/job-new/$1" ]
then
    cd /upload/encryption/job-new
    read key pw < $1
    echo "${key}" > $1

    toLogger "key: ${key}"

    cd /upload/encryption
    if [ ! -d "data/${key}" ]
    then
        mv "job-new/$1" "job-failed"
        toLogger "No data for: ${key}, cancel job"

     else
        mv "job-new/$1" "job-in-progress/"

        calculateNeededSizeForVeracryptContainer "$key"
        CALCULATED_SIZE=$?

        toLogger "needed container size: $CALCULATED_SIZE MB ($key)"

        toLogger "start container creation ($key) ..."
        createOrOverwriteVeracryptContainer "$key" "$pw" "$CALCULATED_SIZE"

        if [ ! -f "/upload/encryption/volumes/${key}.vc" ]
        then
            mv "job-in-progress/$1" "job-failed"
            toLogger "creation of veracrypt container ${key}.vc failed"
        else
            chown -R veracrypt .
            mkdir "open-volumes/${key}"

            toLogger "start mounting ${key}.vc ..."
            mountVeracryptContainer "$key" "$pw"

            if [ ! -d "/upload/encryption/open-volumes/$key" ]
            then
                mv "job-in-progress/$1" "job-failed"
                toLogger "mounting of ${key} failed, files not copied"
            else
                toLogger "start copying ($key) ..."
                copyFilesInVeracryptContainer "${key}"

                toLogger "dismounting ($key) ..."
                dismountVeracryptContainerAndDeleteMountFolder "${key}"

                mv "volumes/${key}.vc" "finished-volumes/"
                mv "job-in-progress/$1" "job-done"
            fi
        fi
    fi
else
    toLogger  "No file for next job found"
fi

cropLog