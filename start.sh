#!/bin/bash

set -e

LOG_LEVEL=WARNING
PKT_FWD_DIR="gateway"

if [ ! -d "$PKT_FWD_DIR" ]; then
    echo "no gateway installed. exiting."
    exit 1
fi




if [ -f "$PKT_FWD_DIR/packet_forwarder/lora_pkt_fwd/lora_pkt_fwd" ]; then
    docker-compose --log-level $LOG_LEVEL up -d
    pushd $PKT_FWD_DIR/packet_forwarder/lora_pkt_fwd
    ./lora_pkt_fwd
else
    docker-compose --log-level $LOG_LEVEL up
fi