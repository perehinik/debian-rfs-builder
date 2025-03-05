#!/bin/sh

/debootstrap/debootstrap --second-stage

sync

# Enable internet from host
dhclient eth0

# Install additional packages
apt update
apt install -y vim

# Set password for root
echo "root:root" | /sbin/chpasswd

sync
# # Start shell if needed, for debug
# exec /bin/sh

# # Boot Debian
# echo;echo;echo "BOOT DEBIAN"; echo;
# exec /sbin/init

# Shutdown system so Qemu exits
shutdown -h now || /bin/true
reboot --halt -f
