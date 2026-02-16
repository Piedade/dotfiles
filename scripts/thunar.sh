#!/bin/bash

echo_info "Installing thunar..."

# Install
"${SUDO_CMD}" apt-get install -y thunar gvfs gvfs-backends gvfs-fuse thunar tumbler-plugins-extra thunar-archive-plugin

# default
echo_info "Setting Thunar as default file manager."
xdg-mime default thunar.desktop inode/directory
xdg-mime default thunar.desktop application/x-wayland-gnome-saved-search
