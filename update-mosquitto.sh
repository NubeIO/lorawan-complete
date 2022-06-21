#!/bin/bash
set -e

# -- User Config --
REMOVE='false'
CONFIG_FILE="/etc/mosquitto/mosquitto.conf"
BACKUP_NAME="mosquitto.pre_docker.conf"
BACKUP_FILE=
DOCKER_IP="172.17.0.1"

SERVICE_FILE="/lib/systemd/system/mosquitto.service"

print_usage() {
    echo "Updates Mosquitto to support Docker."
    echo "  Adds a Docker listener to your Mosquitto config file."
    echo "  Changes service file to wait for Docker to start first."
    echo
    echo "Options:"
    echo " -r                : Remove Docker changes (default is to add)"
    echo " -c <config_file>  : Path to Mosquitto config (default $CONFIG_FILE)"
    echo " -b <backup_file>  : Path to Mosquitto config backup (default <path_to_config>/$BACKUP_NAME)"
    echo " -i <docker_ip>    : Docker IP to listen on (default $DOCKER_IP)"
    echo " -s <service_file> : Path to Mosquitto service file (default $SERVICE_FILE)"
}

while getopts 'c:b:i:s:rh' flag; do
    case "${flag}" in
        c) CONFIG_FILE="${OPTARG}" ;;
        b) BACKUP_FILE="${OPTARG}" ;;
        i) DOCKER_IP="${OPTARG}" ;;
        r) REMOVE='true' ;;
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

function addDocker() {
    if [ -z "$BACKUP_FILE" ]; then
        CONFIG_DIR="$(dirname "${CONFIG_FILE}")"
        BACKUP_FILE="$CONFIG_DIR/$BACKUP_NAME"
    fi

    echo "Creating config backup to $BACKUP_FILE"
    cp $CONFIG_FILE $BACKUP_FILE

    echo "Adding Docker listener to Mosquitto config"
    LISTENER="listener 1883 $DOCKER_IP"
    if [[ $(grep "$LISTENER" $CONFIG_FILE) ]]; then
        sed -i 's/^#.*'"$LISTENER"'/'"$LISTENER"'/' $CONFIG_FILE
    else
        sed -i '/^listener.*/a '"$LISTENER"'' $CONFIG_FILE
    fi

    echo "Modifying service file to wait for Docker"
    if [ -z "$(grep -E "After=.*docker.service" $SERVICE_FILE)" ]; then
        sed -i 's/After=.*/& docker.service/' $SERVICE_FILE
        systemctl daemon-reload
    else
        echo "No modification needed."
    fi

    if command -v ufw &> /dev/null; then
        echo "Allowing UFW rules between Docker and Mosquitto"
        ufw allow from $DOCKER_IP/24 port 1883
        ufw allow to $DOCKER_IP/24 port 1883
    fi
}

function removeDocker() {
    echo "Removing Docker listener from Mosquitto config"
    LISTENER="listener 1883 $DOCKER_IP"
    sed -i '/^'"$LISTENER"'/d' $CONFIG_FILE

    echo "Modifying service file"
    sed -i 's/[ ]*docker.service//' $SERVICE_FILE
    systemctl daemon-reload

    if command -v ufw &> /dev/null; then
        echo "Removing UFW rules between Docker and Mosquitto"
        ufw delete allow from $DOCKER_IP/24 port 1883
        ufw delete allow to $DOCKER_IP/24 port 1883
    fi
}

if [ $REMOVE = 'false' ]; then
    echo "Adding Docker changes"
    addDocker
else
    echo "Removing Docker changes"
    removeDocker
fi

echo "Restart Mosquitto for changes to take effect."
echo "Finished"