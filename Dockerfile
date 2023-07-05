FROM            larserdmann/ubuntu-for-manual-ppa:22.04

MAINTAINER      Lars Erdmann <lars.erdmann@uni-greifswald.de>

COPY            config/veracrypt-ppa /etc/apt/sources.list.d/unit193-ubuntu-encryption-bionic.list

RUN             apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 03647209B58A653A && \
                apt-get update --no-install-recommends && \
                apt-get install veracrypt -y --no-install-recommends && \
                apt-get install nano -y && \
                apt-get install incron && \
                echo root >> /etc/incron.allow && \
                apt-get autoclean && \
                apt-get --purge -y autoremove && \
                groupadd -r veracrypt -g 433 && \
                useradd -u 431 -r -g veracrypt -s /bin/false -c "VeraCrypt user" veracrypt

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
                mv /var/spool/incron/incron-command /var/spool/incron/root

ENTRYPOINT      ["./run.sh"]
