#!/bin/sh

# let debootstrap install everything
/debootstrap/debootstrap --second-stage

# move poweroff binary from root to /sbin
# It can't be done in steps.s. Looks like debootstrap removes it.
mv /poweroff /sbin

# Enable internet from host
dhclient eth0

echo;echo;echo "EXECUTE USER SCRIPTS"; echo;
cd /postinst
/postinst/postinst.sh || /bin/true
cd /

sync
# # Start shell if needed, for debug
# exec /bin/sh

# # Boot Debian
# echo;echo;echo "BOOT DEBIAN"; echo;
# exec /sbin/init

apt clean

echo;echo;echo "BUILD SUCCESS. SHUTTING DOWN QEMU MACHINE"; echo;

# Shutdown system so Qemu exits
reboot --halt -f || shutdown -h now
