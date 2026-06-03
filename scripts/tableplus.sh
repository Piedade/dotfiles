#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing Tableplus..."

if command_exists tableplus; then
    echo_success "Tableplus already installed!"
    return
fi

wget -qO - https://deb.tableplus.com/apt.tableplus.com.gpg.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/tableplus-archive.gpg > /dev/null
echo "deb [arch=amd64] https://deb.tableplus.com/debian/24 tableplus main" | sudo tee /etc/apt/sources.list.d/tableplus.list
sudo apt-get update
sudo apt-get install -y tableplus

echo_success "Tableplus installed!"
