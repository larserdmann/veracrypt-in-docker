calculateNeededSizeForVeracryptContainer() {
    NAME=$1

    SIZE_OF_GENERAL_FOLDER=$(du -m "data/for-all" | cut -f 1)
    SIZE_OF_SPECIFIC_FOLDER=$(du -m "data/${NAME}" | cut -f 1)
    SIZE_OF_ALL=$(($SIZE_OF_GENERAL_FOLDER+$SIZE_OF_SPECIFIC_FOLDER+1))

    return "$SIZE_OF_ALL"
}

checkAvailableSize() {

    SIZE_OF_VOLUME=$(df -m  --output=avail /upload | sed -n 2p)

    return "$SIZE_OF_VOLUME"
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
    cd /upload/encryption/
    mv "job-new/$1" "job-in-progress/"

    read key pw < "job-in-progress/$1"

    toLogger "found key: ${key}"

    if [ ! -d "data/${key}" ]
    then
        mv "job-in-progress/$1" "job-failed"
        toLogger "No data for: ${key}, cancel job"

     else
        calculateNeededSizeForVeracryptContainer "$key"
        CALCULATED_SIZE=$?

        checkAvailableSize
        AVAILABLE_SIZE=$?

        toLogger "needed container size for $key: $CALCULATED_SIZE MB / $AVAILABLE_SIZE MB"

        if [ $AVAILABLE_SIZE -lt $CALCULATED_SIZE ]
        then
            mv "job-in-progress/$1" "job-failed"
            toLogger "CAUTION! NOT ENOUGH SPACE ON DISK, cancel job"

        else
            toLogger "start container creation ($key) ..."

            veracrypt -t \
                --create "volumes/${key}.vc" \
                --size="${CALCULATED_SIZE}M" \
                --volume-type=normal \
                --encryption=AES \
                --hash=sha-512 \
                --filesystem=FAT \
                --pim=0 \
                -k "" \
                --password="${pw}" \
                --non-interactive

            if [ ! -f "/upload/encryption/volumes/${key}.vc" ]
            then
                mv "job-in-progress/$1" "job-failed"
                toLogger "creation of veracrypt container ${key}.vc failed"
            else
                chown -R veracrypt .
                mkdir "open-volumes/${key}"

                toLogger "start mounting ${key}.vc ..."

                veracrypt -t \
                    --pim=0 \
                    -k "" \
                    -m=nokernelcrypto \
                    --password="$pw" \
                    --non-interactive \
                    "volumes/${key}.vc" \
                    "open-volumes/${key}"

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
    fi
else
    toLogger  "No file for next job found"
fi

cropLog
