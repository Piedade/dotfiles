#!/bin/bash

echo_info "Installing OpenVPN..."

# Install our GPG key
"${SUDO_CMD}" mkdir -p /etc/apt/keyrings && curl -fsSL https://packages.openvpn.net/packages-repo.gpg | sudo tee /etc/apt/keyrings/openvpn.asc
DISTRO=$(lsb_release -c -s)
echo "deb [signed-by=/etc/apt/keyrings/openvpn.asc] https://packages.openvpn.net/openvpn3/debian $DISTRO main" | sudo tee /etc/apt/sources.list.d/openvpn-packages.list

"${SUDO_CMD}" apt-get update
"${SUDO_CMD}" apt-get install openvpn3 -y

echo_success "OpenVPN installed!"
