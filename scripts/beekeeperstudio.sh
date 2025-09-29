#!/bin/bash

echo_info "Installing Beekeeper Studio..."

# Install our GPG key
curl -fsSL https://deb.beekeeperstudio.io/beekeeper.key | "${SUDO_CMD}" gpg --dearmor --output /usr/share/keyrings/beekeeper.gpg \
  && "${SUDO_CMD}" chmod go+r /usr/share/keyrings/beekeeper.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/beekeeper.gpg] https://deb.beekeeperstudio.io stable main" \
  | "${SUDO_CMD}" tee /etc/apt/sources.list.d/beekeeper-studio-app.list > /dev/null

# Update apt and install
"${SUDO_CMD}" apt update && "${SUDO_CMD}" apt install beekeeper-studio -y

echo_success "Beekeeper Studio installed!"
