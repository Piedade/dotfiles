#!/bin/bash

echo_info "Installing swaybg..."

if command_exists swaybg; then
    echo_success "Swaybg already installed!"
    return
fi

# Install
sudo apt-get install -y swaybg
