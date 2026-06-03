#!/bin/bash

echo_info "Installing libreoffice..."

if command_exists libreoffice; then
    echo_success "LibreOffice already installed!"
    return
fi

# Install
"${SUDO_CMD}" apt-get install -y libreoffice
