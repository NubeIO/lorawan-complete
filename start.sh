#!/bin/bash

set -e

LOG_LEVEL=WARNING
PKT_FWD_DIR=""


if [ -d "$PKT_FWD_DIR" ] && [ -f "$PKT_FWD_DIR/lora_pkt_fwd" ]; then
    docker-compose --log-level $LOG_LEVEL up -d
    pushd $PKT_FWD_DIR
    ./lora_pkt_fwd
else
    docker-compose --log-level $LOG_LEVEL up
fi