#!/bin/bash

create_domain() {
    if [ -z "$1" ]; then
        echo "Enter the domain name (e.g., example.com): "
        read DOMAIN
    else
        DOMAIN="$1"
    fi

    # Define paths
    VHOST_CONF="/etc/apache2/sites-available/$DOMAIN.conf"
    WEB_ROOT="/var/www/$DOMAIN"

    # Create web directory
    if [ ! -d "$WEB_ROOT" ]; then
        echo_info "Directory '$WEB_ROOT' does not exist. Creating it now..."

        sudo mkdir -p "$WEB_ROOT"
        sudo chown -R $USER:$USER "$WEB_ROOT"

        if [ $? -eq 0 ]; then
            echo_success "Directory '$WEB_ROOT' created successfully."
        else
            echo_error "Error: Failed to create directory '$WEB_ROOT'." >&2
            exit 1 # Exit with an error code
        fi
    else
        echo_error "Directory '$WEB_ROOT' already exists."
    fi

    # Create Virtual Host Config
    sudo tee $VHOST_CONF > /dev/null <<EOF
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

    echo_success "Virtual host for $DOMAIN has been created."
}

fix_permissions() {
    COMPOSER_FILE="composer.lock"

    current_dir=$(pwd)

    # Check if the current directory is inside /var/www
    if [[ ! "$current_dir" =~ ^/var/www ]]; then
        echo_error "Current directory is not inside /var/www. Please navigate to the correct directory."
        return 1
    fi

    # Initialize variables
    folders=""
    appName=""
    framework_matched=false

    # Check if composer.json exists
    if [[ ! -f "$COMPOSER_FILE" ]]; then
        echo_info "This does not appear to be a valid Laravel or PrestaShop project."
        echo_info "$COMPOSER_FILE not found."
    else
        composer_content=$(tr '[:upper:]' '[:lower:]' < "$COMPOSER_FILE")

        framework_matched=false

        if grep -qi "laravel" <<< "$composer_content"; then
            folders="storage bootstrap/cache"
            appName="${ORANGE_LARAVEL} Laravel${NO_COLOR}"
            framework_matched=true
        fi

        if grep -qi "prestashop" <<< "$composer_content"; then
            # If both exist, PrestaShop will override Laravel — adjust logic if you prefer otherwise
            folders="app/config config download img log mails modules override themes translations upload var"
            appName="${BLUE_PRESTASHOP}󱇕 PrestaShop${NO_COLOR}"
            framework_matched=true
        fi

        if [ "$framework_matched" = false ]; then
            echo "❌ composer.json found, but no recognized framework ('laravel', 'prestashop') was found."
            return 1
        fi
    fi

    # Ask for sudo to run the command
    sudo -v &>/dev/null

    # Apply permissions
    current_folder=$(basename $current_dir)
    echo -e "for $BOLD$appName$RESET $ITALIC($current_folder)$RESET on the folders:"

    # FIX permissions
    sudo chown -R $USER:$USER "$current_dir"
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
