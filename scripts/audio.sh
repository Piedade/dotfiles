#!/bin/bash

echo_info "Installing audio..."

# Install
"${SUDO_CMD}" apt-get install -y pipewire pipewire-pulse wireplumber pipewire-audio-client-libraries pavucontrol libspa-0.2-bluetooth
