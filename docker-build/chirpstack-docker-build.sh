#!/bin/bash
set -e

# https://github.com/multiarch/qemu-user-static#getting-started
BUILD_ARCH="arm32v7"
BUILD_OS="debian"
BUILD_PLATFORM="linux/arm/v7"

echo "Cloning Chirpstack git repos"
set +e
git clone https://github.com/brocaar/chirpstack-network-server
git clone https://github.com/brocaar/chirpstack-application-server
git clone https://github.com/brocaar/chirpstack-gateway-bridge
set -e
# docker multiarch build support
# https://github.com/docker/buildx/issues/138
echo "Enabling support for multi architecture building for $BUILD_ARCH/$BUILD_OS"
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker run --rm -t $BUILD_ARCH/$BUILD_OS uname -m

# enable buildx
export DOCKER_CLI_EXPERIMENTAL=enabled
# create new buildx builder with the added arm support from above
set +e
docker buildx create --name armbuilder
set -e
docker buildx use armbuilder
docker buildx inspect --bootstrap

# edit dockerfile to take in target platform
sed -i '/RUN make$/i \\nCOPY --from=tonistiigi\/xx:golang \/ \/\nARG TARGETPLATFORM\n' chirpstack-network-server/Dockerfile
sed -i '/RUN make$/i \\nCOPY --from=tonistiigi\/xx:golang \/ \/\nARG TARGETPLATFORM\n' chirpstack-application-server/Dockerfile
sed -i '/RUN make$/i \\nCOPY --from=tonistiigi\/xx:golang \/ \/\nARG TARGETPLATFORM\n' chirpstack-gateway-bridge/Dockerfile

echo
echo "Multi arch setup complete"

# build for arm
echo
echo "BUILDING CHIRPSTACK-NETWORK-SERVER"
docker buildx build --platform $BUILD_PLATFORM -t chirpstack-network-server-$BUILD_ARCH-local chirpstack-network-server/ --load
docker save -o chirpstack-network-server-$BUILD_ARCH-local.tar chirpstack-network-server-$BUILD_ARCH-local
docker rmi chirpstack-network-server-$BUILD_ARCH-local
echo
echo "BUILD CHIRPSTACK-NETWORK-SERVER COMPLETE"
echo
echo "BUILDING CHIRPSTACK-APPLICATION-SERVER"
docker buildx build --platform $BUILD_PLATFORM -t chirpstack-application-server-$BUILD_ARCH-local chirpstack-application-server/ --load
docker save -o chirpstack-application-server-$BUILD_ARCH-local.tar chirpstack-application-server-$BUILD_ARCH-local
docker rmi chirpstack-application-server-$BUILD_ARCH-local
echo
echo "BUILD CHIRPSTACK-APPLICATION-SERVER COMPLETE"
echo
echo "BUILDING CHIRPSTACK-GATEWAY-BRIDGE"
docker buildx build --platform $BUILD_PLATFORM -t chirpstack-gateway-bridge-$BUILD_ARCH-local chirpstack-gateway-bridge/ --load
docker save -o chirpstack-gateway-bridge-$BUILD_ARCH-local.tar chirpstack-gateway-bridge-$BUILD_ARCH-local
docker rmi chirpstack-gateway-bridge-$BUILD_ARCH-local
echo
echo "BUILD CHIRPSTACK-GATEWAY-BRIDGE COMPLETE"

#remove repos
echo "Cleaning up"
rm -rf chirpstack-network-server/
rm -rf chirpstack-application-server/
rm -rf chirpstack-gateway-bridge/
echo
echo "Finished"