#!/bin/bash

RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'

# add variables to top level so can easily be accessed by all functions
SUDO_CMD=""
SUGROUP=""
GITPATH=""

## Get the correct user home directory.
USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

checkEnv() {
    ## Check for requirements.
    REQUIREMENTS='curl groups sudo'
    for req in $REQUIREMENTS; do
        if ! command_exists "$req"; then
            echo "${RED}To run me, you need: $REQUIREMENTS${RC}"
            exit 1
        fi
    done

    SUDO_CMD="sudo"

    echo "Using $SUDO_CMD as privilege escalation software"

    ## Check if the current directory is writable.
    GITPATH=$(dirname "$(realpath "$0")")
    if [ ! -w "$GITPATH" ]; then
        echo "${RED}Can't write to $GITPATH${RC}"
        exit 1
    fi

    ## Check SuperUser Group

    SUPERUSERGROUP='wheel sudo root'
    for sug in $SUPERUSERGROUP; do
        if groups | grep -q "$sug"; then
            SUGROUP="$sug"
            echo "Super user group $SUGROUP"
            break
        fi
    done

    ## Check if member of the sudo group.
    if ! groups | grep -q "$SUGROUP"; then
        echo "${RED}You need to be a member of the sudo group to run me!${RC}"
        exit 1
    fi
}

installFirewall() {
    printf "${YELLOW}Installing firewall...${RC}"
    "${SUDO_CMD}" apt install -y ufw

    printf "%b\n" "${YELLOW}Allowing incoming HTTP and HTTPS${RC}"
    "${SUDO_CMD}" ufw allow in "WWW Full"

    "${SUDO_CMD}" ufw enable
}


installApache() {
    echo "${YELLOW}Installing apache2...${RC}"

    "${SUDO_CMD}" apt install apache2

    echo -e "\n\nServerName localhost" | "${SUDO_CMD}" tee -a "/etc/apache2/apache2.conf" > /dev/null

    # Change apache user and group
    "${SUDO_CMD}" sed -i "s/^export APACHE_RUN_USER=.*/export APACHE_RUN_USER="${SUDO_USER:-$USER}"/" "/etc/apache2/envvars"
    "${SUDO_CMD}" sed -i "s/^export APACHE_RUN_GROUP=.*/export APACHE_RUN_GROUP="${SUDO_USER:-$USER}"/" "/etc/apache2/envvars"
    "${SUDO_CMD}" systemctl restart apache2

    # FIX permissions
    "${SUDO_CMD}" chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} /var/www
    "${SUDO_CMD}" find /var/www -type d -exec chmod 2755 {} \+
    "${SUDO_CMD}" find /var/www -type f -exec chmod 644 {} \+
}


installMySQL() {
    APT_CONFIG_FILE="mysql-apt-config_0.8.33-1_all.deb"

    echo "${YELLOW}Installing MySQL from APT Repository...${RC}"
    wget "$APT_CONFIG_FILE"

    # non interactive
    # "${SUDO_CMD}" debconf-set-selections <<< "mysql-apt-config mysql-apt-config/select-server select mysql-5.8"
    # "${SUDO_CMD}" debconf-set-selections <<< "mysql-apt-config mysql-apt-config/select-product select Ok"
    "${SUDO_CMD}" dpkg -i "$APT_CONFIG_FILE"

    "${SUDO_CMD}" apt-get update
    "${SUDO_CMD}" apt-get install mysql-server

    rm -f "$APT_CONFIG_FILE"
}


installPHP() {
    echo "${YELLOW}Installing php...${RC}"

    # Add the SURY repository key
    "${SUDO_CMD}" wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg > /dev/null

    # Add the SURY repository
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | "${SUDO_CMD}" tee /etc/apt/sources.list.d/php.list

    "${SUDO_CMD}" apt-get update

    echo "${YELLOW}Installing FastCGI mod...${RC}"
    # fcgid is a high performance alternative to mod_cgi that starts a sufficient number of instances of the CGI program to handle concurrent requests.
    "${SUDO_CMD}" apt-get install libapache2-mod-fcgid

    echo "${YELLOW}Installing php 7.4...${RC}"
    "${SUDO_CMD}" apt-get install php7.4 php7.4-fpm php7.4-mysql php7.4-common php7.4-curl php7.4-xml php7.4-mbstring php7.4-zip php7.4-opcache php7.4-gd php7.4-intl php7.4-apcu php7.4-xdebug libapache2-mod-php7.4 php7.4-json -y
    # Change fpm user and group
    "${SUDO_CMD}" sed -i "s/^user = .*/user = "${SUDO_USER:-$USER}"/" "/etc/php/7.4/fpm/pool.d/www.conf"
    "${SUDO_CMD}" sed -i "s/^group = .*/group = "${SUDO_USER:-$USER}"/" "/etc/php/7.4/fpm/pool.d/www.conf"
    "${SUDO_CMD}" systemctl restart php7.4-fpm

    echo "${YELLOW}Installing php 8.4...${RC}"
    "${SUDO_CMD}" apt-get install php8.4 php8.4-fpm php8.4-mysql php8.4-common php8.4-curl php8.4-xml php8.4-mbstring php8.4-zip php8.4-opcache php8.4-gd php8.4-intl php8.4-apcu php8.4-xdebug libapache2-mod-php8.4 -y
    # Change fpm user and group
    "${SUDO_CMD}" sed -i "s/^user = .*/user = "${SUDO_USER:-$USER}"/" "/etc/php/8.4/fpm/pool.d/www.conf"
    "${SUDO_CMD}" sed -i "s/^group = .*/group = "${SUDO_USER:-$USER}"/" "/etc/php/8.4/fpm/pool.d/www.conf"
    "${SUDO_CMD}" systemctl restart php8.4-fpm

    # Select default PHP version
    # update-alternatives --config php

    # Select default PHP-fpm version
    # update-alternatives --config php-fpm.sock

    "${SUDO_CMD}" a2enmod actions fcgid alias proxy_fcgi
}

installDNSmasq() {
    # Automatically handle wildcard *.test names and forward all of them to localhost (127.0.0.1).
    # https://community.zextras.com/how-to-install-your-dns-server-using-dnsmasq/
    echo "${YELLOW}Installing dnsmasq...${RC}"

    "${SUDO_CMD}" apt-get install dnsmasq

    DNSMASQCONF="/etc/dnsmasq.conf";
    RESOLVCONF="/etc/resolv.conf";

    if ! "${SUDO_CMD}" mv "$DNSMASQCONF" "$DNSMASQCONF".bak; then
        echo "${RED}Can't move the old dnsmasq.conf file!${RC}"
        exit 1
    fi

    # upstream DNS server for non-local domain names, using Cloudflare and google public DNS
    # add .test to resolve to your local machine
    echo -e "server=1.1.1.1\nserver=8.8.8.8\n\naddress=/.test/127.0.0.1" | sudo tee -a "$DNSMASQCONF" > /dev/null

    if ! "${SUDO_CMD}" mv "$RESOLVCONF" "$RESOLVCONF".bak; then
        echo "${RED}Can't move the old resolv.conf file!${RC}"
        exit 1
    fi

    echo -e "nameserver 127.0.0.1" | sudo tee -a "$RESOLVCONF" > /dev/null

    # Change the file’s attributes using the chattr command to make our file immutable.
    # This prevents the local network manager from overwriting our changes:
    sudo chattr +i /etc/resolv.conf
}

installDNSmasq() {
    echo "${YELLOW}Installing mkcert...${RC}"
    "${SUDO_CMD}" apt-get install libnss3-tools mkcert
    mkcert -install
}

installNVM() {
    echo "${YELLOW}Installing nvm...${RC}"
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    nvm install --lts
}

installComposer() {
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
    php composer-setup.php
    php -r "unlink('composer-setup.php');"

    "${SUDO_CMD}" mv composer.phar /usr/local/bin/composer
}

checkEnv

installFirewall
installApache
installMySQL
installPHP
installDNSmasq
installNVM
installComposer

