#!/bin/bash

echo_info "Installing firewall..."

if command_exists ufw; then
    echo_success "Firewall (ufw) already installed!"
    return
fi
"${SUDO_CMD}" apt-get install ufw -y

echo_info "Allowing incoming HTTP and HTTPS"
"${SUDO_CMD}" ufw allow in "WWW Full"

# enable firewall
"${SUDO_CMD}" ufw enable
