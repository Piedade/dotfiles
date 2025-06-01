#!/bin/bash

echo_info "Installing php..."

# Add the SURY repository key
"${SUDO_CMD}" wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg > /dev/null

# Add the SURY repository
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | "${SUDO_CMD}" tee /etc/apt/sources.list.d/php.list

"${SUDO_CMD}" apt-get update -y

echo_info "Installing FastCGI mod..."
# fcgid is a high performance alternative to mod_cgi that starts a sufficient number of instances of the CGI program to handle concurrent requests.
"${SUDO_CMD}" apt-get install libapache2-mod-fcgid -y

## PHP 7.2
echo_info "Installing php 7.2..."

# Install missing libicu72
wget http://ftp.de.debian.org/debian/pool/main/i/icu/libicu72_72.1-3_amd64.deb
"${SUDO_CMD}" dpkg -i libicu72_72.1-3_amd64.deb

"${SUDO_CMD}" apt-get install php7.2 php7.2-fpm php7.2-mysql php7.2-common php7.2-curl php7.2-xml php7.2-mbstring php7.2-zip php7.2-opcache php7.2-gd php7.2-intl php7.2-apcu php7.2-xdebug libapache2-mod-php7.2 php7.2-json -y
# Change fpm user and group
"${SUDO_CMD}" sed -i "s/^user = .*/user = "${SUDO_USER:-$USER}"/" "/etc/php/7.2/fpm/pool.d/www.conf"
"${SUDO_CMD}" systemctl restart php7.2-fpm

# clean php7.2
rm -f libicu72_72.1-3_amd64.deb

## PHP 7.4
echo_info "Installing php 7.4..."
"${SUDO_CMD}" apt-get install php7.4 php7.4-fpm php7.4-mysql php7.4-common php7.4-curl php7.4-xml php7.4-mbstring php7.4-zip php7.4-opcache php7.4-gd php7.4-intl php7.4-apcu php7.4-xdebug libapache2-mod-php7.4 php7.4-json -y
# Change fpm user and group
"${SUDO_CMD}" sed -i "s/^user = .*/user = "${SUDO_USER:-$USER}"/" "/etc/php/7.4/fpm/pool.d/www.conf"
"${SUDO_CMD}" systemctl restart php7.4-fpm

## PHP 8.4
echo_info "Installing php 8.4..."
"${SUDO_CMD}" apt-get install php8.4 php8.4-fpm php8.4-mysql php8.4-common php8.4-curl php8.4-xml php8.4-mbstring php8.4-zip php8.4-opcache php8.4-gd php8.4-intl php8.4-apcu php8.4-xdebug libapache2-mod-php8.4 -y
# Change fpm user and group
"${SUDO_CMD}" sed -i "s/^user = .*/user = "${SUDO_USER:-$USER}"/" "/etc/php/8.4/fpm/pool.d/www.conf"
"${SUDO_CMD}" systemctl restart php8.4-fpm

# Select default PHP version
# update-alternatives --config php

# Select default PHP-fpm version
# update-alternatives --config php-fpm.sock

"${SUDO_CMD}" a2enmod actions fcgid alias proxy_fcgi rewrite ssl

