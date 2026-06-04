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

echo_success "NetworkManager installed!"
