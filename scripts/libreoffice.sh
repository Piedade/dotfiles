#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing libreoffice..."

if command_exists libreoffice; then
    echo_success "LibreOffice already installed!"
    return
fi

# Install
sudo apt-get install -y libreoffice
