#!/bin/bash

echo_info "Installing Chrome..."

"${SUDO_CMD}" apt-get install -y fonts-liberation

TMPDIR=$(mktemp -d)
wget -O "$TMPDIR/google-chrome.deb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
"${SUDO_CMD}" apt-get install -y "$TMPDIR/google-chrome.deb"
rm -rf "$TMPDIR"

echo_success "Chrome installed!"
