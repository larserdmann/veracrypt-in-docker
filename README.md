# veracrypt-in-docker

Docker container for automated encryption

1. fetch Docker Image
    ```
    docker pull larserdmann/veracrypt-in-docker:1.3
    ```

2. run container of `guiless-veracrypt` image with an existing volume `transfer_files`:
Note: container uses /dev/fuse of host to enable mounting of veracrypt container

```
docker run -d -t -i \
	--privileged=true \
	--name veracrypt \
	-v transfer_files:/upload \
	-e USED_ENCRYPTION_MODE='AES' \
	larserdmann/veracrypt-in-docker:1.3
```

Check existing docker container:
```
docker container ls -a
```

If needed, view into the logs with:
```
docker logs veracrypt
```

or log into the veracrypt container with:
```
docker exec -it veracrypt bash
``` 

### problem: fuse + docker -> need privileged mode

without `--privileged` veracrypt mounting would produces following error:
Error: Failed to set up a loop device

## Start of encryption jobs, inputfile for incron

Name of the job-file is irrelevant, the file-content not: 


job.001:	```NameForVeracryptContainer PasswordForVeracryptContainer DataInputPath VeracryptOutputPath```

Size of files is computed in shell script.
All files of folder `DataInputPath` are taken into account. 
Also all files and subfolders are copied from there to the veracrypt container.


## Configure Incron inside veracrypt container

Incron is already configured, but if there is a need for changes:

Edit incron process:
```
incrontab -e
```

DO NOT add spaces between events or slice up in multiple commands. 
Incron can only watch a path once. If there is a need for different workflows, 
the called script have to handle that.

Check, if all is ok with:

```bash
incrontab -l
```
if there is a event wrong, it is replaced with '0'


### Possible algorithm to use

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
But at mount time we CAN NOT leave out -m=nokernelcrypto, 
because the resulting veracrypt container do not work properly (is empty). 