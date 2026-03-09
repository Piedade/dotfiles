#!/bin/bash

echo_info "Installing PostgreSQL..."

"${SUDO_CMD}" apt-get install -y postgresql

"${SUDO_CMD}" su - postgres -c "createuser piedade --superuser"

# Python 3.11 para o odoo v17

# odoo deps
sudo apt install libpq-dev libldap2-dev libsasl2-dev

sudo apt update
sudo apt install -y \
  build-essential \
  libssl-dev zlib1g-dev libbz2-dev \
  libreadline-dev libsqlite3-dev wget curl llvm \
  libncurses5-dev libncursesw5-dev xz-utils tk-dev \
  libffi-dev liblzma-dev git

cd /usr/src
sudo wget https://www.python.org/ftp/python/3.11.14/Python-3.11.14.tgz
sudo tar xvf Python-3.11.14.tgz
cd Python-3.11.14
sudo ./configure --enable-optimizations
sudo make altinstall
