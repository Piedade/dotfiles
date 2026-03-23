#!/bin/bash

echo_info "Installing ssh-agent..."

# Install
"${SUDO_CMD}" apt-get install -y keychain

systemctl --user enable --now ssh-agent.socket

# # .profile
# if [ -n "$WAYLAND_DISPLAY" ]; then
#   eval $(keychain --eval --quiet ~/.ssh/id_ed25519)
# fi

