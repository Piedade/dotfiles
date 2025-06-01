#!/bin/bash

echo_info "Installing Chrome..."

wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
"${SUDO_CMD}" dpkg -i ./google-chrome-stable_current_amd64.deb
"${SUDO_CMD}" apt-get -f install
rm ./google-chrome-stable_current_amd64.deb

echo_success "Chrome installed!"
