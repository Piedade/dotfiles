#!/bin/bash

echo_info "Installing mouse..."

if command_exists solaar; then
    echo_success "Solaar already installed!"
    return
fi

sudo apt-get install -y solaar

sudo usermod -aG plugdev $USER

# Cria a regra udev para o Logitech Unifying Receiver
echo 'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c52b", MODE="0666", GROUP="plugdev"' \
  | sudo tee /etc/udev/rules.d/50-logitech-unifying.rules > /dev/null

sudo udevadm control --reload-rules
sudo udevadm trigger
