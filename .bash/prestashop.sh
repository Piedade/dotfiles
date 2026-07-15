create_prestashop() {
    local ACCOUNT=$1
    local DOMAIN=$2
    local ROOT_DIR=$3
    local DB_NAME=$4
    local ENABLE_MULTI_PHP=$5
    local FIXTURES=$6
    local SHOP_NAME

    if [ -z "$ACCOUNT" ]; then
        ACCOUNT=$(select_account) || { echo_error "Account is required."; return 1; }
    fi

    local _main_domain
    _main_domain=$(select_domain "$ACCOUNT") || _main_domain=""

    if [ $# -eq 0 ]; then
        local _default_domain="$ACCOUNT.dev.red.com.pt"
        read -rp "Domain [$_default_domain]: " DOMAIN
        [ -z "$DOMAIN" ] && DOMAIN="$_default_domain"

        local _default_root_dir="public_html"
        [ "$DOMAIN" != "$_default_domain" ] && [ "$DOMAIN" != "$_main_domain" ] && _default_root_dir="$DOMAIN"
        read -rp "Root directory [$_default_root_dir]: " ROOT_DIR
        [ -z "$ROOT_DIR" ] && ROOT_DIR="$_default_root_dir"

        local _default_db_name="site"
        [ "$DOMAIN" != "$_default_domain" ] && [ "$DOMAIN" != "$_main_domain" ] && _default_db_name="${DOMAIN%%.*}"
        _default_db_name="${_default_db_name//-/_}"
        read -rp "Database name [$_default_db_name]: " DB_NAME
        [ -z "$DB_NAME" ] && DB_NAME="$_default_db_name"

        read -rp "Shop name [$ACCOUNT]: " SHOP_NAME
        [ -z "$SHOP_NAME" ] && SHOP_NAME="$ACCOUNT"

        read -rp "Enable MultiPHP? [y/N]: " _multi
        case "$_multi" in
            [Yy]*) ENABLE_MULTI_PHP="yes" ;;
            *) ENABLE_MULTI_PHP="" ;;
        esac

        read -rp "Install demo fixtures? [Y/n]: " _fixtures
        case "$_fixtures" in
            [Nn]*) FIXTURES="0" ;;
            *) FIXTURES="1" ;;
        esac
    else
        [ -z "$DOMAIN" ] && DOMAIN="$ACCOUNT.dev.red.com.pt"
        if [ -z "$ROOT_DIR" ]; then
            if [ "$DOMAIN" = "$ACCOUNT.dev.red.com.pt" ] || [ "$DOMAIN" = "$_main_domain" ]; then
                ROOT_DIR="public_html"
            else
                ROOT_DIR="$DOMAIN"
            fi
        fi
        if [ -z "$DB_NAME" ]; then
            if [ "$DOMAIN" = "$ACCOUNT.dev.red.com.pt" ] || [ "$DOMAIN" = "$_main_domain" ]; then
                DB_NAME="site"
            else
                DB_NAME="${DOMAIN%%.*}"
            fi
        fi
        [ -z "$SHOP_NAME" ] && SHOP_NAME="$ACCOUNT"
        [ -z "$FIXTURES" ] && FIXTURES="1"
    fi

    # Validate DB_NAME: replace hyphens and enforce 16-char limit
    if [[ "$DB_NAME" == *-* ]]; then
        local _db_name_clean="${DB_NAME//-/_}"
        echo_error "DB_NAME '$DB_NAME' contains hyphens. Converting to '$_db_name_clean'."
        DB_NAME="$_db_name_clean"
    fi
    if [ ${#DB_NAME} -gt 16 ]; then
        local _db_name_truncated="${DB_NAME:0:16}"
        echo_error "DB_NAME '$DB_NAME' exceeds 16 characters. Truncating to '$_db_name_truncated'."
        DB_NAME="$_db_name_truncated"
    fi

    # Check domain ownership so the confirmation shows what will happen to it
    local DOMAIN_OWNER
    DOMAIN_OWNER=$(whm_account_by_domain "$DOMAIN")
    local DOMAIN_STATUS
    if [ -z "$DOMAIN_OWNER" ]; then
        DOMAIN_STATUS="will be created"
    elif [ "$DOMAIN_OWNER" != "$ACCOUNT" ]; then
        echo_error "Domain $DOMAIN already belongs to another account ($DOMAIN_OWNER). Aborting."
        return 1
    else
        DOMAIN_STATUS="already exists for this account"
    fi

    echo_info "Account: $ACCOUNT"
    echo_info "Domain: $DOMAIN ($DOMAIN_STATUS)"
    echo_info "Root: ~/$ROOT_DIR"
    echo_info "Database: ${ACCOUNT}_${DB_NAME}"
    echo_info "Shop name: $SHOP_NAME"
    echo_info "Demo fixtures: $([ "$FIXTURES" = "1" ] && echo yes || echo no)"
    if [ -n "$ENABLE_MULTI_PHP" ]; then
        echo_info "Enable MultiPHP: $ENABLE_MULTI_PHP"
    fi

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
            echo "Activating shell access..."
            add_shell_access "$ACCOUNT" || { echo_error "Failed to activate shell"; return 1; }
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

    # Abort early rather than silently overwriting an existing site (unzip -o would clobber
    # matching files) or generating a fresh password that won't match an existing DB user's
    # real one — that mismatch only surfaces later as an opaque DB-connection failure.
    if remote_file_exists "$ACCOUNT" "$ROOT_DIR/app/config/parameters.php" \
        || remote_file_exists "$ACCOUNT" "$ROOT_DIR/config/settings.inc.php"; then
        echo_error "~/$ROOT_DIR already has an installed PrestaShop (parameters.php/settings.inc.php found). Aborting."
        return 1
    fi
    if mysql_database_exists "$ACCOUNT" "${ACCOUNT}_${DB_NAME}"; then
        echo_error "Database ${ACCOUNT}_${DB_NAME} already exists. Aborting."
        return 1
    fi
    if mysql_user_exists "$ACCOUNT" "${ACCOUNT}_${DB_NAME}"; then
        echo_error "MySQL user ${ACCOUNT}_${DB_NAME} already exists. Aborting."
        return 1
    fi

    if [ -z "$DOMAIN_OWNER" ]; then
        # Este servidor não tem o módulo AddonDomain (nem em uapi nem em cpapi2).
        # Uma addon domain é, por baixo, um subdomínio interno com docroot próprio +
        # o domínio real "estacionado" (parked) nesse vhost — feito ao nível do WHM (root).
        if [ -z "$_main_domain" ]; then
            echo_error "Não consegui determinar o domínio principal de '$ACCOUNT' para criar '$DOMAIN'."
            return 1
        fi

        local SUBDOMAIN="${DOMAIN%%.*}"
        local INTERNAL_SUBDOMAIN="${SUBDOMAIN}.${_main_domain}"

        echo_info "Creating internal subdomain $INTERNAL_SUBDOMAIN..."
        ssh "$SERVER" "whmapi1 create_subdomain domain='${INTERNAL_SUBDOMAIN}' document_root='${ROOT_DIR}'" \
            || { echo_error "Falha a criar o subdomínio interno para '$DOMAIN'."; return 1; }

        if [ "$DOMAIN" != "$INTERNAL_SUBDOMAIN" ]; then
            echo_info "Creating $DOMAIN as addon domain (parked em $INTERNAL_SUBDOMAIN)..."
            ssh "$SERVER" "whmapi1 create_parked_domain_for_user domain='${DOMAIN}' username='${ACCOUNT}' web_vhost_domain='${INTERNAL_SUBDOMAIN}'" \
                || { echo_error "Falha a associar o domínio '$DOMAIN'."; return 1; }
        fi
    fi

    local DB_PASS ADMIN_PASS EMAIL_PASS
    DB_PASS=$(gen_pass)
    ADMIN_PASS=$(gen_pass)
    EMAIL_PASS=$(gen_pass)
    local PS_LANGUAGE="pt"
    local PS_COUNTRY="pt"
    local PHP_BIN="/opt/alt/php84/usr/bin/php -d memory_limit=-1"

    if [ "$ENABLE_MULTI_PHP" = "yes" ] || [ "$ENABLE_MULTI_PHP" = "true" ]; then
        echo_info "MultiPHP enabled: skipping account-wide default (this domain forces 8.4 via .htaccess)."
    else
        echo_info "Setting PHP version to 8.4..."
        run_remote "$ACCOUNT" "selectorctl --interpreter=php --set-user-current=8.4"
    fi

    echo_info "Checking required PHP extensions..."
    check_php_extensions "$ACCOUNT" "/opt/alt/php84/usr/bin/php" \
        curl dom fileinfo gd iconv intl json mbstring openssl simplexml zip \
        || return 1

    echo_info "Creating database and user..."
    run_remote "$ACCOUNT" "uapi Mysql create_database name='${ACCOUNT}_${DB_NAME}'"
    run_remote "$ACCOUNT" "uapi Mysql create_user name='${ACCOUNT}_${DB_NAME}' password='${DB_PASS}'"
    run_remote "$ACCOUNT" "uapi Mysql set_privileges_on_database user='${ACCOUNT}_${DB_NAME}' database='${ACCOUNT}_${DB_NAME}' privileges='ALL PRIVILEGES'"

    echo_info "Creating email..."
    run_remote "$ACCOUNT" "uapi Email add_pop email='noreply@${DOMAIN}' password='${EMAIL_PASS}'"
    run_remote "$ACCOUNT" "uapi Email suspend_incoming email='noreply@${DOMAIN}'"

    echo_info "Disable Nginx cache..."
    run_remote "$ACCOUNT" "uapi NginxCaching disable_cache"

    # --- Build the release locally: composer create-release needs composer/node/npm/make,
    # which a shared cPanel account won't have. Only the finished release ZIP travels over SSH.
    # Built zips are cached by version in CACHE_DIR so re-running for the same version (e.g.
    # a second account) skips the clone + build entirely.
    local TMP_DIR="/tmp/prestashop_install"
    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"

    local CACHE_DIR="$HOME/.cache/prestashop-releases"
    mkdir -p "$CACHE_DIR"

    local RELEASE_ZIP VERSION
    echo_info "🔎 Checking latest PrestaShop release on GitHub..."
    VERSION=$(curl -fsSL https://api.github.com/repos/PrestaShop/PrestaShop/releases/latest | jq -r '.tag_name')
    if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
        echo_error "Failed to fetch latest PrestaShop version from GitHub."
        rm -rf "$TMP_DIR"
        return 1
    fi
    echo_info "Latest version: $VERSION"

    local CACHED_ZIP="$CACHE_DIR/prestashop_${VERSION}.zip"

    if [ -f "$CACHED_ZIP" ]; then
        echo_info "📦 Reusing cached build for PrestaShop $VERSION..."
        RELEASE_ZIP="$CACHED_ZIP"
    else
        echo_info "⬇️  Cloning PrestaShop $VERSION..."
        if ! git clone --quiet --depth 1 --branch "$VERSION" https://github.com/PrestaShop/PrestaShop.git "$TMP_DIR/src"; then
            echo_error "Failed to clone PrestaShop $VERSION."
            rm -rf "$TMP_DIR"
            return 1
        fi

        # Defends against silently building the wrong ref: --branch on a shallow clone should
        # only ever land exactly on the tag, but verify rather than assume.
        local CLONED_REF
        CLONED_REF=$(git -C "$TMP_DIR/src" describe --tags --exact-match 2>/dev/null)
        if [ "$CLONED_REF" != "$VERSION" ]; then
            echo_error "Cloned ref '$CLONED_REF' does not match expected version '$VERSION'. Aborting."
            rm -rf "$TMP_DIR"
            return 1
        fi

        echo_info "🛠️  Building release with composer create-release (this can take a while)..."
        if ! (cd "$TMP_DIR/src" && composer create-release -- --version="$VERSION" --destination-dir="$TMP_DIR/release"); then
            echo_error "composer create-release failed."
            rm -rf "$TMP_DIR"
            return 1
        fi

        local BUILT_ZIP
        BUILT_ZIP=$(find "$TMP_DIR/release" -maxdepth 1 -iname "prestashop_*.zip" | head -n1)
        if [ -z "$BUILT_ZIP" ] || [ ! -f "$BUILT_ZIP" ]; then
            echo_error "Release zip not found in $TMP_DIR/release."
            rm -rf "$TMP_DIR"
            return 1
        fi

        cp "$BUILT_ZIP" "$CACHED_ZIP"
        RELEASE_ZIP="$CACHED_ZIP"
    fi

    echo_info "📦 Extracting installer wrapper to reach the inner PrestaShop ZIP..."
    mkdir -p "$TMP_DIR/unpacked"
    unzip -q "$RELEASE_ZIP" -d "$TMP_DIR/unpacked"

    local INNER_ZIP
    INNER_ZIP=$(find "$TMP_DIR/unpacked" -maxdepth 1 -type f -iname "prestashop*.zip" | head -n1)
    if [ -z "$INNER_ZIP" ] || [ ! -f "$INNER_ZIP" ]; then
        echo_error "Expected internal PrestaShop ZIP file not found!"
        rm -rf "$TMP_DIR"
        return 1
    fi

    echo_info "⬆️  Uploading release to ${ACCOUNT}@server..."
    scp -q "$INNER_ZIP" "${ACCOUNT}@server:~/prestashop_release.zip" || { echo_error "scp failed."; rm -rf "$TMP_DIR"; return 1; }
    rm -rf "$TMP_DIR"

    echo_info "📁 Extracting on the server into ~/$ROOT_DIR..."
    run_remote "$ACCOUNT" "mkdir -p ~/$ROOT_DIR && unzip -q -o ~/prestashop_release.zip -d ~/$ROOT_DIR && rm -f ~/prestashop_release.zip"

    # PrestaShop ships its own .htaccess with the rewrite rules it needs — appended (never
    # overwritten) with the same cPanel PHP ini directives create_wordpress uses, since the
    # admin (image processing, imports, module installs) needs more than default PHP limits.
    if [ "$ENABLE_MULTI_PHP" = "yes" ] || [ "$ENABLE_MULTI_PHP" = "true" ]; then
        echo_info "Forcing PHP 8.4 for this domain via MultiPHP..."
        run_remote "$ACCOUNT" "cat >> ~/$ROOT_DIR/.htaccess <<EOL

# php -- BEGIN cPanel-generated handler, do not edit
# Set the “alt-php84” package as the default “PHP” programming language.
<IfModule mime_module>
  AddHandler application/x-httpd-alt-php84___lsphp .php .php8 .phtml
</IfModule>
# php -- END cPanel-generated handler, do not edit
EOL"
    fi

    echo_info "Tuning PHP limits in .htaccess..."
    run_remote "$ACCOUNT" "cat >> ~/$ROOT_DIR/.htaccess <<EOL

# BEGIN cPanel-generated php ini directives, do not edit
<IfModule php8_module>
   php_flag display_errors Off
   php_value max_execution_time 60
   php_value max_input_time 60
   php_value max_input_vars 1000
   php_value memory_limit 512M
   php_value post_max_size 32M
   php_value session.gc_maxlifetime 1440
   php_value session.save_path \"/var/cpanel/php/sessions/ea-php84\"
   php_value upload_max_filesize 16M
   php_flag zlib.output_compression Off
</IfModule>
<IfModule lsapi_module>
   php_flag display_errors Off
   php_value max_execution_time 60
   php_value max_input_time 60
   php_value max_input_vars 1000
   php_value memory_limit 512M
   php_value post_max_size 32M
   php_value session.gc_maxlifetime 1440
   php_value session.save_path \"/var/cpanel/php/sessions/ea-php84\"
   php_value upload_max_filesize 16M
   php_flag zlib.output_compression Off
</IfModule>
# END cPanel-generated php ini directives, do not edit
EOL"

    echo_info "📝 Creating composer.json on the server..."
    ssh "${ACCOUNT}@server" "cat > ~/$ROOT_DIR/composer.json" <<EOF
{
    "\$schema": "https://getcomposer.org/schema.json",
    "name": "red/${ACCOUNT}",
    "type": "project",
    "description": "",
    "keywords": [
        "prestashop"
    ],
    "config": {
        "platform": {
            "php": "8.4"
        }
    },
    "license": "MIT",
    "require": {
        "php": "^8.1"
    },
    "scripts": {
        "dev": [
            "Composer\\\\Config::disableProcessTimeout",
            "npx concurrently -c \"#fdba74\" \"cd themes/${ACCOUNT} && npm run dev\" --names=vite"
        ]
    },
    "minimum-stability": "stable",
    "prefer-stable": true
}
EOF

    echo_info "🚀 Running PrestaShop CLI installer remotely..."
    run_remote "$ACCOUNT" "cd ~/$ROOT_DIR/install && $PHP_BIN index_cli.php \
        --language='$PS_LANGUAGE' \
        --country='$PS_COUNTRY' \
        --domain='$DOMAIN' \
        --db_server='localhost' \
        --db_name='${ACCOUNT}_${DB_NAME}' \
        --db_user='${ACCOUNT}_${DB_NAME}' \
        --db_password='${DB_PASS}' \
        --db_create='0' \
        --ssl='1' \
        --fixtures='$FIXTURES' \
        --name='$SHOP_NAME' \
        --email='webmaster@redpost.pt' \
        --password='${ADMIN_PASS}' \
        --firstname='Webmaster' \
        --lastname='RED'"

    echo_info "🧹 Cleaning up install folder..."
    run_remote "$ACCOUNT" "rm -rf ~/$ROOT_DIR/install"

    # The installer auto-renames admin/ to a random slug (printed in its own output above);
    # capture it here so the final summary can show the real backoffice URL.
    local ADMIN_DIR
    ADMIN_DIR=$(ssh "${ACCOUNT}@server" "cd ~/$ROOT_DIR && ls -d admin*/ 2>/dev/null | head -n1" | tr -d '/')

    echo_info "Setting permissions..."
    run_remote "$ACCOUNT" "cd ~/$ROOT_DIR && find . -type d -exec chmod 755 {} \;"
    run_remote "$ACCOUNT" "cd ~/$ROOT_DIR && find . -type f -exec chmod 644 {} \;"
    run_remote "$ACCOUNT" "cd ~/$ROOT_DIR && [ -f app/config/parameters.php ] && chmod 400 app/config/parameters.php; [ -f config/settings.inc.php ] && chmod 400 config/settings.inc.php; true"

    # PrestaShop has no .env mailer support: PS_MAIL_* live in ps_configuration (same as
    # the legacy config), pre-seeded by the installer's default configuration.xml.
    echo_info "Mail config..."
    local MAIL_SERVER="servidor.dplay.tv"
    local MAIL_PORT="465"
    local MAIL_ENCRYPTION="tls"
    local MAIL_SQL
    MAIL_SQL=$(cat <<EOF
UPDATE ps_configuration SET value='2' WHERE name='PS_MAIL_METHOD';
UPDATE ps_configuration SET value='${MAIL_SERVER}' WHERE name='PS_MAIL_SERVER';
UPDATE ps_configuration SET value='noreply@${DOMAIN}' WHERE name='PS_MAIL_USER';
UPDATE ps_configuration SET value='${EMAIL_PASS}' WHERE name='PS_MAIL_PASSWD';
UPDATE ps_configuration SET value='${MAIL_ENCRYPTION}' WHERE name='PS_MAIL_SMTP_ENCRYPTION';
UPDATE ps_configuration SET value='${MAIL_PORT}' WHERE name='PS_MAIL_SMTP_PORT';
EOF
)
    echo "$MAIL_SQL" | ssh "${ACCOUNT}@server" "MYSQL_PWD='${DB_PASS}' mysql -u '${ACCOUNT}_${DB_NAME}' '${ACCOUNT}_${DB_NAME}'" \
        || echo_error "Failed to configure outgoing email — check Preferences > Email in the admin manually."

    # Uses PrestaShop's own Mail::sendMailTest() (the same call the admin's Preferences >
    # Email "send test" button makes under the hood — that button itself needs a logged-in
    # admin session + CSRF token, so it can't be hit directly over SSH). The script is fully
    # static (no injected values) so it's safe to heredoc verbatim; real values go via argv.
    echo_info "Sending test email..."
    ssh "${ACCOUNT}@server" "cat > ~/$ROOT_DIR/_test_mail.php" <<'PHPEOF'
<?php
require_once __DIR__ . '/config/config.inc.php';
require_once __DIR__ . '/init.php';

[, $smtpServer, $to, $from, $smtpUser, $smtpPass, $smtpPort, $smtpEncryption] = $argv;

$result = Mail::sendMailTest(
    true,
    $smtpServer,
    'This is a test message. Your server is now configured to send email.',
    'Test message -- PrestaShop',
    'text/html',
    $to,
    $from,
    $smtpUser,
    $smtpPass,
    $smtpPort,
    $smtpEncryption
);

echo $result === true ? "OK\n" : ('FAIL: ' . $result . "\n");
PHPEOF
    run_remote "$ACCOUNT" "cd ~/$ROOT_DIR && $PHP_BIN _test_mail.php '$MAIL_SERVER' 'webmaster@redpost.pt' 'noreply@${DOMAIN}' 'noreply@${DOMAIN}' '${EMAIL_PASS}' '$MAIL_PORT' '$MAIL_ENCRYPTION'; rm -f _test_mail.php"

    echo
    echo_success "✅ PrestaShop $VERSION installed and ready at https://$DOMAIN"
    if [ -n "$ADMIN_DIR" ]; then
        echo "🔧 Backoffice: https://$DOMAIN/$ADMIN_DIR/"
    fi
    echo "👤 Admin: webmaster@redpost.pt"
    echo "🔑 Admin Password: $ADMIN_PASS"
    echo "🗄️ Database:"
    echo "User: ${ACCOUNT}_${DB_NAME}"
    echo "Pass: $DB_PASS"
    echo "📧 Email:"
    echo "noreply@$DOMAIN"
    echo "Pass: $EMAIL_PASS"
}



generate_secrets() {
    COMPOSER_FILE="composer.lock"
    current_dir=$(pwd)

    # Check if the current directory is inside /var/www
    if [[ ! "$current_dir" =~ ^/var/www ]]; then
        echo_error "Current directory is not inside /var/www. Please navigate to the correct directory."
        return 1
    fi

    # Initialize variables
    appName=""

    # Check if composer.json exists
    if [[ ! -f "$COMPOSER_FILE" ]]; then
        echo_info "This does not appear to be a valid Laravel or PrestaShop project."
        echo_info "$COMPOSER_FILE not found."
    else
        if grep -qi "prestashop" "$COMPOSER_FILE"; then
            appName="${BLUE_PRESTASHOP}󱇕 PrestaShop${NO_COLOR}" # Ensure colors are reset
        else
            echo "❌ $COMPOSER_FILE found, but no recognized 'prestashop' were found."
            return 1
        fi
    fi

    phpfile="genkeys.php"

    cat > "$phpfile" <<'EOF'
<?php
require_once __DIR__ . '/config/config.inc.php';
$_SERVER['REQUEST_METHOD'] = "POST";
require_once __DIR__ . '/init.php'; // optional if you need full init

$secret = Tools::passwdGen(64);
$cookie_key = Tools::passwdGen(64);
$cookie_iv = Tools::passwdGen(32);

$key = PhpEncryption::createNewRandomKey();
$privateKey = openssl_pkey_new([
    'private_key_bits' => 2048,
    'private_key_type' => OPENSSL_KEYTYPE_RSA,
]);
openssl_pkey_export($privateKey, $apiPrivateKey);
$apiPublicKey = openssl_pkey_get_details($privateKey)['key'];

$parameters = [
    'cookie_key' => $cookie_key,
    'cookie_iv' => $cookie_iv,
    'new_cookie_key' => $key,
    'secret' => $secret,
    'api_public_key' => $apiPublicKey,
    'api_private_key' => $apiPrivateKey,
];

foreach ($parameters as $key => $value) {
    echo "<p>" . $key . ": <pre>" . $value . "</pre></p>\n";
}

// load current parameters.php
$file = __DIR__ . '/app/config/parameters.php';
$config = include $file;

// replace with new values
foreach ($parameters as $k => $v) {
    $config['parameters'][$k] = $v;
}

// rebuild PHP file
$content = "<?php\nreturn " . var_export($config, true) . ";\n";

// overwrite file
file_put_contents($file, $content);

echo "parameters.php updated successfully\n";
EOF

    php "$phpfile"
    rm -f "$phpfile"

    echo -e "$BOLD$GREEN Permissions have been set.$RESET"
}

is_a_prestashop_project() {
    COMPOSER_FILE="composer.lock"

    if [[ ! -f "$COMPOSER_FILE" ]]; then
        echo "❌ This does not appear to be a valid Laravel or PrestaShop project."
        echo "File $COMPOSER_FILE not found."
        return 1
    fi

    if grep -qi "prestashop" "$COMPOSER_FILE"; then
        echo -e "$BOLD$BLUE_PRESTASHOP󱇕 PrestaShop$NO_COLOR$RESET"
        return 0
    else
        echo "❌ $COMPOSER_FILE found, but no recognized framework ('laravel', 'prestashop') was found."
        return 1
    fi
}

create_ps_module() {
    TEMPLATE_DIR="/var/www/templates/prestashop_module"

    # Check PrestaShop project
    if ! is_a_prestashop_project; then
        echo "Cannot create module: not inside a PrestaShop project."
        return 1
    fi

    # Check module name
    if [ -z "$1" ]; then
        echo "Usage: create_ps_module ModuleName"
        return 1
    fi

    MODULE_NAME=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    MODULE_NAME_CAPITALIZED=$(echo "$1" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
    MODULE_DIR="./modules/red_$MODULE_NAME"

    if [[ -d "$MODULE_DIR" ]]; then
        echo "❌ Module $MODULE_NAME already exists!"
        return 1
    fi

    # Copy template folder
    cp -r "$TEMPLATE_DIR" "$MODULE_DIR"

    # Recursively rename files/folders containing MODULE_NAME
    find "$MODULE_DIR" -depth -name "*MODULE_NAME_CAPITALIZED*" | while read file; do
        newfile=$(echo "$file" | sed "s/MODULE_NAME_CAPITALIZED/$MODULE_NAME_CAPITALIZED/g")
        mv "$file" "$newfile"
    done

    # Recursively rename files/folders containing MODULE_NAME
    find "$MODULE_DIR" -depth -name "*MODULE_NAME*" | while read file; do
        newfile=$(echo "$file" | sed "s/MODULE_NAME/$MODULE_NAME/g")
        mv "$file" "$newfile"
    done

    # Replace placeholders inside all files
    find "$MODULE_DIR" -type f -exec sed -i \
        -e "s/MODULE_NAME_CAPITALIZED/$MODULE_NAME_CAPITALIZED/g" \
        -e "s/MODULE_NAME/$MODULE_NAME/g" {} +

    echo "✅ Module $MODULE_NAME_CAPITALIZED created successfully in $MODULE_DIR"
}
