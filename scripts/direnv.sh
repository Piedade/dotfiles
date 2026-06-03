#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing direnv..."

if command_exists direnv; then
    echo_success "Direnv already installed!"
    return
fi

sudo apt-get install direnv -y
