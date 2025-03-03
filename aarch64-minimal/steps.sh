#!/bin/bash

readonly LOOP_DEVICE=/dev/loop8
readonly DEB_VER_NAME=bookworm

echo;echo;echo "INSTALL DEPENDENCIES"; echo
apt-get update
## Debootstrap
apt-get install -y debootstrap

## Dependencies for QEMU
apt install -y qemu-system-arm qemu-system qemu-utils

echo;echo;echo "CREATE QEMU IMAGE"; echo
mkdir -p ./rootfs
umount "${LOOP_DEVICE}" || /bin/true
losetup -D || /bin/true

qemu-img create -f raw rootfs.img 4G
losetup "${LOOP_DEVICE}" ./rootfs.img
mkfs.ext4 "${LOOP_DEVICE}"
mount -o loop "${LOOP_DEVICE}" ./rootfs
echo $(losetup -l)
echo $(losetup -a)

echo;echo;echo "DEBOOTSTRAP FIRST STAGE"; echo
debootstrap --arch=arm64 --foreign $DEB_VER_NAME ./rootfs http://ftp.debian.org/debian/
sync
umount "${LOOP_DEVICE}" 
losetup -D

echo;echo;echo "RUN QEMU" echo;

apt install -y iproute2 vim

qemu-system-aarch64 \
	-machine virt \
	-cpu cortex-a57 \
	-m 4G \
	-smp 4 \
	-nographic \
	-kernel Image.gz \
	-drive if=none,file=rootfs.img,format=raw,id=mydisk \
	-device virtio-blk-device,drive=mydisk \
	-append "rootwait root=/dev/vda init=/bin/sh rw" \
	-device virtio-net-device,netdev=usernet \
    	-netdev user,id=usernet

