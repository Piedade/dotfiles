#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing Bruno..."

if command_exists bruno; then
    echo_success "Bruno already installed!"
    return
fi

sudo mkdir -p /etc/apt/keyrings
curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x9FA6017ECABE0266" \
    | gpg --dearmor \
    | sudo tee /etc/apt/keyrings/bruno.gpg > /dev/null
sudo chmod 644 /etc/apt/keyrings/bruno.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/bruno.gpg] http://debian.usebruno.com/ bruno stable" \
    | sudo tee /etc/apt/sources.list.d/bruno.list

sudo apt-get update
sudo apt-get install -y bruno

echo_success "Bruno installed!"
