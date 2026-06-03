#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing Monitor setup..."

if command_exists nwg-displays; then
    echo_success "nwg-displays already installed!"
    return
fi

sudo apt-get install -y nwg-displays
