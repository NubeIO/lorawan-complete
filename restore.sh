#!/bin/bash

if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

if [ $# -lt 1 ]; then
    echo "Error: You must provide the backup zip filename."
    exit 1
fi

echo -e "\e[33mWARNING: This operation will wipe ALL existing LoRaWAN data! Are you sure you want to continue?\e[0m"
read -p "Press Enter to proceed or Ctrl+C to cancel..."
echo "Proceeding..."

systemctl stop lorawan-server.service
sleep 2
docker-compose down -v
sleep 1

mkdir -p .tmp/
unzip $1 -d .tmp/
pushd .tmp/
    ../docker-backup restore $(ls chirpstack_chirpstack-application-server*.tar)
    ../docker-backup restore $(ls chirpstack_chirpstack-network-server*.tar)
    ../docker-backup restore $(ls chirpstack_chirpstack-gateway-bridge*.tar)
    ../docker-backup restore $(ls redis-local*.tar)
    ../docker-backup restore $(ls postgres-local*.tar)
popd
rm -r .tmp/

systemctl restart lorawan-server.service
