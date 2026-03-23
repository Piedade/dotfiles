#!/bin/bash

echo_info "Installing printer drivers..."

"${SUDO_CMD}" apt-get install -y cups printer-driver-all system-config-printer
"${SUDO_CMD}" systemctl enable --now cups
