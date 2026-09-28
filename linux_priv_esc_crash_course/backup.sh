#!/bin/bash

export PATH="/home/ctf/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

cd /opt/data || exit 1

tar -cvf /var/backups/data.tar.gz *
