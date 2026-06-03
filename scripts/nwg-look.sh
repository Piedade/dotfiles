#!/bin/bash

echo_info "Installing appearance..."

if command_exists nwg-look; then
    echo_success "nwg-look already installed!"
    return
fi

"${SUDO_CMD}" apt-get install -y nwg-look papirus-icon-theme
