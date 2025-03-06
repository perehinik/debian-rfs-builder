FROM ubuntu:22.04

RUN apt-get update

# Dependencies for rootfs build
RUN apt-get install -y debootstrap
RUN apt-get install -y qemu-system-arm qemu-system qemu-utils

# Dependencies for kernel build
RUN apt-get install -y gcc-aarch64-linux-gnu \
	bc \
	flex \
	bison \
	make \
	libc6-dev \
	libssl-dev \
	device-tree-compiler

RUN useradd builder
RUN usermod -aG sudo builder
USER builder

WORKDIR /home/builder
