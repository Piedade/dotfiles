#!/bin/bash

set -e

echo_info "Installing sway, greetd and tuigreet..."
sudo apt update
sudo apt install sway xwayland build-essential greetd tuigreet swayidle gtklock jq -y

# Backup config
sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.bak 2>/dev/null || true

sudo tee /etc/greetd/config.toml > /dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --cmd sway"
EOF

# Enable greetd
echo_info "Enabling greetd..."
sudo systemctl enable greetd
sudo systemctl start greetd

# Mudar o GECOS (nome completo) do utilizador
sudo usermod -c "$USER" "$USER"
