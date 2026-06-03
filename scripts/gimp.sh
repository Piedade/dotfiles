#!/bin/bash

echo_info "Installing gimp..."

if command_exists gimp; then
    echo_success "GIMP already installed!"
    return
fi

# Install
sudo apt-get install -y gimp
