#!/bin/bash
set -e

# https://github.com/multiarch/qemu-user-static#getting-started
BUILD_ARCH="arm32v7"
BUILD_OS="debian"
BUILD_PLATFORM="linux/arm/v7"

REPOS=(
    "chirpstack-network-server"
    "chirpstack-application-server"
    "chirpstack-gateway-bridge"
)

# ---------------------------------------------------------------------------
# Always start from a clean clone. If we don't, a second run would re-apply
# the Dockerfile patch on top of an already-patched file and stack the
# injected lines (this is what caused the 6x COPY --from=tonistiigi/xx the
# previous run).
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
# Multi-arch / QEMU setup
# ---------------------------------------------------------------------------
echo "Enabling support for multi architecture building for $BUILD_ARCH/$BUILD_OS"
docker run --rm --privileged tonistiigi/binfmt --install all

# Pre-pull the ARM base image so the sanity check below doesn't fail with
# "no matching manifest for linux/amd64".
docker pull --platform "$BUILD_PLATFORM" "$BUILD_ARCH/$BUILD_OS"
docker run --rm --platform "$BUILD_PLATFORM" -t "$BUILD_ARCH/$BUILD_OS" uname -m

export DOCKER_CLI_EXPERIMENTAL=enabled
set +e
docker buildx create --name armbuilder
set -e
docker buildx use armbuilder
docker buildx inspect --bootstrap

# ---------------------------------------------------------------------------
# Patch each Dockerfile to CROSS-COMPILE instead of running Go under QEMU.
#
# Why: emulating `go build` under QEMU is 5-20x slower than native. The
# tonistiigi/xx helper provides `xx-go`, which cross-compiles natively on the
# host arch (amd64) and emits ARM binaries. `xx-go --wrap` aliases `go` to
# `xx-go`, so existing Makefiles work unchanged.
#
# The patch:
#   1. Pins the (first) builder FROM line to $BUILDPLATFORM so it runs
#      natively on the host.
#   2. Adds a dedicated `xx` build stage pinned to $BUILDPLATFORM, then COPYs
#      its contents into the builder stage. Using a named stage avoids the
#      "InvalidBaseImagePlatform" warning and guarantees xx-go is on PATH.
#   3. Wraps `go` so `RUN make` becomes a native cross-compile.
#
# A marker comment makes this idempotent.
# ---------------------------------------------------------------------------
PATCH_MARKER="# >>> chirpstack-arm-patch <<<"

patch_dockerfile() {
    local dockerfile="$1"

    if grep -qF "$PATCH_MARKER" "$dockerfile"; then
        echo "Skipping already-patched: $dockerfile"
        return 0
    fi

    # 1. Pin the first FROM to $BUILDPLATFORM if not already.
    if ! grep -qE '^FROM\s+--platform=' "$dockerfile"; then
        sed -i '0,/^FROM /{s|^FROM |FROM --platform=$BUILDPLATFORM |}' "$dockerfile"
    fi

    # 2. Prepend a dedicated xx stage at the top of the Dockerfile.
    #    (sed `1i` inserts BEFORE line 1.)
    sed -i "1i ${PATCH_MARKER}\nFROM --platform=\$BUILDPLATFORM tonistiigi/xx AS xx\n" "$dockerfile"

    # 3. Inject `COPY --from=xx`, TARGETPLATFORM, and `xx-go --wrap` right
    #    before `RUN make`.
    sed -i '/^RUN make$/i COPY --from=xx \/ \/\nARG TARGETPLATFORM\nRUN xx-go --wrap\n' "$dockerfile"
}

for r in "${REPOS[@]}"; do
    patch_dockerfile "$r/Dockerfile"
done

echo
echo "Multi arch setup complete"
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
