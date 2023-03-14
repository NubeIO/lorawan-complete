#!/bin/bash
set -e


# -- User Config --
LORA_REGION="au915"
LORA_REGION_BAND=0

GATEWAY_INSTALL='true'
STARTUP_SERVICE='true'
LOG_LEVEL=WARNING

SERV_ADDR="localhost"
SERV_PORT_UP=1700
SERV_PORT_DOWN=1700

VERSION_DRIVER="2.1.0"

# Other
PKT_FWD_DIR="gateway/sx1302"

print_usage() {
    echo
    echo " -r <region>    : Region [au915]. Default au915"
    echo " -b <band>      : Region Band [0,1] (for AU and US).   Default 0"
    echo " -a <IP>        : Server address.               Default localhost"
    echo " -u <port>      : Server port up.               Default 1700"
    echo " -d <port>      : Server port down.             Default 1700"
    echo " -s             : Disable startup service"
}

while getopts 'r:b:a:u:d:sh' flag; do
    case "${flag}" in
        r) LORA_REGION="${OPTARG}"
            echo "LoRaWAN Region set to $LORA_REGION" ;;
        b) LORA_REGION_BAND="${OPTARG}"
            echo "Region Band set to $LORA_REGION_BAND" ;;
        a) SERV_ADDR="${OPTARG}"
            echo "Server address set to $SERV_ADDR" ;;
        u) SERV_PORT_UP="${OPTARG}"
            echo "Server port up set to $SERV_PORT_UP" ;;
        d) SERV_PORT_DOWN="${OPTARG}"
            echo "Server port down set to $SERV_PORT_DOWN" ;;
        s) STARTUP_SERVICE='false' ;;
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


#Packet Forwarder
if [ ! -f "$PKT_FWD_DIR/lora_pkt_fwd" ]; then

    echo "Installing Gateway..."

    sed -i 's,PKT_FWD_DIR=.*,PKT_FWD_DIR="'"$PKT_FWD_DIR"'",g' start.sh

    if [ ! -d "$PKT_FWD_DIR" ]; then
        mkdir $PKT_FWD_DIR -p
    fi
    pushd $PKT_FWD_DIR
        set +e
        rm -r ./*
        set -e

        # Build USB driver
        wget https://github.com/Lora-net/sx1302_hal/archive/refs/tags/V$VERSION_DRIVER.zip -O sx1302_hal.zip
        unzip sx1302_hal.zip
        rm sx1302_hal.zip
        mkdir bin
        pushd sx1302_hal-$VERSION_DRIVER
            make clean all
            mv packet_forwarder/lora_pkt_fwd ../bin/
            mv util_chip_id/chip_id ../bin/
            mv tools/reset_lgw.sh ../bin/
            cp ../../../configuration/gateway/sx1302/global_conf.$LORA_REGION.$LORA_REGION_BAND.json ../bin/global_conf.json
        popd
        rm -r sx1302_hal-$VERSION_DRIVER
        mv bin/* ./
        rm -r bin

        sed -i 's,/\*.*,,g' global_conf.json
        GWID=$(./chip_id -u -d /dev/ttyACM0 | grep "concentrator EUI: " | cut -c 27-)
        sed -i 's/\(^\s*"gateway_ID":\s*"\).\{16\}"\s*\(,\?\).*$/\1'${GWID}'"\2/' global_conf.json
        sed -i 's/\"server_address\":.*/\"server_address\": \"'"$SERV_ADDR"'\",/g' global_conf.json
        sed -i 's/\"serv_port_up\":.*/\"serv_port_up\": '"$SERV_PORT_UP"',/g' global_conf.json
        sed -i 's/\"serv_port_down\":.*/\"serv_port_down\": '"$SERV_PORT_DOWN"',/g' global_conf.json
        chmod +x lora_pkt_fwd
    popd
    echo "Done"
else
    echo "Gateway already installed..."
fi


#System service
SERVICE_FILE_GATEWAY=lorawan-gateway
if [ $STARTUP_SERVICE = 'true' ] && [ -f "systemd/$SERVICE_FILE_GATEWAY.service" ]; then
    echo "Enabling system startup service"

    sed -i 's,WorkingDirectory=.*,WorkingDirectory='"$(pwd)/$PKT_FWD_DIR/"',g' systemd/$SERVICE_FILE_GATEWAY.service
    sed -i 's,ExecStart=.*,ExecStart='"$(pwd)/$PKT_FWD_DIR/lora_pkt_fwd"',g' systemd/$SERVICE_FILE_GATEWAY.service

    echo "creating service $SERVICE_FILE_GATEWAY"
    cp systemd/$SERVICE_FILE_GATEWAY.service /lib/systemd/system/$SERVICE_FILE_GATEWAY.service
    systemctl daemon-reload
    systemctl enable $SERVICE_FILE_GATEWAY.service
    service $SERVICE_FILE_GATEWAY start
else
    echo "No system startup service..."
fi
