#!/bin/bash

echo_info "Installing Monitor setup..."

if command_exists nwg-displays; then
    echo_success "nwg-displays already installed!"
    return
fi

sudo apt-get install -y nwg-displays
