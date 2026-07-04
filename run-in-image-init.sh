#!/usr/bin/env bash
set -e

show_help() {
    echo "Usage: $(basename "$0") -i <image> -s <script> [-c <directory>] [-k <kernel>]"
    echo
    echo "Options:"
    echo "  -i <image>       Root filesystem image."
    echo "  -s <script>      Script to execute inside the target image."
    echo "  -c <directory>   Directory to copy into the target image (optional)."
    echo "  -k <kernel>      Kernel image (default: Image.gz)."
    echo "  -d               Run inside Docker."
    echo "  -h               Show this help message."
}

THIS_SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
THIS_SCRIPT_DIR="$(dirname "$THIS_SCRIPT_PATH")"

IMAGE_NAME=""
SCRIPT_PATH=""
COPY_DIR=""
ROOTFS_DIR="./build/rootfs"
KERNEL_IMAGE="${THIS_SCRIPT_DIR}/kernel/Image.gz"
QEMU_LOG="./build/qemu.log"
USE_DOCKER=0
DOCKER_IMAGE="perehiniak/linux-build-tools:1.0.0"

while getopts "i:s:c:k:dh" opt; do
    case "$opt" in
        i) IMAGE_NAME="$OPTARG" ;;
        s) SCRIPT_PATH="$OPTARG" ;;
        c) COPY_DIR="$OPTARG" ;;
        k) KERNEL_IMAGE="$OPTARG" ;;
        d) USE_DOCKER=1 ;;
        h)
            show_help
            exit 0
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            show_help
            exit 1
            ;;
        \?)
            show_help
            exit 1
            ;;
    esac
done

if [ "$USE_DOCKER" = "1" ] && [ -z "${INSIDE_DOCKER:-}" ]; then
    exec docker run -it \
        --rm \
        --privileged \
        -e INSIDE_DOCKER=1 \
        -v ./:/root \
        -w /root \
        -u root \
        --entrypoint "$0" \
        ${DOCKER_IMAGE} \
        "$@"
fi

[ -n "$IMAGE_NAME" ] || { echo "ERROR: -i is required."; exit 1; }
[ -n "$SCRIPT_PATH" ] || { echo "ERROR: -s is required."; exit 1; }

[ -f "$IMAGE_NAME" ] || { echo "ERROR: Image not found: $IMAGE_NAME"; exit 1; }
[ -f "$SCRIPT_PATH" ] || { echo "ERROR: Script not found: $SCRIPT_PATH"; exit 1; }

if [ -n "$COPY_DIR" ] && [ ! -d "$COPY_DIR" ]; then
    echo "ERROR: Directory not found: $COPY_DIR"
    exit 1
fi

REMOTE_DIR=/qemu_env
REMOTE_SCRIPT="$(basename "$SCRIPT_PATH")"


echo "run-in-image copy files"
mkdir -p "${ROOTFS_DIR}"
losetup -D
LOOP_DEVICE="$(losetup -f ./${IMAGE_NAME} --show)"
mount -o loop "${LOOP_DEVICE}" "${ROOTFS_DIR}"

mkdir -p "${ROOTFS_DIR}/${REMOTE_DIR}"
cp -a "${SCRIPT_PATH}" "${ROOTFS_DIR}/${REMOTE_DIR}"
if [ ${COPY_DIR} != "" ]; then
    cp -ra "${COPY_DIR}/." "${ROOTFS_DIR}/${REMOTE_DIR}"
fi
sync
ls -l "${ROOTFS_DIR}"
umount "${LOOP_DEVICE}" || true
umount "${ROOTFS_DIR}" || true
losetup -d "${LOOP_DEVICE}" || true



echo "run-in-image start qemu"
qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a57 \
    -m 4G \
    -smp 4 \
    -nographic \
    -kernel "${KERNEL_IMAGE}" \
    -drive if=none,file=${IMAGE_NAME},format=raw,id=mydisk \
    -device virtio-blk-device,drive=mydisk \
    -append "rootwait root=/dev/vda init=${REMOTE_DIR}/${REMOTE_SCRIPT} rw" \
    -device virtio-net-device,netdev=usernet \
    -netdev user,id=usernet



echo "run-in-image cleanup"
LOOP_DEVICE="$(losetup -f ./${IMAGE_NAME} --show)"
mount -o loop "${LOOP_DEVICE}" "${ROOTFS_DIR}"
rm -rf "${ROOTFS_DIR}/qemu_env"
ls -l "${ROOTFS_DIR}"
sync
umount "${LOOP_DEVICE}" || true
umount "${ROOTFS_DIR}" || true
losetup -d "${LOOP_DEVICE}" || true
