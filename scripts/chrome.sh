#!/bin/bash

echo_info "Installing Chrome..."

if command_exists google-chrome; then
    echo_success "Chrome already installed!"
    return
fi

sudo apt-get install -y fonts-liberation

TMPDIR=$(mktemp -d)
wget -O "$TMPDIR/google-chrome.deb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt-get install -y "$TMPDIR/google-chrome.deb"
rm -rf "$TMPDIR"

echo_success "Chrome installed!"
