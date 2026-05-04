#!/bin/bash
set -e

# Native amd64 build of the Chirpstack images.
# No QEMU / cross-compile patching needed: Go builds natively on the host.
BUILD_ARCH="amd64"
BUILD_OS="debian"
BUILD_PLATFORM="linux/amd64"

REPOS=(
    "chirpstack-network-server"
    "chirpstack-application-server"
    "chirpstack-gateway-bridge"
)

# ---------------------------------------------------------------------------
# Always start from a clean clone.
# ---------------------------------------------------------------------------
echo "Cleaning any previous clones"
for r in "${REPOS[@]}"; do
    rm -rf "$r"
done

echo "Cloning Chirpstack git repos"
git clone https://github.com/brocaar/chirpstack-network-server
git clone https://github.com/brocaar/chirpstack-application-server
git clone https://github.com/brocaar/chirpstack-gateway-bridge

# ---------------------------------------------------------------------------
# Sanity check the base image is available for amd64.
# ---------------------------------------------------------------------------
docker pull --platform "$BUILD_PLATFORM" "$BUILD_OS"
docker run --rm --platform "$BUILD_PLATFORM" -t "$BUILD_OS" uname -m

# ---------------------------------------------------------------------------
# Use buildx for nicer caching / --platform support, even though we're
# building natively.
# ---------------------------------------------------------------------------
export DOCKER_CLI_EXPERIMENTAL=enabled
set +e
docker buildx create --name amd64builder
set -e
docker buildx use amd64builder
docker buildx inspect --bootstrap

echo
echo "amd64 build setup complete"
echo

# ---------------------------------------------------------------------------
# Build helper:
#   --cache-to/--cache-from caches the Go module download + build cache
#   locally so subsequent builds are dramatically faster.
# ---------------------------------------------------------------------------
build_image() {
    local name="$1"
    local context="$2"
    local tag="${name}-${BUILD_ARCH}-local"
    local cache_dir="/tmp/buildx-cache/${name}"
    mkdir -p "$cache_dir"

    echo
    echo "BUILDING ${name}"
    docker buildx build \
        --platform "$BUILD_PLATFORM" \
        --cache-to   "type=local,dest=${cache_dir},mode=max" \
        --cache-from "type=local,src=${cache_dir}" \
        -t "$tag" \
        "$context" \
        --load

    docker save -o "${tag}.tar" "$tag"
    docker rmi "$tag"
    echo "BUILD ${name} COMPLETE"
}

build_image chirpstack-network-server     chirpstack-network-server/
build_image chirpstack-application-server chirpstack-application-server/
build_image chirpstack-gateway-bridge     chirpstack-gateway-bridge/

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
echo
echo "Cleaning up"
for r in "${REPOS[@]}"; do
    rm -rf "$r"
done
echo
echo "Finished"
