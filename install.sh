#!/bin/bash
set -e


# -- User Config --
BUILD_ARCH="arm32v7"
LORA_MODULE="rak2247_usb"
LORA_REGION="au915_928"
LORA_REGION_BAND=0

GATEWAY_INSTALL='true'
STARTUP_SERVICE='true'

# Other
PKT_FWD_DIR="gateway"
NIC="eth0"

print_usage() {
    echo
    echo " -r <region>    : Region [au915-928]"
    echo " -b <band>      : Region Band [0,2]"
    echo " -n <NIC>       : Provide NIC name"
    echo " -g             : Disable gateway install"
    echo " -s             : Disable startup service"
}

while getopts 'r:b:n:gsh' flag; do
    case "${flag}" in
        r) LORA_REGION="${OPTARG}"
            echo "LoRaWAN Region set to $LORA_REGION" ;;
        b) LORA_REGION_BAND="${OPTARG}"
            echo "Region Band set to $LORA_REGION_BAND" ;;
        n) NIC="${OPTARG}"
            echo "NIC set to $NIC" ;;
        g) GATEWAY_INSTALL='false' ;;
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

            ./install.sh

            cp ../set_eui.sh packet_forwarder/lora_pkt_fwd/
            cp ../update_gwid.sh packet_forwarder/lora_pkt_fwd/
            cp ../start.sh packet_forwarder/lora_pkt_fwd/
            
            # cp global_conf/global_conf.$LORA_REGION.json packet_forwarder/lora_pkt_fwd/global_conf.json
            # sed -i "s/^.*server_address.*$/\t\"server_address\": \"127.0.0.1\",/" packet_forwarder/lora_pkt_fwd/global_conf.json
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

#System service
SERVICE_FILE=lorawan-complete
if [ $STARTUP_SERVICE = 'true' ] && [ -f "systemd/$SERVICE_FILE.service" ]; then
    echo "Enabling system startup service"
    sed -i 's,WorkingDirectory=.*,WorkingDirectory='"$(pwd)"'/,g' systemd/$SERVICE_FILE.service
    sed -i 's,ExecStart=.*,ExecStart=/bin/bash '"$(pwd)"'/start.sh,g' systemd/$SERVICE_FILE.service
    sed -i 's,ExecStop=.*,ExecStop=/bin/bash '"$(pwd)"'/stop.sh,g' systemd/$SERVICE_FILE.service
    # sed -i 's,ExecStart=.*,ExecStart='"$(which docker-compose)"' up,g' systemd/$SERVICE_FILE.service
    cp systemd/$SERVICE_FILE.service /etc/systemd/system/$SERVICE_FILE.service
    systemctl daemon-reload
    systemctl enable $SERVICE_FILE.service
    service $SERVICE_FILE start
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
python chirpstack-app-init.py $GW_EUI
echo
echo "Finished"