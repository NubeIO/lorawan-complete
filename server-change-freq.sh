#!/bin/bash
set -e

# -- User Config --
LORA_REGION="au915"


print_usage() {
    echo
    echo " -r <region>       : Region [au915, us902, eu868]"
}

while getopts 'r:h' flag; do
    case "${flag}" in
        r) LORA_REGION="${OPTARG}"
            echo "LoRaWAN Region set to $LORA_REGION" ;;
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

echo "Setting Chirpstack Network Server config to $LORA_REGION"
cp configuration/chirpstack-network-server/examples/chirpstack-network-server.$LORA_REGION.toml configuration/chirpstack-network-server/chirpstack-network-server.toml

systemctl restart lorawan-server.service