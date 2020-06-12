#!/bin/bash
set +e

if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

echo "Wiping Chirpstack application data..."
python chirpstack-app-wipe.py
echo "Done"

SERVICE_FILE=lorawan-complete
if [ -f "/etc/systemd/system/$SERVICE_FILE.service" ]; then
    echo "Removing system service"
    systemctl daemon-reload
    service $SERVICE_FILE stop
    systemctl disable $SERVICE_FILE.service
    sudo rm /etc/systemd/system/$SERVICE_FILE.service
    echo "Done"
fi

echo "Removing Chirpstack Docker containers..."

docker-compose down -v

docker ps -a | awk '{ print $1,$2 }' | grep chirpstack | awk '{print $1 }' | xargs -I {} docker stop {}
docker ps -a | awk '{ print $1,$2 }' | grep chirpstack | awk '{print $1 }' | xargs -I {} docker rm {}
echo "Done"
echo "Removing Chirpstack Docker images..."
docker images -a | awk '{ print $1,$2 }' | grep chirpstack | awk '{print $1":"$2 }' | xargs -I {} docker rmi {}

echo "Finished"