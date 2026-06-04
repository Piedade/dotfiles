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

echo_success "Chrome installed!"
