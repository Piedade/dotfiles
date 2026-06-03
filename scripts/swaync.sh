#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing Notifications..."

if command_exists swaync; then
    echo_success "Swaync already installed!"
    return
fi

sudo apt-get install -y sway-notification-center libnotify-bin
