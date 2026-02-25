#!/bin/bash

echo_info "Installing mouse..."

"${SUDO_CMD}" apt-get install -y solaar

"${SUDO_CMD}" usermod -aG plugdev $USER

# Cria a regra udev para o Logitech Unifying Receiver
echo 'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c52b", MODE="0666", GROUP="plugdev"' \
  | "${SUDO_CMD}" tee /etc/udev/rules.d/50-logitech-unifying.rules > /dev/null

"${SUDO_CMD}" udevadm control --reload-rules
"${SUDO_CMD}" udevadm trigger
