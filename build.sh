#!/bin/bash
set -e

POSTINST_SCRIPT_PATH="./postinst/postinst.sh"
IMAGE_VERSION="default"

# Function to display help message
show_help() {
    echo "Usage: $(basename "$0") -d <directory>"
    echo ""
    echo "Options:"
    echo "  -x <path>        Specify script that should be executed in target rfs after installation."
    echo "  -v <version>     minimal | default | xfce"
    echo "  -d               Run inside Docker."
    echo "  -h               Show this help message."
}

USE_DOCKER=0
DOCKER_IMAGE="perehiniak/linux-build-tools:1.0.0"

# Parse options
while getopts "x:v:dh" opt; do
    case $opt in
        x) POSTINST_SCRIPT_PATH=$OPTARG ;;
        v) IMAGE_VERSION=$OPTARG ;;
        d) USE_DOCKER=1 ;;
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

POSTINST_SCRIPT_NAME=$(basename ${POSTINST_SCRIPT_PATH})
POSTINST_SCRIPT_DIR=$(dirname ${POSTINST_SCRIPT_PATH})


if [ "$USE_DOCKER" = "1" ] && [ -z "${INSIDE_DOCKER:-}" ]; then
    if [ -f "${POSTINST_SCRIPT_PATH}" ]; then
        # Just mount postinst over default postinst
        POSTINST_SCRIPT_OPTION="-v ${POSTINST_SCRIPT_DIR}/:/root/postinst"
    fi

    echo "'${POSTINST_SCRIPT_OPTION}'"

    exec docker run -it \
        --rm \
        --privileged \
        -e INSIDE_DOCKER=1 \
        -v ./:/root \
        -v "$HOME/.ssh:/root/.ssh:ro" \
        ${POSTINST_SCRIPT_OPTION} \
        -w /root \
        -u root \
        --entrypoint "$0" \
        ${DOCKER_IMAGE} \
        "$@" \
        -x "./postinst/${POSTINST_SCRIPT_NAME}"
fi

# Check if the specified directory exists
if [ -n "${POSTINST_SCRIPT_PATH}" ] && [ ! -f "${POSTINST_SCRIPT_PATH}" ]; then
    echo "Error: File ${POSTINST_SCRIPT_PATH} does not exist"
    exit 1
fi

# Check if POSTINST_SCRIPT_PATH is executable
if [ ! -x "${POSTINST_SCRIPT_PATH}" ]; then
    echo "Error: '${POSTINST_SCRIPT_PATH}' is not executable."
    exit 1
fi

rm -rf ./dist
rm -rf ./build
mkdir -p ./build/postinst
cp -r -a ./aarch64-${IMAGE_VERSION}/* ./build
cp ./kernel/Image.gz ./build

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

if [ ${POSTINST_SCRIPT_DIR} != "./build/postinst" ]; then
    cp -r -a ${POSTINST_SCRIPT_DIR}/* ./build/postinst
    if [ "${POSTINST_SCRIPT_NAME}" != "postinst.sh" ]; then
        mv "./build/postinst/${POSTINST_SCRIPT_NAME}" \
           "./build/postinst/postinst.sh"
    fi
fi

# Build rootfs
cd ./build
./steps.sh || true
cd ..

mkdir ./dist
mv -f ./build/rootfs-*.img ./dist

