#!/bin/bash
set +e

print_usage() {
    echo
    echo "Removes all Chirpstack docker contianers and images. Used to update Chirpstack version."
}

while getopts 'h' flag; do
    case "${flag}" in
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

echo ""
echo "Stopping lorawan-server service"
systemctl stop lorawan-server

echo ""
echo "Removing Chirpstack Docker containers and images"
docker ps -a | awk '{ print $1,$2 }' | grep chirpstack | awk '{print $1 }' | xargs -I {} docker stop {}
docker ps -a | awk '{ print $1,$2 }' | grep chirpstack | awk '{print $1 }' | xargs -I {} docker rm {}
docker images -a | awk '{ print $1,$2 }' | grep chirpstack | awk '{print $1":"$2 }' | xargs -I {} docker rmi {}

echo ""
echo "Done"