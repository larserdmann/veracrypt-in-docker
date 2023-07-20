FROM            debian:12.0

MAINTAINER      Lars Erdmann <lars.erdmann@uni-greifswald.de>

COPY            deb/veracrypt-console-1.25.9-Debian-12-amd64.deb /opt/veracrypt.deb
COPY            deb/VeraCrypt_PGP_public_key.asc /opt/veracrypt.sig

RUN             apt-get update --no-install-recommends && \
                apt-get autoclean && \
                apt-get install gnupg --yes && \
                apt-get install nano --yes

# add verarypt
RUN             gpg --dearmor /opt/veracrypt.sig && \
                apt-key add /opt/veracrypt.sig && \
                apt install /opt/veracrypt.deb --yes && \
                groupadd -r veracrypt -g 433 && \
                useradd -u 431 -r -g veracrypt -s /bin/false -c "VeraCrypt user" veracrypt

# add incron
RUN             apt-get install incron && \
                echo root >> /etc/incron.allow && \
                apt-get autoclean

RUN             apt-get install exfat-fuse --yes && \
                apt-get --purge --yes autoremove

# add directory structure and files for easy testing
RUN             mkdir /testing && \
                mkdir /testing/new-job && \
                mkdir /testing/work && \
                mkdir /testing/logs && \
                mkdir /testing/TEST-123 && \
                mkdir /testing/TEST-123/Data && \
                mkdir /testing/TEST-123/Result

COPY            config/incron-command /var/spool/incron/
COPY            config/run.sh /
COPY            config/executeJob.sh /
COPY            test/test.vc /
COPY            test/checkFunctionality.sh /
COPY            test/executeTestJob.sh /
COPY            test/TEST-123.job /testing/
COPY            test/testcontent.csv /testing/TEST-123/Data

RUN             chmod +x /executeJob.sh && \
                chmod +x /run.sh && \
                chmod +x /checkFunctionality.sh && \
                chmod +x /executeTestJob.sh && \
                mv /var/spool/incron/incron-command /var/spool/incron/root

# veracrypt user is only for data handling, data should not be owned by root
#
# USER            veracrypt
#
# you can only use root user, because of
# 1. veracrypt needs to mount into filesystem
# 2. incron does work properly with root rights (starting scripts)

ENTRYPOINT      ["./run.sh"]
