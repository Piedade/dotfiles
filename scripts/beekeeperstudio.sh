#!/bin/bash

echo_info "Installing Beekeeper Studio..."

if command_exists beekeeper-studio; then
    echo_success "Beekeeper Studio already installed!"
    return
fi

# Install our GPG key
curl -fsSL https://deb.beekeeperstudio.io/beekeeper.key | sudo gpg --dearmor --output /usr/share/keyrings/beekeeper.gpg \
  && sudo chmod go+r /usr/share/keyrings/beekeeper.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/beekeeper.gpg] https://deb.beekeeperstudio.io stable main" \
  | sudo tee /etc/apt/sources.list.d/beekeeper-studio-app.list > /dev/null

# Update apt and install
sudo apt-get update && sudo apt-get install beekeeper-studio -y

echo_success "Beekeeper Studio installed!"
