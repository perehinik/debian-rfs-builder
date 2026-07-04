#!/bin/sh
set -e

print_step() {
    echo
    echo
    echo "=== $1 ==="
    echo
}

print_step "INSTALL XFCE"
date
whoami
id

sudo apt-get update
export DEBIAN_FRONTEND=noninteractive
sudo apt-get install -y xfce4 xfce4-goodies
sudo apt-get install -y lightdm
sudo systemctl enable lightdm
export DEBIAN_FRONTEND=interactive
