#!/bin/bash

echo_info "Installing ssh-agent..."

if command_exists keychain; then
    echo_success "Keychain already installed!"
    return
fi

# Install
sudo apt-get install -y keychain

systemctl --user enable --now ssh-agent.socket

# # .profile
# if [ -n "$WAYLAND_DISPLAY" ]; then
#   eval $(keychain --eval --quiet ~/.ssh/id_ed25519)
# fi

