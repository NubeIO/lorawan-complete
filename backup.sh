#!/bin/bash

if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

systemctl stop lorawan-server.service
sleep 2

FILENAME="lorawan-backup_$(date +%Y-%m-%dT%H:%M:%S).zip"

mkdir -p .tmp/
pushd .tmp/
    ../docker-backup backup --tar $(docker ps -a | grep chirpstack/chirpstack-application-server | awk '{print $1}')
    ../docker-backup backup --tar $(docker ps -a | grep chirpstack/chirpstack-network-server | awk '{print $1}')
    ../docker-backup backup --tar $(docker ps -a | grep chirpstack/chirpstack-gateway-bridge | awk '{print $1}')
    ../docker-backup backup --tar $(docker ps -a | grep redis | awk '{print $1}')
    ../docker-backup backup --tar $(docker ps -a | grep postgres | awk '{print $1}')
    
    zip ../$FILENAME chirpstack_chirpstack-*.tar redis-local-*.tar postgres-local-*.tar
popd
rm -r .tmp/

systemctl restart lorawan-server.service

echo "Backup successfully created: $FILENAME"
