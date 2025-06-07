#!/bin/bash

echo_info "Installing AnyDesk..."

# Add the AnyDesk GPG key
"${SUDO_CMD}" curl -fsSL https://keys.anydesk.com/repos/DEB-GPG-KEY -o /etc/apt/keyrings/keys.anydesk.com.asc
"${SUDO_CMD}" chmod a+r /etc/apt/keyrings/keys.anydesk.com.asc

# Add the AnyDesk apt repository
echo "deb [signed-by=/etc/apt/keyrings/keys.anydesk.com.asc] https://deb.anydesk.com all main" | "${SUDO_CMD}" tee /etc/apt/sources.list.d/anydesk-stable.list > /dev/null

# Update apt caches and install the AnyDesk client
"${SUDO_CMD}" apt-get update
"${SUDO_CMD}" apt-get install anydesk -y

echo_success "AnyDesk installed!"
