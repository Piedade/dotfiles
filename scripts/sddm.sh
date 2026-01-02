#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/utils.sh

deps=(
  libqt6svg6
  qt6-declarative-dev
  qt6-svg-dev
  qt6-virtualkeyboard-plugin
  libqt6multimedia6
  qml6-module-qtquick-controls
  qml6-module-qtquick-effects
)

# Installation of sddm deps
echo_info "Installing dependencies..."
for dep in "${deps[@]}"; do
    install_package "$dep"
    if [ $? -ne 0 ]; then
        echo_error "$dep installation failed!"
        exit 1
    fi
done

echo_info "Installing sddm..."
"${SUDO_CMD}" apt-get --no-install-recommends -y install sddm

# Create sessions folder
# sudo mkdir -p /usr/share/wayland-sessions

sudo systemctl set-default graphical.target
sudo systemctl enable sddm.service
