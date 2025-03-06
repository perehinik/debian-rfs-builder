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

echo;echo;echo "BUILD SUCCESS. SHUTTING DOWN QEMU MACHINE"; echo;

# Shutdown system so Qemu exits
reboot --halt -f || shutdown -h now
