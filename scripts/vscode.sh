#!/bin/bash

echo_info "Installing VS Code..."

wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
"${SUDO_CMD}" install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | "${SUDO_CMD}" tee /etc/apt/sources.list.d/vscode.list > /dev/null
rm -f packages.microsoft.gpg
"${SUDO_CMD}" apt-get update
"${SUDO_CMD}" apt-get install -y apt-transport-https code

echo_success "VS Code installed!"
