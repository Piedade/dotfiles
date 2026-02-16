#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/utils.sh

name="rofi"
tag="2.0.0"

echo_info "Installing $name..."
if git clone --recursive -b $tag https://github.com/davatorium/rofi; then
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
