#!/bin/sh
set -e

print_step() {
    echo
    echo
    echo "=== $1 ==="
    echo
}

print_step "DEBOOTSTRAP SECOND STAGE"

# Let debootstrap install everything
/debootstrap/debootstrap --second-stage


print_step "CREATE QEMU ENVIRONMENT"
cd /qemu_env
./create-qemu-env.sh

sync

print_step "SECOND STAGE COMPLETE - SHUTTING DOWN"

# Shutdown system so QEMU exits
poweroff || reboot --halt -f || shutdown -h now
