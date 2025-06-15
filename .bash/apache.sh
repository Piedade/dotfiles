#!/bin/bash

createdomain() {
    echo "Enter the domain name (e.g., example.com): "
    read DOMAIN

    # Define paths
    VHOST_CONF="/etc/apache2/sites-available/$DOMAIN.conf"
    WEB_ROOT="/var/www/$DOMAIN"

    # Create web directory
    sudo mkdir -p "$WEB_ROOT"
    sudo chown -R $USER:$USER "$WEB_ROOT"
    sudo chmod -R 755 /var/www

    # Create Virtual Host Config
    sudo tee $VHOST_CONF <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    Redirect permanent / https://$DOMAIN
</VirtualHost>
<VirtualHost *:443>
    ServerName $DOMAIN
    DocumentRoot $WEB_ROOT

    SSLEngine on
    SSLCertificateFile "/var/www/ssl/$DOMAIN.pem"
    SSLCertificateKeyFile "/var/www/ssl/$DOMAIN-key.pem"

    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php8.4-fpm.sock|fcgi://localhost"
    </FilesMatch>

    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
EOF

    ( cd /var/www/ssl ; mkcert $DOMAIN )

    # Enable site and restart Apache
    sudo a2ensite "$DOMAIN.conf" > /dev/null
    sudo systemctl reload apache2 > /dev/null

    echo "Virtual host for $DOMAIN has been created."
}

fixpermissions() {
    current_dir=$(pwd)

    # Check if the current directory is inside /var/www
    if [[ ! "$current_dir" =~ ^/var/www ]]; then
        echo "❌ Current directory is not inside /var/www. Please navigate to the correct directory."
        return 1
    fi

    # Check if composer.json exists
    if [[ ! -f "composer.json" ]]; then
        echo "This does not appear to be a valid Laravel or PrestaShop project."
        echo "❌ composer.json not found."
        return 1
    fi

    # Check the 'name' property in composer.json to determine the framework
    framework=$(jq -r '.name' composer.json)

    if [[ "$framework" == "laravel/laravel" ]]; then
        folders="storage bootstrap/cache"
        appName="$ORANGE_LARAVEL Laravel"

    elif [[ "$framework" == "prestashop/prestashop" ]]; then
        folders="admin-dev/autoupgrade app/config config download img log mails modules override themes translations upload var"
        appName="$BLUE_PRESTASHOP󱇕 PrestaShop"

    else
        echo "❌ composer.json found, but the 'name' property does not match a recognized framework."
        return 1
    fi

    # Ask for sudo to run the command
    sudo -v &>/dev/null

    # Apply permissions
    current_folder=$(basename $current_dir)
    echo -e "for $BOLD$appName$RESET $ITALIC($current_folder)$RESET on the folders:"

    # FIX permissions
    sudo chown -R $USER:www-data "$current_dir"
    find "$current_dir" -type d -exec chmod 2755 {} \+
    find "$current_dir" -type f -exec chmod 644 {} \+

    for folder in ${folders}; do
        if [ ! -d "$folder" ]; then
            echo -e "- $folder $ITALIC${YELLOW}created${RESET}"
            mkdir -p "$folder"
        else
            echo "- $folder"
        fi
        chmod -R 775 "$folder"
    done
    echo -e "$BOLD$GREEN Permissions have been set.$RESET"
}
