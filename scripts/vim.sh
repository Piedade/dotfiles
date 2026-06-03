#!/bin/bash

echo_info "Installing vim..."

if command_exists vim; then
    echo_success "Vim already installed!"
    return
fi

# Install
"${SUDO_CMD}" apt-get install -y vim
