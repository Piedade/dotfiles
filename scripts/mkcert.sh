#!/bin/bash

echo_info "Installing mkcert..."
"${SUDO_CMD}" apt-get install libnss3-tools mkcert -y
ensure_dir "/var/www/ssl"
mkcert -install
