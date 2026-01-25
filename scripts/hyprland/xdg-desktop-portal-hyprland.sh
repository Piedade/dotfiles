#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/../utils.sh

name="xdg-desktop-portal-hyprland"
tag="v1.3.11"

echo_info "Installing $name $tag..."
if git clone --recursive -b $tag https://github.com/hyprwm/xdg-desktop-portal-hyprland; then
    cd $name || exit 1
    
    cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -S . -B ./build
    cmake --build ./build -j$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)

    if sudo cmake --install ./build; then
        echo_success "$name installed successfully."
    else
        echo_error "Installation failed for $name"
    fi

    cd ..
else
    echo_error "Download failed for $name!"
fi

rm -rf ./$name
