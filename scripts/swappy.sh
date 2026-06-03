#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

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
        return 1
    fi
done

name="swappy"
tag="v1.8.0"

echo_info "Installing $name..."

if command_exists swappy; then
    echo_success "Swappy already installed!"
    return
fi

if git clone --recursive -b "$tag" https://github.com/jtheoof/swappy; then
    pushd "$name" > /dev/null

    # Install to /usr/local so pkg-config can prefer it over distro /usr
    meson setup build --prefix=/usr/local
    meson compile -C build -j"$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)"

    if sudo meson install -C build; then
        echo_success "$name installed successfully."
    else
        echo_error "Installation failed for $name"
    fi

    popd > /dev/null
else
    echo_error "Download failed for $name!"
fi

rm -rf "./$name"
