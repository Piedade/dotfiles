echo_info "Installing Polkit Agent..."

"${SUDO_CMD}" apt-get install -y polkitd pkexec lxpolkit gnome-keyring libsecret-1-0

echo_success "Polkit installed!"
