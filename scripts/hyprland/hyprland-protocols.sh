#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/../utils.sh

tag="v0.7.0"
name="hyprland-protocols"

echo_info "Installing $name $tag..."
if git clone --recursive -b $tag https://github.com/hyprwm/hyprland-protocols.git; then
    cd $name || exit 1
    
	meson setup build
    if sudo meson install -C build; then
        echo_success "$name installed successfully."
    else
        echo_error "Installation failed for $name"
    fi

    cd ..
else
    echo_error "Download failed for $name!"
fi

rm -rf ./$name
