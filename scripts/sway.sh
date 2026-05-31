#!/bin/bash

set -e

echo_info "Installing sway, greetd and tuigreet..."
"${SUDO_CMD}" apt update
"${SUDO_CMD}" apt install -y sway xwayland build-essential greetd tuigreet swayidle gtklock jq

# Backup config
"${SUDO_CMD}" cp /etc/greetd/config.toml /etc/greetd/config.toml.bak 2>/dev/null || true

"${SUDO_CMD}" tee /etc/greetd/config.toml > /dev/null <<EOF
[terminal]
vt = 7

[default_session]
command = "tuigreet --time --remember --cmd 'sway > $HOME/sway.log 2>&1' --power-reboot '/usr/bin/systemctl reboot' --power-shutdown '/usr/bin/systemctl poweroff'"
user = "_greetd"
EOF

# Enable greetd
echo_info "Enabling greetd..."
"${SUDO_CMD}" systemctl enable greetd

# User groups
"${SUDO_CMD}" usermod -c "$USER" "$USER"
"${SUDO_CMD}" usermod -aG render "$USER"

echo_success "Sway installed!"
