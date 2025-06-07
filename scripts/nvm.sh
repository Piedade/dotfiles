#!/bin/bash

echo_info "Installing nvm..."
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/refs/heads/master/install.sh | bash

export NVM_DIR="$USER_HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

echo $NVM_DIR

nvm install --lts

# Angular CLI
echo_info "Installing Angular CLI..."
npm install -g @angular/cli@latest
