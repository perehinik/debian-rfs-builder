#!/bin/bash

readonly DEB_VER_NAME=bookworm
readonly IMAGE_NAME=rootfs-${DEB_VER_NAME}-minimal.img
readonly KEYFILE=key.pub

mkdir -p ./rootfs
losetup -D

echo;echo;echo "BUILD TOOLS"; echo
echo "Building poweroff command"
aarch64-linux-gnu-gcc -o ./poweroff ./tools/poweroff.c

echo;echo;echo "CREATE IMAGE"; echo
dd if=/dev/zero of=./${IMAGE_NAME} bs=1 count=0 seek=4G
LOOP_DEVICE=$(losetup -f ./${IMAGE_NAME} --show)
mkfs.ext4 "${LOOP_DEVICE}"
mount -o loop "${LOOP_DEVICE}" ./rootfs
echo $(losetup -l --raw)

echo;echo;echo "DEBOOTSTRAP FIRST STAGE"; echo
debootstrap --arch=arm64 \
	--variant=minbase \
	--include=isc-dhcp-client \
	--foreign $DEB_VER_NAME \
	./rootfs http://ftp.debian.org/debian/

mkdir ./rootfs/qemu_env
cp -r -a ./src ./rootfs/qemu_env
cp ./second-stage.sh ./rootfs/qemu_env
cp ./create-qemu-env.sh ./rootfs/qemu_env
cp -a ./poweroff ./rootfs/qemu_env
cp -r -a ./postinst ./rootfs/qemu_env
if [ -f "$KEYFILE" ]; then
    cp "$KEYFILE" ./rootfs/qemu_env/key.pub
else
    echo "$KEYFILE not found."
fi
date "+%Y-%m-%d %H:%M:%S" > ./rootfs/qemu_env/saved-date.txt
chmod 666 ./rootfs/qemu_env/saved-date.txt

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
    -append "rootwait root=/dev/vda init=/qemu_env/second-stage.sh rw" \
    -device virtio-net-device,netdev=usernet \
    -netdev user,id=usernet

echo;echo;echo "CLEANUP"; echo;
LOOP_DEVICE="$(losetup -f ./${IMAGE_NAME} --show)"
mount -o loop "${LOOP_DEVICE}" ./rootfs
rm -rf ./rootfs/qemu_env
ls -l ./rootfs
sync
umount "${LOOP_DEVICE}"
umount ./rootfs
losetup -d "${LOOP_DEVICE}"
