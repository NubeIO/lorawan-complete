#!/bin/bash
set -e


# -- User Config --
BUILD_ARCH="arm32v7"
LORA_MODULE="rak2247_usb"
LORA_REGION="au915"
LORA_REGION_BAND=0

GATEWAY_INSTALL='true'
STARTUP_SERVICE='true'
ENABLE_MOSQUITTO='true'
LOG_LEVEL=WARNING

# Other
PKT_FWD_DIR="gateway"
NIC="eth0"

print_usage() {
    echo
    echo " -r <region>    : Region [au915, us902]"
    echo " -b <band>      : Region Band [0,1]"
    echo " -n <NIC>       : Provide NIC name"
    echo " -g             : Disable gateway install"
    echo " -s             : Disable startup service"
    echo " -m             : Disable Mosquitto"
}

while getopts 'r:b:n:gsmh' flag; do
    case "${flag}" in
        r) LORA_REGION="${OPTARG}"
            echo "LoRaWAN Region set to $LORA_REGION" ;;
        b) LORA_REGION_BAND="${OPTARG}"
            echo "Region Band set to $LORA_REGION_BAND" ;;
        n) NIC="${OPTARG}"
            echo "NIC set to $NIC" ;;
        g) GATEWAY_INSTALL='false' ;;
        s) STARTUP_SERVICE='false' ;;
        m) ENABLE_MOSQUITTO='false' ;;
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

chmod +x uninstall.sh start.sh stop.sh

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
    usermod -aG docker $USER
    set +e
    usermod -aG docker $(who am i | awk '{print $1}')
    set -e
fi
# Install requirements
apt install -y docker-compose git python-pip python3-pip jq
pip install requests
echo "Done"

#Packet Forwarder

if [ $GATEWAY_INSTALL = 'true' ] && [ ! -f "$PKT_FWD_DIR/packet_forwarder/lora_pkt_fwd/lora_pkt_fwd" ]; then

    echo "Installing Gateway..."

    sed -i 's,PKT_FWD_DIR=.*,PKT_FWD_DIR="'"$PKT_FWD_DIR"'",g' start.sh

    if [ ! -d "$PKT_FWD_DIR" ]; then
        mkdir $PKT_FWD_DIR
    fi
    pushd $PKT_FWD_DIR
        set +e
        rm -r ./*
        set -e
        git clone https://github.com/RAKWireless/rak_common_for_gateway
        pushd rak_common_for_gateway/lora/$LORA_MODULE

            sed -i 's,GATEWAY_EUI_NIC=.*,GATEWAY_EUI_NIC="'"$NIC"'",g' ../set_eui.sh
            sed -i 's,GATEWAY_EUI_NIC=.*,GATEWAY_EUI_NIC="'"$NIC"'",g' ../update_gwid.sh
            sed -i 's,LOCAL_CONFIG_FILE=.*,LOCAL_CONFIG_FILE=../../../../configuration/gateway/global_conf.'"$LORA_REGION.$LORA_REGION_BAND"'.json,g' ../set_eui.sh

            ./install.sh

            cp ../set_eui.sh packet_forwarder/lora_pkt_fwd/
            cp ../update_gwid.sh packet_forwarder/lora_pkt_fwd/
            cp ../start.sh packet_forwarder/lora_pkt_fwd/
            
            # old config copy from rak folder
            # cp global_conf/global_conf.$LORA_REGION.json packet_forwarder/lora_pkt_fwd/global_conf.json
            # sed -i "s/^.*server_address.*$/\t\"server_address\": \"127.0.0.1\",/" packet_forwarder/lora_pkt_fwd/global_conf.json
            # new pre configured config file
            cp ../../../../configuration/gateway/global_conf.$LORA_REGION.$LORA_REGION_BAND.json packet_forwarder/lora_pkt_fwd/global_conf.json
            # remove comment lines...
            sed -i 's,/\*.*,,g' packet_forwarder/lora_pkt_fwd/global_conf.json
        popd
        cp -r rak_common_for_gateway/lora/$LORA_MODULE/packet_forwarder/ .
        rm -r rak_common_for_gateway/
        chmod +x packet_forwarder/lora_pkt_fwd/start.sh packet_forwarder/lora_pkt_fwd/lora_pkt_fwd
    popd
    echo "Done"
else
    echo "Skipping Gateway install..."
fi


#Chirpstack
echo "Loading Docker images..."
docker load -i build/chirpstack-network-server-$BUILD_ARCH-local.tar
docker load -i build/chirpstack-application-server-$BUILD_ARCH-local.tar
docker load -i build/chirpstack-gateway-bridge-$BUILD_ARCH-local.tar
echo "Done"

#Chirpstack Network Server Config
echo "Setting Chirpstack Network Server config to $LORA_REGION band $LORA_REGION_BAND"
cp configuration/chirpstack-network-server/examples/chirpstack-network-server.$LORA_REGION.$LORA_REGION_BAND.toml configuration/chirpstack-network-server/chirpstack-network-server.toml

#System service
SERVICE_FILE_SERVER=lorawan-server
SERVICE_FILE_GATEWAY=lorawan-gateway
if [ $STARTUP_SERVICE = 'true' ] && [ -f "systemd/$SERVICE_FILE_SERVER.service" ] && [ -f "systemd/$SERVICE_FILE_GATEWAY.service" ]; then
    echo "Enabling system startup service"
    
    sed -i 's,WorkingDirectory=.*,WorkingDirectory='"$(pwd)"'/,g' systemd/$SERVICE_FILE_SERVER.service
    if [ $ENABLE_MOSQUITTO = 'true' ]; then
        sed -i 's,ExecStart=.*,ExecStart='"$(which docker-compose)"' -f docker-compose.yml -f docker-compose-mosquitto.yml --log-level '"$LOG_LEVEL"' up,g' systemd/$SERVICE_FILE_SERVER.service
        sed -i 's,ExecStop=.*,ExecStop='"$(which docker-compose)"' -f docker-compose.yml -f docker-compose-mosquitto.yml --log-level '"$LOG_LEVEL"' stop,g' systemd/$SERVICE_FILE_SERVER.service
    else
        sed -i 's,ExecStart=.*,ExecStart='"$(which docker-compose)"' --log-level '"$LOG_LEVEL"' up,g' systemd/$SERVICE_FILE_SERVER.service
        sed -i 's,ExecStop=.*,ExecStop='"$(which docker-compose)"' --log-level '"$LOG_LEVEL"' stop,g' systemd/$SERVICE_FILE_SERVER.service

        sed -i 's,tcp://mosquitto:1883,tcp://host.docker.internal:1883,g' configuration/chirpstack-application-server/chirpstack-application-server.toml
        sed -i 's,tcp://mosquitto:1883,tcp://host.docker.internal:1883,g' configuration/chirpstack-network-server/chirpstack-network-server.toml
        sed -i 's,tcp://mosquitto:1883,tcp://host.docker.internal:1883,g' configuration/chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml
    fi
    sed -i 's,WorkingDirectory=.*,WorkingDirectory='"$(pwd)/$PKT_FWD_DIR/packet_forwarder/lora_pkt_fwd/"',g' systemd/$SERVICE_FILE_GATEWAY.service
    sed -i 's,ExecStart=.*,ExecStart='"$(pwd)/$PKT_FWD_DIR/packet_forwarder/lora_pkt_fwd/lora_pkt_fwd"',g' systemd/$SERVICE_FILE_GATEWAY.service

    echo "creating services $SERVICE_FILE_SERVER and $SERVICE_FILE_GATEWAY"
    cp systemd/$SERVICE_FILE_SERVER.service /etc/systemd/system/$SERVICE_FILE_SERVER.service
    cp systemd/$SERVICE_FILE_GATEWAY.service /etc/systemd/system/$SERVICE_FILE_GATEWAY.service
    systemctl daemon-reload
    systemctl enable $SERVICE_FILE_SERVER.service
    systemctl enable $SERVICE_FILE_GATEWAY.service
    service $SERVICE_FILE_SERVER start
    service $SERVICE_FILE_GATEWAY start
else
    echo "No system startup service... starting docker-compose daemon"
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
if [ $GATEWAY_INSTALL = 'true' ]; then
    GW_EUI=$(jq -r .gateway_conf.gateway_ID gateway/packet_forwarder/lora_pkt_fwd/global_conf.json)
    echo "Gateway EUI: $GW_EUI"
fi
python chirpstack-app-init.py $GW_EUI $LORA_REGION_BAND
echo
echo "Finished"