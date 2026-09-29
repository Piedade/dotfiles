#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing vlc..."

if command_exists vlc; then
    echo_success "VLC already installed!"
    return
fi

# Install
sudo apt-get install -y vlc
