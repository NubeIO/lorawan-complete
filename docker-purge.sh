#!/bin/bash


if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

echo "Purging Docker..."

docker stop $(sudo docker ps -aq)
docker rm $(sudo docker ps -aq)
docker rmi $(sudo docker images -aq)

apt-get purge -y docker-ce docker-ce-cli containerd.io

rm -rf /var/lib/docker
rm -rf /var/lib/containerd

echo ""
echo "Done"
