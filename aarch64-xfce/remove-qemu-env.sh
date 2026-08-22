#!/bin/sh
set -e

print_step() {
    echo
    echo
    echo "=== $1 ==="
    echo
}

print_step "REMOVE QEMU SUDO ACCESS"
rm -f /etc/sudoers.d/qemu

print_step "REMOVE QEMU USER"
if id qemu >/dev/null 2>&1; then
    userdel -r qemu 2>/dev/null || {
        echo "WARNING: userdel -r failed, trying manual cleanup"
        userdel qemu || true
        rm -rf /home/qemu
    }
else
    echo "qemu user does not exist"
fi

print_step "PACKAGE CLEANUP"
apt clean

print_step "REMOVE QEMU ETH CONNECTIONS"
rm -f /etc/network/interfaces.d/qemu-*.cfg

print_step "DONE"
sync

poweroff || reboot --halt -f || shutdown -h now
