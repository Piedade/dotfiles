#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing alacritty..."

if command_exists alacritty; then
    echo_success "Alacritty already installed!"
    return
fi

# Install
sudo apt-get install -y alacritty

# Set as default terminal
sudo update-alternatives --set x-terminal-emulator $(which alacritty)
