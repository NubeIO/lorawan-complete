#!/bin/bash
set -e


# -- User Config --
LORA_MODULE="rak2247_usb"
LORA_REGION="au915"
LORA_REGION_BAND=0

GATEWAY_INSTALL='true'
STARTUP_SERVICE='true'
LOG_LEVEL=WARNING

SERV_ADDR="localhost"
SERV_PORT_UP=1700
SERV_PORT_DOWN=1700

VERSION_PKT_FWD=4.2.8

# Other
PKT_FWD_DIR="gateway/rak"
NIC="eth0"

print_usage() {
    echo
    echo " -r <region>   : Region [au915, us902, eu868, as923]. Default au915"
    echo " -b <band>     : Region Band [0,1] (for AU and US).   Default 0"
    echo " -n <NIC>      : Provide NIC name (helps set gateway EUI). Default eth0"
    echo " -a <IP>       : Server address.               Default localhost"
    echo " -u <port>     : Server port up.               Default 1700"
    echo " -d <port>     : Server port down.             Default 1700"
    echo " -s            : Disable startup service"
}

while getopts 'r:b:n:a:u:d:sh' flag; do
    case "${flag}" in
        r) LORA_REGION="${OPTARG}"
            echo "LoRaWAN Region set to $LORA_REGION" ;;
        b) LORA_REGION_BAND="${OPTARG}"
            echo "Region Band set to $LORA_REGION_BAND" ;;
        n) NIC="${OPTARG}"
            echo "NIC set to $NIC" ;;
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

if [ ! -f "$PKT_FWD_DIR/packet_forwarder/lora_pkt_fwd/lora_pkt_fwd" ]; then

    echo "Installing Gateway..."

    sed -i 's,PKT_FWD_DIR=.*,PKT_FWD_DIR="'"$PKT_FWD_DIR/packet_forwarder/lora_pkt_fwd/"'",g' start.sh

    if [ ! -d "$PKT_FWD_DIR" ]; then
        mkdir -p $PKT_FWD_DIR
    fi
    pushd $PKT_FWD_DIR
        set +e
        rm -r ./*
        set -e
        wget https://github.com/RAKWireless/rak_common_for_gateway/archive/refs/tags/$VERSION_PKT_FWD.zip -O rak_common_for_gateway.zip
        unzip rak_common_for_gateway.zip
        rm rak_common_for_gateway.zip
        pushd rak_common_for_gateway-$VERSION_PKT_FWD/lora/$LORA_MODULE

            sed -i 's,GATEWAY_EUI_NIC=.*,GATEWAY_EUI_NIC="'"$NIC"'",g' ../update_gwid.sh

            ./install.sh

            cp ../update_gwid.sh packet_forwarder/lora_pkt_fwd/
            cp ../start.sh packet_forwarder/lora_pkt_fwd/

            cp ../../../../../configuration/gateway/rak/global_conf.$LORA_REGION.$LORA_REGION_BAND.json packet_forwarder/lora_pkt_fwd/global_conf.json

            pushd packet_forwarder/lora_pkt_fwd
                # remove comment lines...
                sed -i 's,/\*.*,,g' global_conf.json

                bash update_gwid.sh global_conf.json

                sed -i 's/\"server_address\":.*/\"server_address\": \"'"$SERV_ADDR"'\",/g' global_conf.json
                sed -i 's/\"serv_port_up\":.*/\"serv_port_up\": '"$SERV_PORT_UP"',/g' global_conf.json
                sed -i 's/\"serv_port_down\":.*/\"serv_port_down\": '"$SERV_PORT_DOWN"',/g' global_conf.json
            popd
        popd
        mv rak_common_for_gateway-$VERSION_PKT_FWD/lora/$LORA_MODULE/packet_forwarder/ .
        rm -r rak_common_for_gateway-$VERSION_PKT_FWD/
        chmod +x packet_forwarder/lora_pkt_fwd/start.sh packet_forwarder/lora_pkt_fwd/lora_pkt_fwd
    popd
    echo "Done"
else
    echo "Gateway already installed..."
fi


#System service
SERVICE_FILE_GATEWAY=lorawan-gateway
if [ $STARTUP_SERVICE = 'true' ] && [ -f "systemd/$SERVICE_FILE_GATEWAY.service" ]; then
    echo "Enabling system startup service"
    
    sed -i 's,WorkingDirectory=.*,WorkingDirectory='"$(pwd)/$PKT_FWD_DIR/packet_forwarder/lora_pkt_fwd/"',g' systemd/$SERVICE_FILE_GATEWAY.service
    sed -i 's,ExecStart=.*,ExecStart='"$(pwd)/$PKT_FWD_DIR/packet_forwarder/lora_pkt_fwd/lora_pkt_fwd"',g' systemd/$SERVICE_FILE_GATEWAY.service

    echo "creating service $SERVICE_FILE_GATEWAY"
    cp systemd/$SERVICE_FILE_GATEWAY.service /etc/systemd/system/$SERVICE_FILE_GATEWAY.service
    systemctl daemon-reload
    systemctl enable $SERVICE_FILE_GATEWAY.service
    service $SERVICE_FILE_GATEWAY start
else
    echo "No system startup service..."
fi