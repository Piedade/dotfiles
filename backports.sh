#!/bin/bash

set -e

echo "Adding Debian 13 (Trixie) backports repo..."

sudo tee /etc/apt/sources.list.d/trixie-backports.sources >/dev/null <<'EOF'
Types: deb
URIs: https://deb.debian.org/debian
Suites: trixie-backports
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

sudo apt-get update

sudo apt-get install -y -t trixie-backports linux-image-amd64 linux-headers-amd64

echo
echo "Current running kernel:"
uname -r

echo
echo "Installed kernel packages:"
dpkg -l | grep '^ii' | grep linux-image

echo
read -rp "Reboot now? [Y/n]" answer
answer=${answer:-y}

case "$answer" in
	[Yy]*)
		echo "Rebooting..."
		sudo reboot
		;;
	*)
		echo "Reboot skipped. Please reboot later to use the new kernel."
		;;
esac

