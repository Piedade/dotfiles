#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing wl-copy..."

if command_exists wl-copy; then
    echo_success "wl-clipboard already installed!"
    return
fi

# Install
sudo apt-get install -y wl-clipboard cliphist
