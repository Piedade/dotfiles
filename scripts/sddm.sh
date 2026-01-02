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

echo_info "Installing sddm..."

# Installation of sddm deps
for dep in "${deps[@]}"; do
    echo_info "Installing dep $dep"
    "${SUDO_CMD}" apt-get install "$dep"
done

echo_info "Installing sddm..."
"${SUDO_CMD}" apt-get --no-install-recommends -y install sddm

# Create sessions folder
# sudo mkdir -p /usr/share/wayland-sessions

sudo systemctl set-default graphical.target
sudo systemctl enable sddm.service