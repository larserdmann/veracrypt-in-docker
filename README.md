# veracrypt-in-docker

This is a docker container with an automated encryption process.

The files to encrypt are located in a **shared** docker volume. 
Additionally, the veracrypt docker container (*VDC*) generates its own working directory with subdirectories
(see `run.sh` with environment variable `APP_FOLDER`, also used in `executeJob.sh`).

The VDC is configured to wait for a job description file in a specific directory (`APP_FOLDER/new-job/`).
In my case there is a java application that generates the job file with needed content 
and logs the completion of the process, signaled by renaming of the job file from 
`aFilename.job -> aFilename.completed`

## Encryption workflow

The encryption in VDC is based on the `executeJob.sh` script, which is called from incron.

Incron is configured with the `incron-command` file. The three parameters are the `path`, 
the `file events` and the `command`. As command i used `./executeJob.sh $#`, 
that means the filename of the new job is given as a parameter to the script `executeJob.sh`.

### 1. Job file generation

The name of the job-file is irrelevant, **the file-content is important**.
There have to be four parameters, separated by spaces.

1. parameter: the name of the resulting veracrypt container
2. parameter: the password of the resulting veracrypt container
3. parameter: the path of the input files and folders
4. parameter: the path of the resulting veracrypt container

```
<NameForVeracryptContainer> <PasswordForVeracryptContainer> <DataInputPath> <VeracryptOutputPath>
```

Example myVeracrypt.job:
```
Project-XY-002 mySuperSecurePassword /home/user/projectstuff/ /media/backup/project-XY/
```

### 2. Job file placing

To start the process, the job file have to be moved, or written into `APP_FOLDER/new-job/`.

### 3. Encryption process of VDC

Long story short, `executeJob.sh` does his job.
1. move the job file from `.../new-job/ -> .../work/`

   If you are curious if the process has started, you can check the directory.

2. overwrite job file, the password is no longer included in the job file
3. calculation of needed veracrypt container size + a minimal buffer

   If your hard disk is full, then the process abort and logs it. 
   You can check with `docker logs -f --tail=100 veracrypt` or see 
   log file located in `APP_FOLDER/log`
   
4. creating new and mounting this veracrypt container
5. copying files from given input path
6. unmounting veracrypt container
7. renaming job file `aFilename.job -> aFilename.completed`

Unexpected errors can occur at any time, therefor each step in `executeJob.sh` 
produces a log entry. 

### Notes

* total size of files is computed in shell script (`executeJob.sh`).
* all files of folder `DataInputPath` are taken into account. 
* also all files and subdirectories are copied from there to the veracrypt container.
* you **HAVE TO take care of your selected password**, it will not be saved

## installation of veracrypt-in-docker

1. Fetch docker image
```
docker pull larserdmann/veracrypt-in-docker:1.12
```

2. run container of the image with an existing volume `transfer_files`:
Note: container uses /dev/fuse and loop devices of host to enable mounting of veracrypt container

```
docker run -d -t -i \
    --restart unless-stopped \
    --device /dev/fuse \
    --privileged=true \
    --name veracrypt \
    -v transfer_files:/upload \
    -v test_files:/testing \
    larserdmann/veracrypt-in-docker:1.12
```

Check existing docker container:
```
docker container ls -a
```

If needed, view into the logs with:
```
docker logs veracrypt
```

### Trobleshooting

Log into the veracrypt container with:
```
docker exec -it veracrypt bash
``` 

and check if everything works as expected with the given test case

``` 
cd testing
cp TEST-123.job new-job/
``` 

The .log file should be removed from new-log/ directory and a log for this job should be created in logs directory.

### show help
```
docker run -t -i \
	--privileged=true \
	--rm \
    --entrypoint veracrypt \
	larserdmann/veracrypt-in-docker:1.12 -h
```

### Build 'veracrypt-in-docker' image the manual way

Load the source files from github and run:
```
docker build -t larserdmann/veracrypt-in-docker:1.12 .
```

#### Large files in encrypted container -> exFAT

```
veracrypt -t -v \
--create "test.vc" \
--size="6500M" \
--volume-type=normal \
--encryption=AES \
--hash=sha-512 \
--filesystem=exFAT \
--pim=0 \
-k "" \
--password="test" \
-m=nokernelcrypto
--non-interactive
```

#### Problem: fuse + docker -> need privileged mode

without `--privileged=true` veracrypt mounting would produces following error:
Error: Failed to set up a loop device


### Configure incron inside veracrypt container

Incron is already configured, but if there is a need for changes edit the incron process:
```
incrontab -e
```

**DO NOT** add spaces between events or slice up in multiple commands. 
Incron can only watch a path once. If there is a need for different workflows, 
the called script have to handle that.

Check, if all is ok with:

```bash
incrontab -l
```
if there is a event wrong, it is replaced with '0'

Man page see: https://manpages.debian.org/testing/incron/incrontab.5.en.html


## Possible algorithm to use in veracrypt

Algorithm | Key Size (Bits) |	Block Size (Bits) | Mode of Operation
---|---|---|--- 	 	 	 	 
AES | 256 | 128 | XTS
Camellia | 256 | 128 | XTS
Kuznyechik | 256 | 128 | XTS
Serpent | 256 | 128 | XTS
Twofish	| 256 | 128 | XTS
AES-Twofish | 256; 256 | 128 | XTS
AES-Twofish-Serpent | 256; 256; 256 | 128 | XTS
Camellia-Kuznyechik | 256; 256 | 128 | XTS
Camellia-Serpent | 256; 256 | 128 | XTS
Kuznyechik-AES | 256; 256 | 128 | XTS
Kuznyechik-Serpent-Camellia | 256; 256; 256 | 128 | XTS
Kuznyechik-Twofish | 256; 256 | 128 | XTS
Serpent-AES | 256; 256 | 128 | XTS
Serpent-Twofish-AES | 256; 256; 256 | 128 | XTS
Twofish-Serpent | 256; 256 | 128 | XTS

On container creation, one can choose a given algorithm.
But at mount time we **CAN NOT** leave out `-m=nokernelcrypto`, 
because the resulting veracrypt container do not work properly (is empty). 

## Update Release notes of used components

- Incron see: https://github.com/ar-/incron/blob/master/CHANGELOG
- Ubuntu (actual used LTS 22.04): https://wiki.ubuntu.com/Releases
- Veracrypt see: https://github.com/veracrypt/VeraCrypt/releases

- https://serverfault.com/a/531533
- https://askubuntu.com/questions/1454126/incron-not-starting-script
- https://hackaday.com/2020/10/28/linux-fu-troubleshooting-incron/
- https://unix.stackexchange.com/questions/290970/users-incrontab-not-working-only-roots-when-incrond-is-run-as-a-service
