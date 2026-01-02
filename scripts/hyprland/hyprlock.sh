#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/../utils.sh

deps=(
	libpam0g-dev
	libgbm-dev
	libdrm-dev
    libmagic-dev
    libaudit-dev
    libsdbus-c++-dev
)

echo_info "Installing dependencies..."
for dep in "${deps[@]}"; do
    install_package "$dep"
    if [ $? -ne 0 ]; then
        echo_error "$dep installation failed!"
        exit 1
    fi
done

build_dep=(
    pam
)

for dep in "${build_dep[@]}"; do
  build_dep "$dep" "$LOG"
done

tag="v0.9.1"
name="hyprlock"

echo_info "Installing $name $tag..."
if git clone --recursive -b $tag https://github.com/hyprwm/hyprlock.git; then
    cd $name || exit 1

	cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build
	cmake --build ./build --config Release --target hyprlock -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`
    
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
