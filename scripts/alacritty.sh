#!/bin/bash

echo_info "Installing alacritty..."

if command_exists alacritty; then
    echo_success "Alacritty already installed!"
    return
fi

# Install
sudo apt-get install -y alacritty

# Set as default terminal
sudo update-alternatives --set x-terminal-emulator $(which alacritty)
