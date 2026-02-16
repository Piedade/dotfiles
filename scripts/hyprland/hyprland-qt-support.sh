#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/../utils.sh

deps=(
    qt6-base-dev
    qt6-wayland
    qt6-declarative-dev
    qml6-module-qtcore
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

tag="v0.1.0"
name="hyprland-qt-support"

echo_info "Installing $name $tag..."
if git clone --recursive -b $tag https://github.com/hyprwm/hyprland-qt-support.git; then
    cd $name || exit 1

    mkdir -p build
    cd build || exit 1

    # Configure CMake and explicitly tell it where to install QML
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DINSTALL_QMLDIR=/usr/lib/qt6/qml

    # Build
    cmake --build . --config Release --target all -j$(nproc 2>/dev/null || getconf NPROCESSORS_CONF)

    # Install
    sudo cmake --install .

    if [ $? -eq 0 ]; then
        echo_success "$name installed successfully."
    else
        echo_error "Installation failed for $name"
    fi

    export QML2_IMPORT_PATH=/usr/lib/qt6/qml

    cd ../.. || exit 1
else
    echo_error "Download failed for $name!"
fi

rm -rf ./$name
