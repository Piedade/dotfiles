#!/bin/bash

echo_info "Installing MySQL from APT Repository..."

# dependency
wget -q https://ftp.debian.org/debian/pool/main/liba/libaio/libaio1_0.3.113-4_amd64.deb
"${SUDO_CMD}" dpkg -i libaio1_0.3.113-4_amd64.deb

APT_CONFIG_FILE="mysql-apt-config_0.8.34-1_all.deb"

wget "https://dev.mysql.com/get/$APT_CONFIG_FILE"

# default to mysql lts version
# echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.4-lts" | "${SUDO_CMD}" debconf-set-selections

disable_log
"${SUDO_CMD}" dpkg -i "$APT_CONFIG_FILE"
enable_log

# update package list and install
"${SUDO_CMD}" apt-get update -y
"${SUDO_CMD}" DEBIAN_FRONTEND=noninteractive apt-get install mysql-server -y

# root password
"${SUDO_CMD}" mysql --user=root <<-EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY 'admin';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
UPDATE mysql.user SET Host='localhost' WHERE User='root' AND Host!='localhost';
FLUSH PRIVILEGES;
EOF

# clean
rm -f "$APT_CONFIG_FILE"
rm -f libaio1_0.3.113-4_amd64.deb
