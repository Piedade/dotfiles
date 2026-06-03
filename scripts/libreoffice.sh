#!/bin/bash

echo_info "Installing libreoffice..."

if command_exists libreoffice; then
    echo_success "LibreOffice already installed!"
    return
fi

# Install
sudo apt-get install -y libreoffice
