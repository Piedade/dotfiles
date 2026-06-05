#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing cliphist..."

if command_exists cliphist; then
    echo_success "cliphist already installed!"
    return
fi

# Install
sudo apt-get install -y wl-clipboard wl-copy cliphist
