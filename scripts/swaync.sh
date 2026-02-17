#!/bin/bash

echo_info "Installing Notifications..."

"${SUDO_CMD}" apt-get install -y sway-notification-center
