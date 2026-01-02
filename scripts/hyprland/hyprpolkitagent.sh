#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/../utils.sh

deps=(
	libpolkit-agent-1-dev
	libpolkit-qt6-1-dev
  qml6-module-qtquick-layouts
  qt6-tools-dev
  qt6-tools-dev-tools
  qt6-charts-dev
)

echo_info "Installing dependencies..."
for dep in "${deps[@]}"; do
    install_package "$dep"
    if [ $? -ne 0 ]; then
        echo_error "$dep installation failed!"
        exit 1
    fi
done

tag="v0.1.3"
name="hyprpolkitagent"

echo_info "Installing $name $tag..."
if git clone --recursive -b $tag https://github.com/hyprwm/hyprpolkitagent.git; then
    cd $name || exit 1

	  cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
	  cmake --build ./build --config Release --target all -j`nproc 2>/dev/null || getconf NPROCESSORS_CONF`

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
