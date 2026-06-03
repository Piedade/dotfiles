#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing gimp..."

if command_exists gimp; then
    echo_success "GIMP already installed!"
    return
fi

# Install
sudo apt-get install -y gimp
