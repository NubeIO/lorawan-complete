#!/bin/bash
set -e

# -- User Config --
PKT_FWD_DIR="gateway"
LORA_MODULE="rak"
LORA_REGION="au915"
LORA_REGION_BAND=0

CFG_DIR=""

print_usage() {
    echo
    echo " -r <region>       : Region [au915, us915, eu868, as923, as920]"
    echo " -b <band>         : Region Band [0,1] (for AU and US)"
    echo " -c <concentrator> : Concentrator [rak, pico]"
}

while getopts 'r:b:c:h' flag; do
    case "${flag}" in
        r) LORA_REGION="${OPTARG}"
            echo "LoRaWAN Region set to $LORA_REGION" ;;
        b) LORA_REGION_BAND="${OPTARG}"
            echo "Region Band set to $LORA_REGION_BAND" ;;
        c) LORA_MODULE="${OPTARG}"
            echo "Concentrator set to $LORA_MODULE" ;;
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

if ! [ -f configuration/gateway/$LORA_MODULE/global_conf.$LORA_REGION.$LORA_REGION_BAND.json ]; then
    echo "ERROR: No Packet forwarder config file found for that frequency plan"
    exit 1
fi

if [ -d "$PKT_FWD_DIR/rak" ]; then
    CFG_DIR="$PKT_FWD_DIR/rak/packet_forwarder/lora_pkt_fwd"
elif [ -d "$PKT_FWD_DIR/pico" ]; then
    CFG_DIR="$PKT_FWD_DIR/pico/pkt_fwd"
fi

sed -i 's,/\*.*,,g' $CFG_DIR/global_conf.json
GW_EUI=$(jq -r .gateway_conf.gateway_ID $CFG_DIR/global_conf.json)
SERV_ADDR=$(jq -r .gateway_conf.server_address $CFG_DIR/global_conf.json)
SERV_PORT_UP=$(jq -r .gateway_conf.serv_port_up $CFG_DIR/global_conf.json)
SERV_PORT_DOWN=$(jq -r .gateway_conf.serv_port_down $CFG_DIR/global_conf.json)

mv $CFG_DIR/global_conf.json $CFG_DIR/global_conf.json.OLD
cp configuration/gateway/$LORA_MODULE/global_conf.$LORA_REGION.$LORA_REGION_BAND.json $CFG_DIR/global_conf.json
sed -i 's,/\*.*,,g' $CFG_DIR/global_conf.json
sed -i 's/\"gateway_ID\":.*/\"gateway_ID\": \"'"$GW_EUI"'\",/g' $CFG_DIR/global_conf.json
sed -i 's/\"server_address\":.*/\"server_address\": \"'"$SERV_ADDR"'\",/g' $CFG_DIR/global_conf.json
sed -i 's/\"serv_port_up\":.*/\"serv_port_up\": '"$SERV_PORT_UP"',/g' $CFG_DIR/global_conf.json
sed -i 's/\"serv_port_down\":.*/\"serv_port_down\": '"$SERV_PORT_DOWN"',/g' $CFG_DIR/global_conf.json

systemctl restart lorawan-gateway.service
