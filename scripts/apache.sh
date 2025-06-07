#!/bin/bash

echo_info "Installing apache2..."

CONFIG_FILE="/etc/apache2/apache2.conf"

"${SUDO_CMD}" apt-get install apache2 -y

# Add ServerName to the last line
echo -e "\n\nServerName localhost" | "${SUDO_CMD}" tee -a "$CONFIG_FILE" > /dev/null

# Enable .htaccess inside /var/www
"${SUDO_CMD}" sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' "$CONFIG_FILE"

# Change apache user and group
"${SUDO_CMD}" sed -i "s/^export APACHE_RUN_USER=.*/export APACHE_RUN_USER="${SUDO_USER:-$USER}"/" "/etc/apache2/envvars"
"${SUDO_CMD}" systemctl restart apache2

# FIX permissions
"${SUDO_CMD}" chown -R ${SUDO_USER:-$USER}:www-data /var/www
"${SUDO_CMD}" find /var/www -type d -exec chmod 2755 {} \+
"${SUDO_CMD}" find /var/www -type f -exec chmod 644 {} \+
"${SUDO_CMD}" find /var/www -type d -exec chmod g+s {} +
