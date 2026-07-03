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
    echo "  -h               Show this help message."
}

# Parse options
while getopts "x:v:h" opt; do
    case $opt in
        x)
            POSTINST_SCRIPT_PATH=$OPTARG
            ;;
        v)
            IMAGE_VERSION=$OPTARG
	    ;;
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
if [ ${POSTINST_SCRIPT_DIR} != "./build/postinst" ]; then
    cp -r -a ${POSTINST_SCRIPT_DIR}/* ./build/postinst
    mv ./build/postinst/${POSTINST_SCRIPT_NAME} ./build/postinst/postinst.sh
fi

# Build rootfs
cd ./build
./steps.sh || true
cd ..

mkdir ./dist
mv -f ./build/rootfs-*.img ./dist

