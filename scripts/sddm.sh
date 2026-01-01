#!/bin/bash

echo_info "Installing sddm..."

"${SUDO_CMD}" apt-get install --no-install-recommends install sddm

"${SUDO_CMD}" systemctl enable sddm
