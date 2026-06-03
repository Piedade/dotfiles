#!/bin/bash

echo_info "Installing AnyDesk..."

if command_exists anydesk; then
    echo_success "AnyDesk already installed!"
    return
fi

# Add the AnyDesk GPG key
sudo curl -fsSL https://keys.anydesk.com/repos/DEB-GPG-KEY -o /etc/apt/keyrings/keys.anydesk.com.asc
sudo chmod a+r /etc/apt/keyrings/keys.anydesk.com.asc

# Add the AnyDesk apt repository
echo "deb [signed-by=/etc/apt/keyrings/keys.anydesk.com.asc] https://deb.anydesk.com all main" | sudo tee /etc/apt/sources.list.d/anydesk-stable.list > /dev/null

# Update apt caches and install the AnyDesk client
sudo apt-get update
sudo apt-get install anydesk -y

echo_success "AnyDesk installed!"
