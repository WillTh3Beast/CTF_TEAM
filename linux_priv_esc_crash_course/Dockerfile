FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        sudo \
        cron \
        tar \
        findutils \
        gcc \
        make \
        ca-certificates \
        dpkg-dev \
        vim \
        less \
        procps \
        psmisc \
        net-tools \
        iproute2 \
        iputils-ping \
        netcat-openbsd \
        python3 \
        curl \
        wget \
        file \
        unzip \
        zip \
        gzip \
        bzip2 \
        xz-utils \
        lsof \
        dnsutils \
        grep \
        sed \
        gawk \
        nano \
        tree \
        man-db && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Unprivileged challenge user
# ------------------------------------------------------------
RUN useradd -m -s /bin/bash ctf && \
    echo 'ctf:ctf' | chpasswd && \
    echo 'root:qwerty' | chpasswd

# ------------------------------------------------------------
# Flag
# ------------------------------------------------------------
RUN mkdir -p /root/ctf /opt/data /var/backups && \
    echo 'CTF{linux_privilege_escalation_training}' \
        > /root/ctf/flag.txt && \
    chmod 600 /root/ctf/flag.txt

# ------------------------------------------------------------
# 1. SUID find
# ------------------------------------------------------------
RUN chmod u+s /usr/bin/find

# ------------------------------------------------------------
# 2. sudo apt
# ------------------------------------------------------------
RUN echo 'ctf ALL=(root) NOPASSWD: /usr/bin/apt-get' \
    > /etc/sudoers.d/ctf-apt && \
    chmod 440 /etc/sudoers.d/ctf-apt

# ------------------------------------------------------------
# Writable directory for cron/tar challenge
# ------------------------------------------------------------
RUN chown -R ctf:ctf /opt/data
RUN touch /opt/data/empty.txt

# ------------------------------------------------------------
# Writable directory placed FIRST in root's PATH
# for the PATH injection challenge.
# ------------------------------------------------------------
RUN mkdir -p /home/ctf/bin && \
    chown -R ctf:ctf /home/ctf/bin && \
    chmod 755 /home/ctf/bin

# ------------------------------------------------------------
# Cron backup script
# ------------------------------------------------------------
COPY backup.sh /usr/local/sbin/backup.sh
RUN chmod 777 /usr/local/sbin/backup.sh

# ------------------------------------------------------------
# Cron configuration
# ------------------------------------------------------------
COPY root-cron /etc/cron.d/ctf-cron
RUN chmod 644 /etc/cron.d/ctf-cron
RUN crontab /etc/cron.d/ctf-cron

# ------------------------------------------------------------
# Make sure ctf owns its home tree.
# ------------------------------------------------------------
RUN chown -R ctf:ctf /home/ctf

# ------------------------------------------------------------
# Start cron and become the challenge user.
# ------------------------------------------------------------

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER root
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash", "-l"]

#USER ctf
#WORKDIR /home/ctf

