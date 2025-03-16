#!/bin/bash

readonly DEB_VER_NAME=bookworm
readonly BUILD_DIR=/tmp/debian-build

rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}/rootfs
cp -r -a ./* ${BUILD_DIR}
losetup -D

pushd ${BUILD_DIR}

echo;echo;echo "BUILD TOOLS"; echo
echo "Building poweroff command"
aarch64-linux-gnu-gcc -o ${BUILD_DIR}/src/poweroff ./tools/poweroff.c

echo;echo;echo "CREATE IMAGE"; echo
dd if=/dev/zero of=${BUILD_DIR}/rootfs.img bs=1 count=0 seek=4G
LOOP_DEVICE=$(losetup -f ${BUILD_DIR}/rootfs.img --show)
mkfs.ext4 "${LOOP_DEVICE}"
mount -o loop "${LOOP_DEVICE}" ${BUILD_DIR}/rootfs
echo $(losetup -l --raw)

echo;echo;echo "DEBOOTSTRAP FIRST STAGE"; echo
debootstrap --arch=arm64 \
	--variant=minbase \
	--include=isc-dhcp-client \
	--foreign $DEB_VER_NAME \
	${BUILD_DIR}/rootfs http://ftp.debian.org/debian/
cp -r -a ${BUILD_DIR}/src/* ${BUILD_DIR}/rootfs
cp ${BUILD_DIR}/second-stage.sh ${BUILD_DIR}/rootfs
cp -r ${BUILD_DIR}/user_steps ${BUILD_DIR}/rootfs
sync
umount "${LOOP_DEVICE}"
umount "${BUILD_DIR}/rootfs"
losetup -d "${LOOP_DEVICE}"

echo;echo;echo "DEBOOTSTRAP SECOND STAGE"; echo;

qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a57 \
    -m 4G \
    -smp 4 \
    -nographic \
    -kernel Image.gz \
    -drive if=none,file=rootfs.img,format=raw,id=mydisk \
    -device virtio-blk-device,drive=mydisk \
    -append "rootwait root=/dev/vda init=/second-stage.sh rw" \
    -device virtio-net-device,netdev=usernet \
    -netdev user,id=usernet

popd


echo;echo;echo "CLEANUP"; echo;
LOOP_DEVICE="$(losetup -f ${BUILD_DIR}/rootfs.img --show)"
mount -o loop "${LOOP_DEVICE}" ${BUILD_DIR}/rootfs
rm -f ${BUILD_DIR}/rootfs/second-stage.sh
rm -rf ${BUILD_DIR}/rootfs/user_steps
ls -l ${BUILD_DIR}/rootfs
sync
umount "${LOOP_DEVICE}"
umount "${BUILD_DIR}/rootfs"
losetup -d "${LOOP_DEVICE}"

cp ${BUILD_DIR}/rootfs.img ./
rm -r ${BUILD_DIR}
