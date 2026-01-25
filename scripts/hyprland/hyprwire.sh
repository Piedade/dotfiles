#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/../utils.sh

name="hyprwire"
tag="v0.2.1"

echo_info "Installing $name $tag..."
if git clone --recursive -b $tag https://github.com/hyprwm/hyprwire.git; then
    cd $name || exit 1
    
	cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr/local -S . -B ./build
	cmake --build ./build --config Release --target hyprwire -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`

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
