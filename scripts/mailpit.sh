#!/bin/bash

echo_info "Installing mailpit..."

# Install
"${SUDO_CMD}" sh < <(curl -sL https://raw.githubusercontent.com/axllent/mailpit/develop/install.sh)

# Database directory
DB_DIR="/var/lib/mailpit"
"${SUDO_CMD}" mkdir -p "$DB_DIR"
"${SUDO_CMD}" chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$DB_DIR"

# Start when your computer starts
cat << 'EOF' | "${SUDO_CMD}" tee /etc/systemd/system/mailpit.service > /dev/null
[Unit]
Description=Mailpit Server

[Service]
ExecStart=/usr/local/bin/mailpit -d /var/lib/mailpit/mailpit.db
Restart=always
# Restart service after 10 seconds service crashes
RestartSec=10
SyslogIdentifier=mailpit
User=piedade
Group=piedade

[Install]
WantedBy=multi-user.target
EOF

"${SUDO_CMD}" systemctl enable mailpit.service
