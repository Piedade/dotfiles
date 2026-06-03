echo_info "Installing Polkit Agent..."

if command_exists lxpolkit; then
    echo_success "Polkit Agent already installed!"
    return
fi

sudo apt-get install -y polkitd lxpolkit gnome-keyring # libsecret-1-0

echo_success "Polkit installed!"
