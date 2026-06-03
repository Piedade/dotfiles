#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing printer drivers..."

if command_exists lpstat; then
    echo_success "Printer drivers already installed!"
    return
fi

sudo apt-get install -y cups printer-driver-all system-config-printer
sudo systemctl enable --now cups
