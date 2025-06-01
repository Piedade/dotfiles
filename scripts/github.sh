#!/bin/bash

echo_info "Installing GitHub CLI..."

(type -p wget >/dev/null || ("${SUDO_CMD}" apt update && "${SUDO_CMD}" apt-get install wget -y)) \
&& "${SUDO_CMD}" mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat $out | "${SUDO_CMD}" tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
&& "${SUDO_CMD}" chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | "${SUDO_CMD}" tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
&& "${SUDO_CMD}" apt update \
&& "${SUDO_CMD}" apt install gh -y

echo_success "GitHub CLI installed!"
