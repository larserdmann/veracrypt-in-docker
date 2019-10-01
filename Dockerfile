FROM            ubuntu_for_man_ppa:latest

MAINTAINER      Lars Erdmann <lars.erdmann@uni-greifswald.de>

COPY            config/veracrypt-ppa /etc/apt/sources.list.d/unit193-ubuntu-encryption-bionic.list
COPY            config/incron-command /var/spool/incron/
COPY            config/run.sh /
COPY            config/executeJob.sh /

RUN             apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 03647209B58A653A && \
                apt-get update --no-install-recommends && \
                apt-get install veracrypt -y --no-install-recommends && \
                apt-get install nano -y && \
                apt-get install incron && \
                echo root >> /etc/incron.allow && \
                apt-get autoclean && \
                apt-get --purge -y autoremove && \
                groupadd -r veracrypt -g 433 && \
                useradd -u 431 -r -g veracrypt -s /bin/false -c "VeraCrypt user" veracrypt && \
                chmod +x /executeJob.sh && \
                chmod +x /run.sh && \
                mv /var/spool/incron/incron-command /var/spool/incron/root

ENTRYPOINT      ["./run.sh"]
