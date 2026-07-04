#!/bin/sh
set -e

print_step() {
    echo
    echo
    echo "=== $1 ==="
    echo
}

sudo apt-get update

# This step is actually not needed.
# This is just to check if Qemu ssh environment is set up correctly
print_step "DEFAULT DEBIAN IMAGE POSTINST"
