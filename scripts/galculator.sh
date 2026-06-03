#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing galculator..."

if command_exists galculator; then
    echo_success "Galculator already installed!"
    return
fi

sudo apt-get -y install galculator
