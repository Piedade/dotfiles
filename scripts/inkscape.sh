#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing inkscape..."

if command_exists inkscape; then
    echo_success "Inkscape already installed!"
    return
fi

# Install
sudo apt-get install -y inkscape
