#!/bin/bash
set +e

if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

#System service
SERVICE_FILE_GATEWAY=lorawan-gateway
echo "Removing system service"
if [ -f "/lib/systemd/system/$SERVICE_FILE_GATEWAY.service" ]; then
    service $SERVICE_FILE_GATEWAY stop
    systemctl disable $SERVICE_FILE_GATEWAY.service
    sudo rm /lib/systemd/system/$SERVICE_FILE_GATEWAY.service
fi
systemctl daemon-reload
echo "Done"
echo "Removing Gateway..."
if [ -d "gateway" ]; then
    rm -r gateway
fi
echo "Finished"