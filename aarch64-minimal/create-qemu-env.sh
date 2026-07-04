#!/bin/sh
set -e

print_step() {
    echo
    echo
    echo "=== $1 ==="
    echo
}

# Move poweroff binary from root to /sbin.
# It can't be done earlier because debootstrap removes it.
mv ./poweroff /sbin
date
date -s "$(cat ./saved-date.txt)"

print_step "ENABLE NETWORK"
# Enable internet from host
dhclient eth0 || true

apt update
apt install -y isc-dhcp-client openssh-server sudo ifupdown

print_step "CREATE QEMU USER"
# Create qemu user if it doesn't already exist
if ! id qemu >/dev/null 2>&1; then
    useradd -m -s /bin/bash qemu
fi

# Allow passwordless sudo
echo "qemu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/qemu
chmod 440 /etc/sudoers.d/qemu

print_step "INSTALL SSH KEY"

mkdir -p /home/qemu/.ssh

if [ -f ./key.pub ]; then
    cp ./key.pub /home/qemu/.ssh/authorized_keys
    chown -R qemu:qemu /home/qemu/.ssh
    chmod 700 /home/qemu/.ssh
    chmod 600 /home/qemu/.ssh/authorized_keys
else
    echo "WARNING: key.pub not found"
fi

cp -r ./src/etc/* /etc

print_step "ENABLE SSH"

systemctl enable ssh || update-rc.d ssh enable || true

print_step "CLEANUP"

apt clean
