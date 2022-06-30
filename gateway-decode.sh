#!/bin/bash
set -e

# -- User Config --
CONCENTRATOR="pico"
PKT_FWD_DIR_RAK="gateway/rak/packet_forwarder/lora_pkt_fwd/"
UP_DIR_RAK="../../../../"
PKT_FWD_DIR_PICO="gateway/pico/pkt_fwd/"
UP_DIR_PICO="../../../"
PKT_FWD_DIR=$PKT_FWD_DIR_PICO
UP_DIR=$UP_DIR_PICO
FLAGS=

print_usage() {
    echo
    echo " -c <concentrator>  : Concentrator (rak/pico). Default pico"
    echo " -j                 : Print non-formatted JSON"
}

while getopts 'c:jh' flag; do
    case "${flag}" in
        c) if [ "${OPTARG}" == "pico" ]; then
            PKT_FWD_DIR=$PKT_FWD_DIR_PICO
            UP_DIR=$UP_DIR_PICO
           else
            PKT_FWD_DIR=$PKT_FWD_DIR_RAK
            UP_DIR=$UP_DIR_RAK
           fi ;;
        j) FLAGS="--json";;
        h) print_usage
            exit 1 ;;
        *) print_usage
            exit 1 ;;
    esac
done

pushd $PKT_FWD_DIR > /dev/null
    stdbuf -o 0 ./lora_pkt_fwd | node $UP_DIR/gateway-decoder/decode.js $FLAGS
popd > /dev/null
