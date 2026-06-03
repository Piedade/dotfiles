#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing firewall..."

if command_exists ufw; then
    echo_success "Firewall (ufw) already installed!"
    return
fi
sudo apt-get install ufw -y

echo_info "Allowing incoming HTTP and HTTPS"
sudo ufw allow in "WWW Full"

# enable firewall
sudo ufw enable
