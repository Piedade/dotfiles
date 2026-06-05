#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing NetworkManager..."

if command_exists nmcli; then
    echo_success "NetworkManager already installed!"
    return
fi

sudo apt-get install -y network-manager

sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

# Disable WWAN radio
nmcli radio wwan off

echo_success "NetworkManager installed!"
