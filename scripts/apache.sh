#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing apache2..."

if command_exists apache2; then
    echo_success "Apache2 already installed!"
    return
fi

CONFIG_FILE="/etc/apache2/apache2.conf"

sudo apt-get install apache2 -y

# Add ServerName to the last line
echo -e "\n\nServerName localhost" | sudo tee -a "$CONFIG_FILE" > /dev/null

# Enable .htaccess inside /var/www
sudo sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' "$CONFIG_FILE"

# Change apache user and group
sudo sed -i "s/^export APACHE_RUN_USER=.*/export APACHE_RUN_USER="${SUDO_USER:-$USER}"/" "/etc/apache2/envvars"
sudo sed -i "s/^export APACHE_RUN_GROUP=.*/export APACHE_RUN_GROUP="${SUDO_USER:-$USER}"/" "/etc/apache2/envvars"
sudo systemctl restart apache2

# FIX permissions
sudo chown -R "${SUDO_USER:-$USER}":"${SUDO_USER:-$USER}" /var/www
sudo find /var/www -type d -exec chmod 2755 {} \+
sudo find /var/www -type f -exec chmod 644 {} \+
sudo find /var/www -type d -exec chmod g+s {} +
