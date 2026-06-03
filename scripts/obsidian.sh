#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing Obsidian..."

if command_exists obsidian; then
    echo_success "Obsidian already installed!"
    return
fi

OBSIDIAN_VER=$(curl -sf --max-time 10 \
    "https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest" \
    | grep -oP '"tag_name":\s*"\K[^"]*')

if [[ -z "$OBSIDIAN_VER" ]]; then
    echo_error "Could not fetch latest Obsidian version from GitHub API"
    return 1
fi

OBSIDIAN_VER_CLEAN="${OBSIDIAN_VER#v}"
DEB_FILE="obsidian_${OBSIDIAN_VER_CLEAN}_amd64.deb"

echo_info "Installing Obsidian $OBSIDIAN_VER..."
wget "https://github.com/obsidianmd/obsidian-releases/releases/download/${OBSIDIAN_VER}/${DEB_FILE}" \
    || { echo_error "Failed to download Obsidian $OBSIDIAN_VER"; return 1; }

sudo apt-get install -y "./${DEB_FILE}"
sudo rm -f "$DEB_FILE"

echo_success "Obsidian $OBSIDIAN_VER installed!"
