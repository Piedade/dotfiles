#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing mouse..."

if command_exists solaar; then
    echo_success "Solaar already installed!"
    return
fi

sudo apt-get install -y solaar

sudo usermod -aG plugdev "$USER"

# Cria a regra udev para o Logitech Unifying Receiver
echo 'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c52b", MODE="0666", GROUP="plugdev"' \
  | sudo tee /etc/udev/rules.d/50-logitech-unifying.rules > /dev/null

sudo udevadm control --reload-rules
sudo udevadm trigger


########## INSTALL BATTERY NOTIFICATION SCRIPT ##########

# # Install battery notification script + systemd user timer
# NOTIFY_SCRIPT="$SCRIPT_DIR/mouse-battery-notify.sh"
# SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
# mkdir -p "$SYSTEMD_USER_DIR"

# # Copy script to ~/.local/bin
# mkdir -p "$HOME/.local/bin"
# cp "$NOTIFY_SCRIPT" "$HOME/.local/bin/mouse-battery-notify.sh"
# chmod +x "$HOME/.local/bin/mouse-battery-notify.sh"

# # Create systemd service
# cat > "$SYSTEMD_USER_DIR/mouse-battery-notify.service" << 'EOF'
# [Unit]
# Description=Mouse Battery Low Notification

# [Service]
# Type=oneshot
# ExecStart=%h/.local/bin/mouse-battery-notify.sh
# EOF

# # Create systemd timer (runs every 15 minutes)
# cat > "$SYSTEMD_USER_DIR/mouse-battery-notify.timer" << 'EOF'
# [Unit]
# Description=Check mouse battery every 15 minutes

# [Timer]
# OnBootSec=2min
# OnUnitActiveSec=15min

# [Install]
# WantedBy=timers.target
# EOF

# systemctl --user daemon-reload
# systemctl --user enable --now mouse-battery-notify.timer

# echo_success "Mouse battery notification timer installed!"
