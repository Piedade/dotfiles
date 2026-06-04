#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing sway, greetd and tuigreet..."

if command_exists sway; then
    echo_success "Sway already installed!"
    return
fi
sudo apt-get update
sudo apt-get install -y sway xwayland waybar build-essential greetd tuigreet swayidle gtklock jq xdg-desktop-portal-wlr playerctl gnome-themes-extra

# Remove foot for alacritty
sudo apt-get remove -y foot

# Portatil
# brightnessctl

# Backup config
sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.bak 2>/dev/null || true

sudo tee /etc/greetd/config.toml > /dev/null <<EOF
[terminal]
vt = 7

[default_session]
command = "tuigreet --time --remember --cmd 'sway > $HOME/sway.log 2>&1' --power-reboot '/usr/bin/systemctl reboot' --power-shutdown '/usr/bin/systemctl poweroff'"
user = "_greetd"
EOF

# Enable greetd
echo_info "Enabling greetd..."
sudo systemctl enable greetd

# User groups
sudo usermod -c "$USER" "$USER"
sudo usermod -aG render "$USER"

echo_success "Sway installed!"
