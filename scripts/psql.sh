#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing PostgreSQL..."

if command_exists psql; then
    echo_success "PostgreSQL already installed!"
    return
fi

sudo apt-get install -y postgresql

sudo su - postgres -c "createuser ${SUDO_USER:-$USER} --superuser" 2>/dev/null || true


# TODO: Create script to install
# # Python 3.11 para o odoo v17

# # odoo deps
# sudo apt install libpq-dev libldap2-dev libsasl2-dev

# sudo apt update
# sudo apt install -y \
#   build-essential \
#   libssl-dev zlib1g-dev libbz2-dev \
#   libreadline-dev libsqlite3-dev wget curl llvm \
#   libncurses5-dev libncursesw5-dev xz-utils tk-dev \
#   libffi-dev liblzma-dev git

# cd /usr/src
# sudo wget https://www.python.org/ftp/python/3.11.15/Python-3.11.15.tgz
# sudo tar xvf Python-3.11.15.tgz
# cd Python-3.11.15
# sudo ./configure --enable-optimizations
# sudo make altinstall

######
# # Python 3.7 para o odoo v12
# sudo apt update
# sudo apt install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev

# # Baixar e compilar o Python 3.7.17
# cd /usr/src
# sudo wget https://www.python.org/ftp/python/3.7.17/Python-3.7.17.tgz
# sudo tar xvf Python-3.7.17.tgz
# cd Python-3.7.17
# sudo ./configure --enable-optimizations
# sudo make altinstall
