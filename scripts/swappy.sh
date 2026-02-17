#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/utils.sh

deps=(
  grim
  slurp
  wl-clipboard
  fonts-font-awesome
)

echo_info "Installing dependencies..."
for dep in "${deps[@]}"; do
    install_package "$dep"
    if [ $? -ne 0 ]; then
        echo_error "$dep installation failed!"
        exit 1
    fi
done

name="swappy"
tag="v1.8.0"

echo_info "Installing $name..."
if git clone --recursive -b $tag https://github.com/jtheoof/swappy; then
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
