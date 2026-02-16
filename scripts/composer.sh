#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/utils.sh
source $SCRIPT_DIR/check_env.sh

echo_info "Installing composer ..."

php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"

echo "Fetching expected signature..."
EXPECTED_HASH="$(wget -q -O - https://composer.github.io/installer.sig)"

echo "Calculating actual signature..."
ACTUAL_HASH="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    echo_error "ERROR: Invalid installer signature"
    echo_error "Expected: $EXPECTED_HASH"
    echo_error "Actual  : $ACTUAL_HASH"
    rm composer-setup.php
    exit 1
fi

php composer-setup.php --quiet
rm composer-setup.php

${SUDO_CMD} mv composer.phar /usr/local/bin/composer
${SUDO_CMD} chmod +x /usr/local/bin/composer

echo_success "Composer installed successfully."

