#!/bin/bash
set +e

if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

echo "Wiping Chirpstack application data..."
python chirpstack-app-wipe.py
echo "Done"

#System service
SERVICE_FILE=lorawan-complete
SERVICE_FILE_SERVER=lorawan-server
SERVICE_FILE_GATEWAY=lorawan-gateway
echo "Removing system services"
if [ -f "/etc/systemd/system/$SERVICE_FILE.service" ]; then
    service $SERVICE_FILE stop
    systemctl disable $SERVICE_FILE.service
    sudo rm /etc/systemd/system/$SERVICE_FILE.service
fi
if [ -f "/etc/systemd/system/$SERVICE_FILE_SERVER.service" ]; then
    service $SERVICE_FILE_SERVER stop
    systemctl disable $SERVICE_FILE_SERVER.service
    sudo rm /etc/systemd/system/$SERVICE_FILE_SERVER.service
fi
if [ -f "/etc/systemd/system/$SERVICE_FILE_GATEWAY.service" ]; then
    service $SERVICE_FILE_GATEWAY stop
    systemctl disable $SERVICE_FILE_GATEWAY.service
    sudo rm /etc/systemd/system/$SERVICE_FILE_GATEWAY.service
fi
systemctl daemon-reload
echo "Done"
echo "Removing Chirpstack Docker containers..."

docker-compose down -v

docker ps -a | awk '{ print $1,$2 }' | grep chirpstack | awk '{print $1 }' | xargs -I {} docker stop {}
docker ps -a | awk '{ print $1,$2 }' | grep chirpstack | awk '{print $1 }' | xargs -I {} docker rm {}
docker ps -a | awk '{ print $1,$2 }' | grep mosquitto | awk '{print $1 }' | xargs -I {} docker stop {}
docker ps -a | awk '{ print $1,$2 }' | grep mosquitto | awk '{print $1 }' | xargs -I {} docker rm {}
echo "Done"
echo "Removing Chirpstack Docker images..."
docker images -a | awk '{ print $1,$2 }' | grep chirpstack | awk '{print $1":"$2 }' | xargs -I {} docker rmi {}

echo "Finished"