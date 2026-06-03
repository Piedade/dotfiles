#!/bin/bash

echo_info "Installing wl-copy..."

if command_exists wl-copy; then
    echo_success "wl-clipboard already installed!"
    return
fi

# Install
"${SUDO_CMD}" apt-get install -y wl-clipboard cliphist
