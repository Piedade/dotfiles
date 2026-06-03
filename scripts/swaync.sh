#!/bin/bash

echo_info "Installing Notifications..."

if command_exists swaync; then
    echo_success "Swaync already installed!"
    return
fi

sudo apt-get install -y sway-notification-center libnotify-bin
