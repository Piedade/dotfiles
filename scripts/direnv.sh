#!/bin/bash

echo_info "Installing direnv..."

if command_exists direnv; then
    echo_success "Direnv already installed!"
    return
fi

"${SUDO_CMD}" apt-get install direnv -y
