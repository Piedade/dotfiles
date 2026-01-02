#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/../utils.sh

deps=(
  bison
  libzip-dev
  librsvg2-dev
)

echo_info "Installing dependencies..."
for dep in "${deps[@]}"; do
    install_package "$dep"
    if [ $? -ne 0 ]; then
        echo_error "$dep installation failed!"
        exit 1
    fi
done

name="libxkbcommon"
tag="xkbcommon-1.13.1"

echo_info "Installing $name $tag..."
if git clone --recursive -b $tag https://github.com/xkbcommon/libxkbcommon.git; then
    cd $name || exit 1

    meson setup build --libdir=/usr/local/lib
    meson compile -C build

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


