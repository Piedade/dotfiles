#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing Obsidian..."

if command_exists obsidian; then
    echo_success "Obsidian already installed!"
    return
fi

wget https://github.com/obsidianmd/obsidian-releases/releases/download/v1.8.10/obsidian_1.8.10_amd64.deb
sudo apt-get install -y ./obsidian_1.8.10_amd64.deb

sudo rm -f obsidian_1.8.10_amd64.deb

echo_success "Obsidian installed!"
