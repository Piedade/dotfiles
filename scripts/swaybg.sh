#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing swaybg..."

if command_exists swaybg; then
    echo_success "Swaybg already installed!"
    return
fi

# Install
sudo apt-get install -y swaybg
