create_prestashop() {
    DOMAIN="$1"
    ZIP_SOURCE="$2"

    if [ -z "$DOMAIN" ]; then
        echo "Usage: create_prestashop <domain>"
        return 1
    fi

    echo "🌐 Installing PrestaShop for domain: $DOMAIN"

    TMP_DIR="/tmp/prestashop_install"
    ZIP_FILE="$TMP_DIR/prestashop.zip"
    PS_DIR="/var/www/$DOMAIN"

    # Config - adjust these as needed or add parameters
    DB_NAME="prestashop"
    DB_USER="root"
    DB_PASS="admin"
    DB_HOST="127.0.0.1"
    SHOP_NAME="My Shop"
    ADMIN_FIRSTNAME="Admin"
    ADMIN_LASTNAME="User"
    ADMIN_EMAIL="admin@$DOMAIN"
    ADMIN_PASS="admin123"
    LANGUAGE="pt"
    COUNTRY="pt"
    DOMAIN_URL="$DOMAIN"

    create_domain "$DOMAIN"

    mkdir -p "$TMP_DIR"

    if [ -n "$ZIP_SOURCE" ] && [ -f "$ZIP_SOURCE" ]; then
        echo_info "📦 Using local PrestaShop ZIP: $ZIP_SOURCE"
        cp "$ZIP_SOURCE" "$ZIP_FILE"
    else
        echo_info "⬇️  Downloading latest PrestaShop..."
        LATEST_URL=$(curl -s https://api.github.com/repos/PrestaShop/PrestaShop/releases/latest | jq -r '.assets[] | select(.name | test("zip$")) | .browser_download_url')

        if [ -z "$LATEST_URL" ]; then
            echo "❌ Failed to get download URL."
            return 1
        fi

        curl -# -L "$LATEST_URL" -o "$ZIP_FILE"
    fi

    echo "📦 Extracting files..."
    ZIP_SIZE=$(stat -c %s "$ZIP_FILE")
    mkdir -p "$TMP_DIR/unpacked"
    pv -s "$ZIP_SIZE" "$ZIP_FILE" | bsdtar -xf - -C "$TMP_DIR/unpacked"

    echo "📁 Moving PrestaShop files to $PS_DIR..."
    ZIP_FILE=$(find "$TMP_DIR/unpacked" -maxdepth 1 -type f -iname "prestashop*.zip" | head -n1)
    if [ -z "$ZIP_FILE" ] || [ ! -f "$ZIP_FILE" ]; then
        echo "❌ Expected internal PrestaShop ZIP file not found!"
        return 1
    fi
    ZIP_SIZE=$(stat -c %s "$ZIP_FILE")
    mkdir -p "$TMP_DIR/unpacked"
    pv -s "$ZIP_SIZE" "$ZIP_FILE" | bsdtar -xf - -C "$PS_DIR"

    # Change to PrestaShop directory before fixing permissions and running installer
    cd "$PS_DIR" || return 1

    echo_info "📝 Creating composer.json..."
    tee composer.json > /dev/null <<'EOF'
{
    "$schema": "https://getcomposer.org/schema.json",
    "name": "red/lenamotos",
    "type": "project",
    "description": "",
    "keywords": [
        "prestashop"
    ],
    "config": {
        "platform": {
            "php": "8.1"
        }
    },
    "license": "MIT",
    "require": {
        "php": "^8.1"
    },
    "scripts": {
        "dev": [
            "Composer\\Config::disableProcessTimeout",
            "npx concurrently -c \"#fdba74\" \"cd themes/lenamotos && npm run dev\" --names=vite"
        ]
    },
    "minimum-stability": "stable",
    "prefer-stable": true
}
EOF

    echo "🔐 Fixing permissions with your custom function..."
    fix_permissions

    echo "🚀 Running PrestaShop CLI installer..."
    cd install || { echo "❌ install directory missing"; return 1; }

    php index_cli.php \
        --language="$LANGUAGE" \
        --country="$COUNTRY" \
        --domain="$DOMAIN_URL" \
        --db_server="$DB_HOST" \
        --db_name="$DB_NAME" \
        --db_user="$DB_USER" \
        --db_password="$DB_PASS" \
        --db_create="1" \
        --ssl="1" \
        --fixtures="1" \
        --name="$SHOP_NAME" \
        --email="$ADMIN_EMAIL" \
        --password="$ADMIN_PASS" \
        --firstname="$ADMIN_FIRSTNAME" \
        --lastname="$ADMIN_LASTNAME" \
        --newsletter=0 \
        --send_email=0

    echo "🧹 Cleaning up temporary files and install folder..."
    cd "$PS_DIR" || return 1
    rm -rf install "$TMP_DIR" "$ZIP_FILE"

    echo "✅ PrestaShop installed and ready at https://$DOMAIN"
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
