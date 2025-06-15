#!/bin/bash

echo_info "Installing Tableplus..."

wget -qO - https://deb.tableplus.com/apt.tableplus.com.gpg.key | gpg --dearmor | "${SUDO_CMD}" tee /etc/apt/trusted.gpg.d/tableplus-archive.gpg > /dev/null
echo "deb [arch=amd64] https://deb.tableplus.com/debian/24 tableplus main" | "${SUDO_CMD}" tee /etc/apt/sources.list.d/tableplus.list
"${SUDO_CMD}" apt-get update
"${SUDO_CMD}" apt-get install -y tableplus

echo_success "Tableplus installed!"
