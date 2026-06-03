#!/bin/bash

echo_info "Installing printer drivers..."

if command_exists lpstat; then
    echo_success "Printer drivers already installed!"
    return
fi

"${SUDO_CMD}" apt-get install -y cups printer-driver-all system-config-printer
"${SUDO_CMD}" systemctl enable --now cups
