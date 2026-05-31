#!/bin/bash

echo_info "Installing alacritty..."

# Install
"${SUDO_CMD}" apt-get install -y alacritty

# Set as default terminal
"${SUDO_CMD}" update-alternatives --set x-terminal-emulator $(which alacritty)
