#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing qrencode..."

if command_exists qrencode; then
    echo_success "qrencode already installed!"
    return
fi

sudo apt-get -y install qrencode
