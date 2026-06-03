#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing thunar..."

if command_exists thunar; then
    echo_success "Thunar already installed!"
    return
fi

# Install
sudo apt-get install -y thunar gvfs gvfs-backends gvfs-fuse tumbler-plugins-extra thunar-archive-plugin

# Network discovery
sudo apt-get install -y avahi-daemon samba

# default
echo_info "Setting Thunar as default file manager."
xdg-mime default thunar.desktop inode/directory
xdg-mime default thunar.desktop application/x-wayland-gnome-saved-search
