#!/bin/bash

echo_info "Installing nvm..."
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/refs/heads/master/install.sh | bash

source $USER_HOME/.bashrc
nvm install --lts

# Angular CLI
echo_info "Installing Angular CLI..."
npm install -g @angular/cli@latest
