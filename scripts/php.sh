#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/utils.sh
source $SCRIPT_DIR/check_env.sh

installPHP(){
    local VERSION="$1"

    # if [ "$VERSION" == "7.2" ]; then
    #     # Install missing libicu72
    #     wget http://ftp.de.debian.org/debian/pool/main/i/icu/libicu72_72.1-3+deb12u1_amd64.deb
    #     "${SUDO_CMD}" dpkg -i libicu72_72.1-3_amd64.deb
    #     rm -f libicu72_72.1-3_amd64.deb
    # fi

    echo_info "Installing php${VERSION}..."

    EXTENSIONS=(
        mysql
        curl
        xml
        mbstring
        zip
        opcache
        gd
        intl
        apcu
        xdebug
        bcmath
        imagick
    )

    PACKAGES=(
        php${VERSION}
        php${VERSION}-common
        php${VERSION}-cli
        php${VERSION}-fpm
    )

    for EXT in "${EXTENSIONS[@]}"; do
        PACKAGES+=("php${VERSION}-${EXT}")
    done

    # ONE SINGLE APT CALL
    "${SUDO_CMD}" apt-get install -y "${PACKAGES[@]}"

    # Change fpm user and group
    "${SUDO_CMD}" sed -i "s/^user = .*/user = "${SUDO_USER:-$USER}"/" "/etc/php/${VERSION}/fpm/pool.d/www.conf"
    # "${SUDO_CMD}" systemctl start php${VERSION}-fpm

    # ${SUDO_CMD} sed -i "s/^user = .*/user = ${FPM_USER}/" "$CONF"
    # ${SUDO_CMD} sed -i "s/^group = .*/group = ${FPM_USER}/" "$CONF"
    # ${SUDO_CMD} sed -i "s/^listen.owner = .*/listen.owner = ${FPM_USER}/" "$CONF"
    # ${SUDO_CMD} sed -i "s/^listen.group = .*/listen.group = ${FPM_USER}/" "$CONF"
    # ${SUDO_CMD} sed -i "s/^listen.mode = .*/listen.mode = 0660/" "$CONF"

    echo_success "php${VERSION} installed!"
}

echo_info "Installing SURY repo..."

# For up-to-date version see: https://packages.sury.org/php/README.txt
# Make sure keyrings directory exists
"${SUDO_CMD}" mkdir -p /etc/apt/keyrings

# Download repo key into keyrings (not deprecated trusted.gpg.d)
"${SUDO_CMD}" wget -O /etc/apt/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg

# Create DEB822 sources file
cat <<EOF | ${SUDO_CMD} tee /etc/apt/sources.list.d/php-sury.sources > /dev/null
Types: deb
URIs: https://packages.sury.org/php/
Suites: $(lsb_release -sc)
Components: main
Signed-By: /etc/apt/keyrings/deb.sury.org-php.gpg
EOF

# Update package lists
"${SUDO_CMD}" apt-get update -y

echo_info "Installing FastCGI mod..."
# fcgid is a high performance alternative to mod_cgi that starts a sufficient number of instances of the CGI program to handle concurrent requests.
"${SUDO_CMD}" apt-get install libapache2-mod-fcgid -y

# installPHP "5.6"
installPHP "7.2"
sleep 1

installPHP "7.4"
sleep 1

installPHP "8.1"
sleep 1

installPHP "8.4"
sleep 1

# Select default PHP version
# update-alternatives --config php

# Select default PHP-fpm version
# update-alternatives --config php-fpm.sock

"${SUDO_CMD}" a2enmod actions fcgid alias proxy_fcgi rewrite ssl
