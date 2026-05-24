#!/bin/bash

set -e

echo "Adding trixie-backports repository..."

sudo tee /etc/apt/sources.list.d/trixie-backports.list > /dev/null <<EOF
deb http://deb.debian.org/debian trixie-backports main contrib non-free-firmware
EOF

sudo apt-get update

# Install latest kernel from backports
echo "Installing backports kernel..."
sudo apt-get -t trixie-backports install linux-image-amd64 linux-headers-amd64 -y

# Install AMD GPU firmware from backports
echo "Installing AMD firmware..."
sudo apt-get -t trixie-backports install firmware-amd-graphics -y

echo "Current running kernel:"
uname -r

echo "REBOOT now"
