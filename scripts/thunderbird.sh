#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing Thunderbird..."

if command_exists thunderbird; then
    echo_success "Thunderbird already installed!"
    return
fi

sudo apt-get install -y thunderbird

echo_success "Thunderbird installed!"
echo_info "Wayland support is enabled via MOZ_ENABLE_WAYLAND in ~/.config/environment.d/wayland.conf"
