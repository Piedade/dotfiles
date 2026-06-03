#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing appearance..."

if command_exists nwg-look; then
    echo_success "nwg-look already installed!"
    return
fi

sudo apt-get install -y nwg-look papirus-icon-theme
