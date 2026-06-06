#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing Polkit Agent..."

if command_exists lxpolkit; then
    echo_success "Polkit Agent already installed!"
    return 2>/dev/null || exit 0
fi

sudo apt-get install -y polkitd lxpolkit gnome-keyring pkexec # libsecret-1-0

echo_success "Polkit installed!"
