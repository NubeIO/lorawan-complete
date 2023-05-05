#!/bin/bash
set -e


# -- User Config --
BUILD_ARCH="arm32v7"

LORA_REGION="au915"
LORA_REGION_BAND=0

SERVER_PASSWORD=

MQTT_USER=""
MQTT_PASS=""

STARTUP_SERVICE='true'
ENABLE_MOSQUITTO='false'
UPDATE_MOSQUITTO='true'

LOG_LEVEL=WARNING


print_usage() {
    echo
    echo " -r <region>    : Region [au915, us915, eu868, as923, as920]. Default au915"
    echo " -b <band>      : Region Band [0,1] (for AU and US).   Default 0"
    echo " -p <password>  : Server password"
    echo " -U <username>  : MQTT broker username"
    echo " -P <password>  : MQTT broker password"
    echo " -s             : Disable startup service"
    echo " -m             : Enable Mosquitto in docker"
    echo " -n             : Don't update Mosquitto config"
}

while getopts 'r:b:p:U:P:smnh' flag; do
    case "${flag}" in
        r) LORA_REGION="${OPTARG}"
            echo "LoRaWAN Region set to $LORA_REGION" ;;
        b) LORA_REGION_BAND="${OPTARG}"
            echo "Region Band set to $LORA_REGION_BAND" ;;
        p) SERVER_PASSWORD="${OPTARG}"
            echo "Server password to be changed" ;;
        U) MQTT_USER="${OPTARG}"
            echo "MQTT username to be changed" ;;
        P) MQTT_PASS="${OPTARG}"
            echo "MQTT password to be changed" ;;
        s) STARTUP_SERVICE='false' ;;
        m) ENABLE_MOSQUITTO='true' ;;
        m) UPDATE_MOSQUITTO='false' ;;
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

if [ -z "$SERVER_PASSWORD" ]; then
    echo "ERROR: Please provide server password (-p)"
    exit 1
fi

chmod +x change-freq-gateway.sh change-freq-server.sh uninstall-gateway.sh uninstall-server.sh start.sh stop.sh

#Dependencies
echo "Dependencies..."
# if ! [ -x "$(command -v docker)" ]; then
if ! hash docker > /dev/null; then
    echo "No docker command found. Installing requirements..."
    set +e
    apt remove docker docker-engine docker.io containerd runc
    set -e
    # Dl and run docker install
    curl -fsSL https://get.docker.com -o get-docker.sh
    chmod +x get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    # Add user to docker group for priviliges
    set +e
    usermod -aG docker $USER
    usermod -aG docker $(who am i | awk '{print $1}')
    set -e
    echo ""
    echo "-- Reboot required after docker installation! --"
    echo "Then re-run this script to continue installation"
    exit 0
fi
# Install requirements
apt install -y docker-compose git python3-pip jq
pip install requests
echo "Done"

#Chirpstack
# Local Images
# echo "Loading Docker images..."
# docker load -i docker-build/chirpstack-network-server-$BUILD_ARCH-local.tar
# docker load -i docker-build/chirpstack-application-server-$BUILD_ARCH-local.tar
# docker load -i docker-build/chirpstack-gateway-bridge-$BUILD_ARCH-local.tar
docker load -i docker-build/postgres-local.tar
docker load -i docker-build/redis-local.tar
# echo "Done"

#Chirpstack Config
echo "Setting Chirpstack Network Server config to $LORA_REGION"
cp configuration/chirpstack-network-server/examples/chirpstack-network-server.$LORA_REGION.toml configuration/chirpstack-network-server/chirpstack-network-server.toml
sed -i 's,tcp://mosquitto:1883,tcp://host.docker.internal:1883,g' configuration/chirpstack-application-server/chirpstack-application-server.toml
sed -i 's,tcp://mosquitto:1883,tcp://host.docker.internal:1883,g' configuration/chirpstack-network-server/chirpstack-network-server.toml
sed -i 's,tcp://mosquitto:1883,tcp://host.docker.internal:1883,g' configuration/chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml

sed -i 's,username=\"\",username=\"'"$MQTT_USER"'\",g' configuration/chirpstack-application-server/chirpstack-application-server.toml
sed -i 's,password=\"\",password=\"'"$MQTT_PASS"'\",g' configuration/chirpstack-application-server/chirpstack-application-server.toml
sed -i 's,username=\"\",username=\"'"$MQTT_USER"'\",g' configuration/chirpstack-network-server/chirpstack-network-server.toml
sed -i 's,password=\"\",password=\"'"$MQTT_PASS"'\",g' configuration/chirpstack-network-server/chirpstack-network-server.toml
sed -i 's,username=\"\",username=\"'"$MQTT_USER"'\",g' configuration/chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml
sed -i 's,password=\"\",password=\"'"$MQTT_PASS"'\",g' configuration/chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml

# Update Mosquitto
if [ $UPDATE_MOSQUITTO = 'true' ]; then
    echo "Updating Mosquitto for Docker..."
    . update-mosquitto.sh
    echo "Updating Mosquitto for Docker Done"
fi

#System service
SERVICE_FILE_SERVER=lorawan-server
if [ $STARTUP_SERVICE = 'true' ] && [ -f "systemd/$SERVICE_FILE_SERVER.service" ]; then
    echo "Enabling system startup service"

    sed -i 's,WorkingDirectory=.*,WorkingDirectory='"$(pwd)"'/,g' systemd/$SERVICE_FILE_SERVER.service
    if [ $ENABLE_MOSQUITTO = 'true' ]; then
        sed -i 's,ExecStart=.*,ExecStart='"$(which docker-compose)"' -f docker-compose.yml -f docker-compose-mosquitto.yml --log-level '"$LOG_LEVEL"' up,g' systemd/$SERVICE_FILE_SERVER.service
        sed -i 's,ExecStop=.*,ExecStop='"$(which docker-compose)"' -f docker-compose.yml -f docker-compose-mosquitto.yml --log-level '"$LOG_LEVEL"' stop,g' systemd/$SERVICE_FILE_SERVER.service
    else
        sed -i 's,ExecStart=.*,ExecStart='"$(which docker-compose)"' --log-level '"$LOG_LEVEL"' up,g' systemd/$SERVICE_FILE_SERVER.service
        sed -i 's,ExecStop=.*,ExecStop='"$(which docker-compose)"' --log-level '"$LOG_LEVEL"' stop,g' systemd/$SERVICE_FILE_SERVER.service
    fi

    echo "creating services $SERVICE_FILE_SERVER"
    cp systemd/$SERVICE_FILE_SERVER.service /lib/systemd/system/$SERVICE_FILE_SERVER.service
    systemctl daemon-reload
    systemctl enable $SERVICE_FILE_SERVER.service
    systemctl start $SERVICE_FILE_SERVER.service
else
    echo "No system startup service."
fi

# Restart Mosquitto
if [ $UPDATE_MOSQUITTO = 'true' ]; then
    echo "Restarting Mosquitto for changes to take effect."
    systemctl restart mosquitto.service
fi

#Init chirpstack application data

echo "Waiting for chirpstack service to start..."
CURL_EXIT_STATUS=1
set +e
while [ $CURL_EXIT_STATUS -ne 0 ]; do
    sleep 5
    echo "."
    curl -s 127.0.0.1:8080 > /dev/null
    CURL_EXIT_STATUS=$?
done
sleep 10
set -e

echo "Initialising Chirpstack aplication server"
GW_EUI=
if [ -d "gateway/rak" ]; then
    GW_EUI=$(jq -r .gateway_conf.gateway_ID gateway/rak/packet_forwarder/lora_pkt_fwd/global_conf.json)
    echo "Gateway EUI: $GW_EUI"
elif [ -d "gateway/pico" ]; then
    GW_EUI=$(jq -r .gateway_conf.gateway_ID gateway/pico/pkt_fwd/global_conf.json)
    echo "Gateway EUI: $GW_EUI"
elif [ -d "gateway/sx1302" ]; then
    GW_EUI=$(jq -r .gateway_conf.gateway_ID gateway/sx1302/global_conf.json)
    echo "Gateway EUI: $GW_EUI"
fi

if [ ! -z "$GW_EUI" ]; then
    python chirpstack-app-init.py -g $GW_EUI -r $LORA_REGION -b $LORA_REGION_BAND -p $SERVER_PASSWORD
else
    python chirpstack-app-init.py -p $SERVER_PASSWORD
fi
echo
echo "Finished"
