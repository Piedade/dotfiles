#!/bin/bash

echo_info "Installing inkscape..."

if command_exists inkscape; then
    echo_success "Inkscape already installed!"
    return
fi

# Install
sudo apt-get install -y inkscape
