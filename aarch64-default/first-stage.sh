#!/bin/bash
set -e

pushd "$(dirname "$0")" > /dev/null

readonly DEB_VER_NAME=bookworm
readonly IMAGE_NAME=rootfs-${DEB_VER_NAME}-default.img

print_step() {
    echo
    echo
    echo "=== $1 ==="
    echo
}

USE_DOCKER=0
DOCKER_IMAGE="perehiniak/linux-build-tools:1.0.0"

while getopts "d" opt; do
    case "$opt" in
        d) USE_DOCKER=1 ;;
    esac
done

if [ "$USE_DOCKER" = "1" ] && [ -z "${INSIDE_DOCKER:-}" ]; then
    popd > /dev/null
    exec docker run -it \
        --rm \
        --privileged \
        -e INSIDE_DOCKER=1 \
        -v ./:/root \
        -w /root \
        -u root \
        --entrypoint "$0" \
        ${DOCKER_IMAGE}
fi

mkdir -p ./rootfs
losetup -D

print_step "CREATE IMAGE"
dd if=/dev/zero of=./${IMAGE_NAME} bs=1 count=0 seek=4G
chown 1000:1000 ./${IMAGE_NAME} || true
LOOP_DEVICE=$(losetup -f ./${IMAGE_NAME} --show)
mkfs.ext4 "${LOOP_DEVICE}"
mount -o loop "${LOOP_DEVICE}" ./rootfs
echo $(losetup -l --raw)

print_step "DEBOOTSTRAP FIRST STAGE"
debootstrap --arch=arm64 \
	--foreign $DEB_VER_NAME \
	./rootfs http://ftp.debian.org/debian/

print_step "COPY FILES"
mkdir -p ./rootfs/qemu_env
date "+%Y-%m-%d %H:%M:%S" > ./rootfs/qemu_env/saved-date.txt
chmod 666 ./rootfs/qemu_env/saved-date.txt
cp ./key.pub ./rootfs/qemu_env

print_step "FIRST STAGE CLEANUP"
sync
umount "${LOOP_DEVICE}" || true
umount ./rootfs || true
losetup -d "${LOOP_DEVICE}" || true

popd > /dev/null
