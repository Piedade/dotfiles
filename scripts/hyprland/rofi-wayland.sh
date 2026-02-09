#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/../utils.sh

name="rofi-wayland"

echo_info "Installing $name..."
repo_url="https://github.com/in0ni/rofi-wayland"
if git clone --depth=1 --filter=blob:none "$repo_url"; then
    cd $name || exit 1
    
    # Install to /usr/local so pkg-config can prefer it over distro /usr
    meson setup build --prefix=/usr/local
    meson compile -C build -j"$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)"

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
