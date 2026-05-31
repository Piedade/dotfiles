#!/bin/bash

echo_info "Installing Bruno..."

"${SUDO_CMD}" mkdir -p /etc/apt/keyrings
curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x9FA6017ECABE0266" \
    | gpg --dearmor \
    | "${SUDO_CMD}" tee /etc/apt/keyrings/bruno.gpg > /dev/null
"${SUDO_CMD}" chmod 644 /etc/apt/keyrings/bruno.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/bruno.gpg] http://debian.usebruno.com/ bruno stable" \
    | "${SUDO_CMD}" tee /etc/apt/sources.list.d/bruno.list

"${SUDO_CMD}" apt-get install -y bruno

echo_success "Bruno installed!"
