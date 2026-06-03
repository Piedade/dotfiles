#!/bin/bash

echo_info "Installing mkcert..."

if command_exists mkcert; then
    echo_success "Mkcert already installed!"
    return
fi
sudo apt-get install libnss3-tools mkcert -y
ensure_dir "/var/www/ssl"
mkcert -install
