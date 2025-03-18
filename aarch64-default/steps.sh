#!/bin/bash

readonly DEB_VER_NAME=bookworm
readonly IMAGE_NAME=rootfs-${DEB_VER_NAME}.img

mkdir -p ./rootfs
losetup -D

echo;echo;echo "CREATE IMAGE"; echo
dd if=/dev/zero of=./${IMAGE_NAME} bs=1 count=0 seek=4G
LOOP_DEVICE=$(losetup -f ./${IMAGE_NAME} --show)
mkfs.ext4 "${LOOP_DEVICE}"
mount -o loop "${LOOP_DEVICE}" ./rootfs
echo $(losetup -l --raw)

echo;echo;echo "DEBOOTSTRAP FIRST STAGE"; echo
debootstrap --arch=arm64 \
	--foreign $DEB_VER_NAME \
	./rootfs http://ftp.debian.org/debian/

cp -r -a ./src/* ./rootfs
cp ./second-stage.sh ./rootfs
cp -r -a ./postinst ./rootfs
sync
umount "${LOOP_DEVICE}"
umount ./rootfs
losetup -d "${LOOP_DEVICE}"

echo;echo;echo "DEBOOTSTRAP SECOND STAGE"; echo;

qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a57 \
    -m 4G \
    -smp 4 \
    -nographic \
    -kernel Image.gz \
    -drive if=none,file=${IMAGE_NAME},format=raw,id=mydisk \
    -device virtio-blk-device,drive=mydisk \
    -append "rootwait root=/dev/vda init=/second-stage.sh rw" \
    -device virtio-net-device,netdev=usernet \
    -netdev user,id=usernet

echo;echo;echo "CLEANUP"; echo;
LOOP_DEVICE="$(losetup -f ./${IMAGE_NAME} --show)"
mount -o loop "${LOOP_DEVICE}" ./rootfs
rm -f ./rootfs/second-stage.sh
rm -rf ./rootfs/postinst
ls -l ./rootfs
sync
umount "${LOOP_DEVICE}"
umount ./rootfs
losetup -d "${LOOP_DEVICE}"

