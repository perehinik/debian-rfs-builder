#!/bin/bash

echo; echo "--- Using default steps-user.sh ---"; echo;

echo "Set password root for user root"
echo "root:root" | /sbin/chpasswd

# Install additional packages
apt-get update
apt-get install -y vim

