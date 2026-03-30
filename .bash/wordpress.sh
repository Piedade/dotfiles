#!/bin/bash

create_wordpress() {
    local ACCOUNT=$1
    local DOMAIN=$2
    local ROOT_DIR=$3

    if [ -z "$ACCOUNT" ]; then
        echo_error "Usage: create_wordpress <account> [domain] [root_dir]"
        return 1
    fi

    if [ -z "$DOMAIN" ]; then
        DOMAIN="$ACCOUNT.dev.red.com.pt"
    fi

    if [ -z "$ROOT_DIR" ]; then
        ROOT_DIR="public_html"
    fi

    # Confirmation to the user that the variables are correct
    echo_info "Account: $ACCOUNT"
    echo_info "Domain: $DOMAIN"
    echo_info "Root: ~/$ROOT_DIR"

    # Ask the user for confirmation if the variables are correct
    read -rp "Do you want to continue? [y/N]: " answer
    case "$answer" in
        [Yy]* )
            echo "Continuing..."
            ;;
        * )
            echo_error "Operation cancelled."
            return 1
            ;;
    esac


    # Check shell access
    check_shell_access "$ACCOUNT" 1
    case $? in
        1)
            # User exists but no shell → ask if should activate
            echo "Activating shell access..."
            add_shell_access "$ACCOUNT" || { echo_error "Failed to activate shell"; return; }
            ;;
        2)
            echo_error "$ACCOUNT not found."
            return 1
            ;;
        3)
            echo_error "$ACCOUNT has an unusual shell. Please check manually."
            return 1
            ;;
    esac

    local DB_PASS=$(gen_pass)
    local WP_ADMIN_PASS=$(gen_pass)
    local EMAIL_PASS=$(gen_pass)

    local WP_BIN="/opt/alt/php84/usr/bin/php -d memory_limit=-1 /usr/local/bin/wp"

    echo_info "Setting PHP version to 8.4..."
    run_remote "selectorctl --interpreter=php --set-user-current=8.4"


    echo_info "Creating database and user..."
    # run_remote "uapi Mysql list_users"
    run_remote "uapi Mysql create_database name='${ACCOUNT}_site'"
    run_remote "uapi Mysql create_user name='${ACCOUNT}_site' password='${DB_PASS}'"
    run_remote "uapi Mysql set_privileges_on_database user='${ACCOUNT}_site' database='${ACCOUNT}_site' privileges='ALL PRIVILEGES'"


    echo_info "Creating email..."
    run_remote "uapi Email add_pop email='noreply@${DOMAIN}' password='${EMAIL_PASS}'"
    run_remote "uapi Email suspend_incoming email='noreply@${DOMAIN}'"


    echo_info "Disable Nginx cache..."
    run_remote "uapi NginxCaching disable_cache"


    echo_info "Creating .htaccess..."
    run_remote "cat > ~/$ROOT_DIR/.htaccess <<'EOL'
# http to https
RewriteEngine On
RewriteCond %{SERVER_PORT} 80
RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]

# www to non-www
RewriteCond %{HTTP_HOST} ^www\.(.*)$ [NC]
RewriteRule ^(.*)$ http://%1%{REQUEST_URI} [R=301,QSA,NC,L]

# Block WordPress xmlrpc.php requests
<Files xmlrpc.php>
order deny,allow
deny from all
</Files>

# Block wp-config.php
<files wp-config.php>
order allow,deny
deny from all
</files>

# Block the include-only files.
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^wp-admin/includes/ - [F,L]
RewriteRule !^wp-includes/ - [S=3]
RewriteRule ^wp-includes/[^/]+\.php$ - [F,L]
RewriteRule ^wp-includes/js/tinymce/langs/.+\.php - [F,L]
RewriteRule ^wp-includes/theme-compat/ - [F,L]
</IfModule>

# BEGIN cPanel-generated php ini directives, do not edit
<IfModule php8_module>
   php_flag display_errors Off
   php_value max_execution_time 30
   php_value max_input_time 60
   php_value max_input_vars 1000
   php_value memory_limit 256M
   php_value post_max_size 32M
   php_value session.gc_maxlifetime 1440
   php_value session.save_path "/var/cpanel/php/sessions/ea-php84"
   php_value upload_max_filesize 16M
   php_flag zlib.output_compression Off
</IfModule>
<IfModule lsapi_module>
   php_flag display_errors Off
   php_value max_execution_time 30
   php_value max_input_time 60
   php_value max_input_vars 1000
   php_value memory_limit 256M
   php_value post_max_size 32M
   php_value session.gc_maxlifetime 1440
   php_value session.save_path "/var/cpanel/php/sessions/ea-php84"
   php_value upload_max_filesize 16M
   php_flag zlib.output_compression Off
</IfModule>
# END cPanel-generated php ini directives, do not edit
EOL"

    echo_info "Installing WordPress..."
    run_remote "cd ~/$ROOT_DIR && $WP_BIN core download --locale='pt_PT'"
    run_remote "cd ~/$ROOT_DIR && $WP_BIN config create --dbname='${ACCOUNT}_site' --dbuser='${ACCOUNT}_site' --dbpass='${DB_PASS}'"
    run_remote "cd ~/$ROOT_DIR && $WP_BIN core install --url='https://${DOMAIN}' --title='${ACCOUNT}' --admin_user='redpost' --admin_password='${WP_ADMIN_PASS}' --admin_email='webmaster@redpost.pt' --skip-email"


    echo_info "Applying security settings..."
    run_remote "cd ~/$ROOT_DIR && $WP_BIN config shuffle-salts"
    run_remote "cd ~/$ROOT_DIR && $WP_BIN config set DISALLOW_FILE_EDIT true --raw"
    run_remote "cd ~/$ROOT_DIR && $WP_BIN config set WP_MEMORY_LIMIT 256M"


    echo_info "Disabling plugins..."
    run_remote "cd ~/$ROOT_DIR && $WP_BIN plugin install disable-xml-rpc disable-json-api simple-smtp elementor --activate"


    echo_info "Mail config..."
    run_remote "cd ~/$ROOT_DIR && $WP_BIN config set SMTP_HOST 'localhost'"
    run_remote "cd ~/$ROOT_DIR && $WP_BIN config set SMTP_AUTH 1 --raw"
    run_remote "cd ~/$ROOT_DIR && $WP_BIN config set SMTP_USER 'noreply@${DOMAIN}'"
    run_remote "cd ~/$ROOT_DIR && $WP_BIN config set SMTP_PASS '${EMAIL_PASS}'"
    run_remote "cd ~/$ROOT_DIR && $WP_BIN config set SMTP_FROM 'noreply@${DOMAIN}'"
    run_remote "cd ~/$ROOT_DIR && $WP_BIN config set SMTP_FROMNAME '${ACCOUNT}'"


    echo_info "Cleaning default plugins/themes..."
    run_remote "cd ~/$ROOT_DIR && $WP_BIN plugin delete hello akismet"
    run_remote "cd ~/$ROOT_DIR && $WP_BIN theme install hello-elementor --activate"
    run_remote "cd ~/$ROOT_DIR && $WP_BIN theme delete twentytwentytwo twentytwentythree twentytwentyfour twentytwentyfive"


    echo_info "Setting permissions..."
    run_remote "cd ~/$ROOT_DIR && find . -type d -exec chmod 755 {} \;"
    run_remote "cd ~/$ROOT_DIR && find . -type f -exec chmod 644 {} \;"
    run_remote "cd ~/$ROOT_DIR && chmod 400 wp-config.php"


    echo "🌍 Site: https://$DOMAIN/wp-admin/admin.php?page=elementor"
    echo "👤 Admin: redpost"
    echo "🔑 Admin Password: $WP_ADMIN_PASS"

    echo "🗄️ Database:"
    echo "User: ${ACCOUNT}_site"
    echo "Pass: $DB_PASS"

    echo "📧 Email:"
    echo "noreply@$DOMAIN"
    echo "Pass: $EMAIL_PASS"
}
