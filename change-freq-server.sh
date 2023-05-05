#!/bin/bash
set -e

# -- User Config --
LORA_REGION="au915"
LORA_REGION_BAND=0
SERVER_USER="admin"
SERVER_PASS="admin"
MQTT_USER=""
MQTT_PASS=""


print_usage() {
    echo
    echo " -r <region>       : Region [au915, us915, eu868, as923, as920]"
    echo " -b <band>         : Region Band [0,1] (for AU and US)"
    # echo " -u <user>         : Server username"
    # echo " -p <pass>         : Server password"
    echo " -U <mqtt user>    : MQTT username"
    echo " -P <mqtt pass>    : MQTT password"
}

while getopts 'r:b:u:p:U:P:h' flag; do
    case "${flag}" in
        r) LORA_REGION="${OPTARG}"
            echo "LoRaWAN Region set to $LORA_REGION" ;;
        b) LORA_REGION_BAND="${OPTARG}"
            echo "Region Band set to $LORA_REGION_BAND" ;;
        u) SERVER_USER="${OPTARG}" ;;
        p) SERVER_PASS="${OPTARG}" ;;
        U) MQTT_USER="${OPTARG}" ;;
        P) MQTT_PASS="${OPTARG}" ;;
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

if ! [ -f configuration/chirpstack-network-server/examples/chirpstack-network-server.$LORA_REGION.toml ]; then
    echo "ERROR: No Chirpstack network server config file found for that frequency plan"
    exit 1
fi

echo "Stopping server"
systemctl stop lorawan-server.service

echo "Setting Chirpstack Network Server config to $LORA_REGION"
cp configuration/chirpstack-network-server/examples/chirpstack-network-server.$LORA_REGION.toml configuration/chirpstack-network-server/chirpstack-network-server.toml
sed -i 's,tcp://mosquitto:1883,tcp://host.docker.internal:1883,g' configuration/chirpstack-network-server/chirpstack-network-server.toml
sed -i 's,username=\"\",username=\"'"$MQTT_USER"'\",g' configuration/chirpstack-network-server/chirpstack-network-server.toml
sed -i 's,password=\"\",password=\"'"$MQTT_PASS"'\",g' configuration/chirpstack-network-server/chirpstack-network-server.toml

echo "Pls manually change the gateway configuration on the server lol I cbf to automate it thanks for coming."
echo "Restarting server..."
systemctl restart lorawan-server.service
