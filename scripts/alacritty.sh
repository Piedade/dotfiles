#!/bin/bash

echo_info "Installing alacritty..."

if command_exists alacritty; then
    echo_success "Alacritty already installed!"
    return
fi

# Install
"${SUDO_CMD}" apt-get install -y alacritty

# Set as default terminal
"${SUDO_CMD}" update-alternatives --set x-terminal-emulator $(which alacritty)
