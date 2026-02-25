#!/bin/bash

echo_info "Installing ssh-agent..."

# Install
"${SUDO_CMD}" apt-get install -y keychain

systemctl --user enable --now ssh-agent.socket

eval $(keychain --eval --quiet ~/.ssh/id_ed25519)

# no .profile será preciso?
# export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/openssh_agent"

