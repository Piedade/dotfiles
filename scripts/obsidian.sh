#!/bin/bash

echo_info "Installing Obsidian..."

wget https://github.com/obsidianmd/obsidian-releases/releases/download/v1.8.10/obsidian_1.8.10_amd64.deb
"${SUDO_CMD}" apt-get install ./obsidian_1.8.10_amd64.deb

"${SUDO_CMD}" rm -f obsidian_1.8.10_amd64.deb

echo_success "Obsidian installed!"
