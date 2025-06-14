#!/bin/bash

echo_info "Installing Git delta..."

wget https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_amd64.deb
"${SUDO_CMD}" apt-get install ./git-delta_0.18.2_amd64.deb

"${SUDO_CMD}" rm -f git-delta_0.18.2_amd64.deb

echo_success "Git delta installed!"
