#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing MySQL from APT Repository..."

if command_exists mysql; then
    echo_success "MySQL already installed!"
    return
fi

# # dependency
# wget -q https://ftp.debian.org/debian/pool/main/liba/libaio/libaio1_0.3.113-4_amd64.deb
# sudo dpkg -i libaio1_0.3.113-4_amd64.deb

APT_CONFIG_FILE="mysql-apt-config_0.8.39-1_all.deb"

wget "https://dev.mysql.com/get/$APT_CONFIG_FILE" \
    || { echo_error "Failed to download mysql-apt-config"; return 1; }

# default to mysql lts version, skip all interactive prompts
echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.4-lts" | sudo debconf-set-selections
echo "mysql-apt-config mysql-apt-config/select-connectors select Disabled" | sudo debconf-set-selections
echo "mysql-apt-config mysql-apt-config/select-product select Ok" | sudo debconf-set-selections

disable_log
sudo DEBIAN_FRONTEND=noninteractive dpkg -i "$APT_CONFIG_FILE"
enable_log

# update package list and install
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install mysql-server -y

# enable mysql_native_password plugin
# echo "mysql_native_password=ON" | sudo tee -a /etc/mysql/mysql.conf.d/mysqld.cnf
sudo tee /etc/mysql/conf.d/native-password.cnf >/dev/null <<'EOF'
[mysqld]
mysql_native_password=ON
EOF

sudo systemctl restart mysql

# root password
sudo mysql <<-EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'admin';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
UPDATE mysql.user SET Host='localhost' WHERE User='root' AND Host!='localhost';
FLUSH PRIVILEGES;
EOF

# Add arch=amd64 to fix N: Skipping acquire of configured file 'main/binary-i386/Packages'
sudo sed -i 's/\[signed-by=/[arch=amd64 signed-by=/g' /etc/apt/sources.list.d/mysql.list

# clean
rm -f "${HOME}/.dotfiles/${APT_CONFIG_FILE}"
# rm -f libaio1_0.3.113-4_amd64.deb
