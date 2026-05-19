#!/bin/bash

setup_ssh_key() {
    local account=$1
    local key_name=${2:-"Piedade"}
    local pub_key_file=~/.ssh/id_ed25519.pub

    [ ! -f "$pub_key_file" ] && { echo_error "~/.ssh/id_ed25519.pub not found"; return 1; }

    echo_info "Setting up SSH key for $account..."
    ssh "$SERVER" "
        mkdir -p /home/$account/.ssh &&
        chown $account:$account /home/$account/.ssh &&
        chmod 700 /home/$account/.ssh
    "
    ssh "$SERVER" "cat > /home/$account/.ssh/${key_name}.pub" < "$pub_key_file"
    ssh "$SERVER" "
        grep -qxF \"\$(cat /home/$account/.ssh/${key_name}.pub)\" /home/$account/.ssh/authorized_keys 2>/dev/null ||
            cat /home/$account/.ssh/${key_name}.pub >> /home/$account/.ssh/authorized_keys &&
        chown $account:$account /home/$account/.ssh/${key_name}.pub /home/$account/.ssh/authorized_keys 2>/dev/null &&
        chmod 644 /home/$account/.ssh/${key_name}.pub &&
        chmod 600 /home/$account/.ssh/authorized_keys
    "
}

create_wordpress() {
    local ACCOUNT=$1
    local DOMAIN=$2
    local ROOT_DIR=$3
    local DB_NAME=$4
    local ENABLE_MULTI_PHP=$5

    if [ $# -eq 0 ]; then
        read -rp "Account: " ACCOUNT
        if [ -z "$ACCOUNT" ]; then
            echo_error "Account is required."
            return 1
        fi

        local _default_domain="$ACCOUNT.dev.red.com.pt"
        read -rp "Domain [$_default_domain]: " DOMAIN
        [ -z "$DOMAIN" ] && DOMAIN="$_default_domain"

        read -rp "Root directory [public_html]: " ROOT_DIR
        [ -z "$ROOT_DIR" ] && ROOT_DIR="public_html"

        read -rp "Database name [site]: " DB_NAME
        [ -z "$DB_NAME" ] && DB_NAME="site"

        read -rp "Enable MultiPHP? [y/N]: " _multi
        case "$_multi" in
            [Yy]*) ENABLE_MULTI_PHP="yes" ;;
            *) ENABLE_MULTI_PHP="" ;;
        esac
    else
        if [ -z "$ACCOUNT" ]; then
            echo_error "Usage: create_wordpress <account> [domain] [root_dir] [db_name] [enable_multi_php]"
            return 1
        fi

        [ -z "$DOMAIN" ] && DOMAIN="$ACCOUNT.dev.red.com.pt"
        [ -z "$ROOT_DIR" ] && ROOT_DIR="public_html"
        [ -z "$DB_NAME" ] && DB_NAME="site"
    fi

    # Confirmation to the user that the variables are correct
    echo_info "Account: $ACCOUNT"
    echo_info "Domain: $DOMAIN"
    echo_info "Root: ~/$ROOT_DIR"
    echo_info "Database: $DB_NAME"
    if [ -n "$ENABLE_MULTI_PHP" ]; then
        echo_info "Enable MultiPHP: $ENABLE_MULTI_PHP"
    fi

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

    setup_ssh_key "$ACCOUNT"

    local DB_PASS=$(gen_pass)
    local WP_ADMIN_PASS=$(gen_pass)
    local EMAIL_PASS=$(gen_pass)
    local WP_BIN="/opt/alt/php84/usr/bin/php -d memory_limit=-1 /usr/local/bin/wp"

    echo_info "Setting PHP version to 8.4..."
    run_remote "selectorctl --interpreter=php --set-user-current=8.4"


    echo_info "Creating database and user..."
    # run_remote "uapi Mysql list_users"
    run_remote "uapi Mysql create_database name='${ACCOUNT}_${DB_NAME}'"
    run_remote "uapi Mysql create_user name='${ACCOUNT}_${DB_NAME}' password='${DB_PASS}'"
    run_remote "uapi Mysql set_privileges_on_database user='${ACCOUNT}_${DB_NAME}' database='${ACCOUNT}_${DB_NAME}' privileges='ALL PRIVILEGES'"


    echo_info "Creating email..."
    run_remote "uapi Email add_pop email='noreply@${DOMAIN}' password='${EMAIL_PASS}'"
    run_remote "uapi Email suspend_incoming email='noreply@${DOMAIN}'"


    echo_info "Disable Nginx cache..."
    run_remote "uapi NginxCaching disable_cache"


    echo_info "Creating .htaccess..."
    local HTACCESS_CONTENT=""

    HTACCESS_CONTENT+="# http to https
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
</IfModule>"

    if [ "$ENABLE_MULTI_PHP" = "yes" ] || [ "$ENABLE_MULTI_PHP" = "true" ]; then
        HTACCESS_CONTENT+="

# php -- BEGIN cPanel-generated handler, do not edit
# Set the \"ea-php84\" package as the default \"PHP\" programming language.
<IfModule mime_module>
  AddHandler application/x-httpd-ea-php84___lsphp .php .php8 .phtml
</IfModule>
# php -- END cPanel-generated handler, do not edit
"
    fi

HTACCESS_CONTENT+="

# BEGIN cPanel-generated php ini directives, do not edit
<IfModule php8_module>
   php_flag display_errors Off
   php_value max_execution_time 30
   php_value max_input_time 60
   php_value max_input_vars 1000
   php_value memory_limit 256M
   php_value post_max_size 32M
   php_value session.gc_maxlifetime 1440
   php_value session.save_path \"/var/cpanel/php/sessions/ea-php84\"
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
   php_value session.save_path \"/var/cpanel/php/sessions/ea-php84\"
   php_value upload_max_filesize 16M
   php_flag zlib.output_compression Off
</IfModule>
# END cPanel-generated php ini directives, do not edit"

    run_remote "cat > ~/$ROOT_DIR/.htaccess <<EOL
$HTACCESS_CONTENT
EOL"

    echo_info "Installing WordPress..."
    run_remote "cd ~/$ROOT_DIR && $WP_BIN core download --locale='pt_PT'"
    run_remote "cd ~/$ROOT_DIR && $WP_BIN config create --dbname='${ACCOUNT}_${DB_NAME}' --dbuser='${ACCOUNT}_${DB_NAME}' --dbpass='${DB_PASS}'"
    run_remote "cd ~/$ROOT_DIR && $WP_BIN core install --url='https://${DOMAIN}' --title='${ACCOUNT}' --admin_user='redpost' --admin_password='${WP_ADMIN_PASS}' --admin_email='webmaster@redpost.pt' --skip-email"

    echo_info "Deleting default post..."
    run_remote "cd ~/$ROOT_DIR && $WP_BIN post delete 1 --force"

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

    echo_info "Testing email..."
    run_remote "
        cd ~/$ROOT_DIR && $WP_BIN eval \"
            if (wp_mail('webmaster@redpost.pt', 'Email Test from ${ACCOUNT}', 'This is a test email from your new WordPress site for https://${DOMAIN} (${ACCOUNT}).')) {
                echo 'Email sent successfully';
            } else {
                echo 'Failed to send email';
            }
        \"
    "

    echo
    echo "🌍 Site: https://$DOMAIN/wp-admin/admin.php?page=elementor"
    echo "👤 Admin: redpost"
    echo "🔑 Admin Password: $WP_ADMIN_PASS"

    echo "🗄️ Database:"
    echo "User: ${ACCOUNT}_${DB_NAME}"
    echo "Pass: $DB_PASS"

    echo "📧 Email:"
    echo "noreply@$DOMAIN"
    echo "Pass: $EMAIL_PASS"
}
