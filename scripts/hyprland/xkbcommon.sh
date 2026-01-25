#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/../utils.sh

echo_info "Installing Hyprland additional dependencies (glaze)..."
if [ ! -d /usr/include/glaze ]; then
    echo_info "Glaze is not installed. Installing glaze from assets..."
    sudo dpkg -i $SCRIPT_DIR/assets/libglaze-dev_4.4.3-1_all.deb
    sudo apt-get install -f -y
    echo_success "libglaze-dev from assets installed."
fi

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


