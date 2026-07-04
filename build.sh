#!/bin/bash
set -e

IMAGE_VERSION="default"

# Function to display help message
show_help() {
    echo "Usage: $(basename "$0") -d <directory>"
    echo ""
    echo "Options:"
    echo "  -v <version>     minimal | default | xfce"
    echo "  -d               Run inside Docker."
    echo "  -h               Show this help message."
}

DOCKER_OPTION=""
DOCKER_IMAGE="perehiniak/linux-build-tools:1.0.0"

# Parse options
while getopts "x:v:dh" opt; do
    case $opt in
        v) IMAGE_VERSION=$OPTARG ;;
        d) DOCKER_OPTION="-d" ;;
        h)
            show_help
            exit 0
            ;;
        \?)
            show_help
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            show_help
            exit 1
            ;;
    esac
done


rm -rf ./dist
rm -rf ./build
mkdir -p ./build/rootfs
cp -r -a ./aarch64-${IMAGE_VERSION}/* ./build

# Copy the first available SSH public key into the image.
for key in \
    "$HOME/.ssh/id_ed25519.pub" \
    "$HOME/.ssh/id_ecdsa.pub" \
    "$HOME/.ssh/id_rsa.pub"; do
    if [ -f "$key" ]; then
        cp "$key" ./build/key.pub
        echo "Using SSH key: $key"
        break
    fi
done

if [ ! -f ./build/key.pub ]; then
    echo "ERROR: No SSH public key found in ~/.ssh/"
    echo "Generate one with:"
    echo "    ssh-keygen -t ed25519"
    exit 1
fi

# Build rootfs
cd ./build
    ./first-stage.sh "${DOCKER_OPTION}"
cd ..

./run-in-image-init.sh "${DOCKER_OPTION}" \
                    -i ./build/rootfs-bookworm-${IMAGE_VERSION}.img \
                    -s ./aarch64-${IMAGE_VERSION}/second-stage.sh \
                    -c ./aarch64-${IMAGE_VERSION}

mkdir ./dist
mv -f ./build/rootfs-bookworm-minimal.img ./dist
