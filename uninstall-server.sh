#!/bin/bash
set +e

ALL="false"

MOSQUITTO_CONFIG_FILE="/etc/mosquitto/mosquitto.conf"
MOSQUITTO_SERVICE_FILE="/lib/systemd/system/mosquitto.service"

print_usage() {
    echo
    echo " -a    : Remove all docker images and data (postgres + redis + mosquitto)"
}

while getopts 'ah' flag; do
    case "${flag}" in
        a) ALL='true' ;;
        h) print_usage
            exit 1 ;;
        *) print_usage
            exit 1 ;;
    esac
done


if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

echo "Wiping Chirpstack application data..."
python chirpstack-app-wipe.py
echo "Done"

#System service
SERVICE_FILE_SERVER=lorawan-server
echo "Removing system service"
if [ -f "/lib/systemd/system/$SERVICE_FILE_SERVER.service" ]; then
    service $SERVICE_FILE_SERVER stop
    systemctl disable $SERVICE_FILE_SERVER.service
    sudo rm /lib/systemd/system/$SERVICE_FILE_SERVER.service
fi
systemctl daemon-reload
echo "Done"
echo "Removing Chirpstack Docker containers..."

docker-compose down -v

docker ps -a | awk '{ print $1,$2 }' | grep chirpstack | awk '{print $1 }' | xargs -I {} docker stop {}
docker ps -a | awk '{ print $1,$2 }' | grep chirpstack | awk '{print $1 }' | xargs -I {} docker rm {}

if [ $ALL = "true" ]; then
    docker ps -a | awk '{ print $1,$2 }' | grep postgres | awk '{print $1 }' | xargs -I {} docker stop {}
    docker ps -a | awk '{ print $1,$2 }' | grep postgres | awk '{print $1 }' | xargs -I {} docker rm {}
    docker ps -a | awk '{ print $1,$2 }' | grep redis | awk '{print $1 }' | xargs -I {} docker stop {}
    docker ps -a | awk '{ print $1,$2 }' | grep redis | awk '{print $1 }' | xargs -I {} docker rm {}
    docker ps -a | awk '{ print $1,$2 }' | grep mosquitto | awk '{print $1 }' | xargs -I {} docker stop {}
    docker ps -a | awk '{ print $1,$2 }' | grep mosquitto | awk '{print $1 }' | xargs -I {} docker rm {}
fi
echo "Done"
echo "Removing Chirpstack Docker images..."
docker images -a | awk '{ print $1,$2 }' | grep chirpstack | awk '{print $1":"$2 }' | xargs -I {} docker rmi {}
if [ $ALL = "true" ]; then
    docker images -a | awk '{ print $1,$2 }' | grep postgres | awk '{print $1":"$2 }' | xargs -I {} docker rmi {}
    docker images -a | awk '{ print $1,$2 }' | grep redis | awk '{print $1":"$2 }' | xargs -I {} docker rmi {}
    docker images -a | awk '{ print $1,$2 }' | grep mosquitto | awk '{print $1":"$2 }' | xargs -I {} docker rmi {}
fi

echo "Updating Mosquitto Config and Service"
. update-mosquitto.sh -r

echo "Finished"