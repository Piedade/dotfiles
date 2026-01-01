#!/bin/bash

echo_info "Installing thunar..."

# Install
"${SUDO_CMD}" apt-get install -y thunar gvfs gvfs-backends gvfs-fuse
