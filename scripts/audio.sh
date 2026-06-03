#!/bin/bash

echo_info "Installing audio..."

if command_exists pipewire; then
    echo_success "Audio (pipewire) already installed!"
    return
fi

# Install
sudo apt-get install -y pipewire pipewire-pulse wireplumber pipewire-audio-client-libraries pavucontrol libspa-0.2-bluetooth
