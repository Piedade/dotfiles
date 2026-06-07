#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing Chrome..."

if command_exists google-chrome; then
    echo_success "Chrome already installed!"
    return
fi

sudo apt-get install -y fonts-liberation

TMPDIR=$(mktemp -d)
wget -O "$TMPDIR/google-chrome.deb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    || { echo_error "Failed to download Chrome"; rm -rf "$TMPDIR"; return 1; }
sudo apt-get install -y "$TMPDIR/google-chrome.deb"
rm -rf "$TMPDIR"

# Add arch=amd64 to fix N: Skipping acquire of configured file 'main/binary-i386/Packages'
sudo sed -i '/^Signed-By:/i Architectures: amd64' /etc/apt/sources.list.d/google-chrome.sources
sudo apt-get update

# Set Chrome to use system title bars and borders (fix sway flickering)
sudo mkdir -p /etc/opt/chrome
sudo tee /etc/opt/chrome/initial_preferences > /dev/null <<'EOF'
{
  "browser": {
    "custom_chrome_frame": false
  }
}
EOF

# Install systemd user service to close Chrome gracefully before logout
SERVICE_DIR="$HOME/.config/systemd/user"
mkdir -p "$SERVICE_DIR"
cat > "$SERVICE_DIR/chrome-shutdown.service" <<'EOF'
[Unit]
Description=Gracefully close Google Chrome before logout
DefaultDependencies=no
Before=exit.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
ExecStop=/bin/bash -c 'pkill -TERM -x chrome; sleep 3; pkill -KILL -x chrome 2>/dev/null; true'
TimeoutStopSec=6

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now chrome-shutdown.service

echo_success "Chrome installed!"
