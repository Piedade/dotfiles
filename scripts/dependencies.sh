#!/bin/bash

echo_info "Installing dependencies..."

# Update packages list and update system
"${SUDO_CMD}" apt-get update
"${SUDO_CMD}" apt-get upgrade -y

# Installing Essential Programs
"${SUDO_CMD}" apt-get install build-essential libxcb-util-dev numlockx feh rofi unzip wget pipewire pipewire-audio-client-libraries wireplumber pipewire-pulse pipewire-alsa pavucontrol libx11-dev libxft-dev libxinerama-dev libx11-xcb-dev libxcb-res0-dev pulseaudio-utils alsa-utils xdg-utils libimlib2-dev pkexec lxpolkit gnome-keyring libsecret-1-0 gvfs gvfs-backends gvfs-fuse thunar tumbler-plugins-extra xarchiver thunar-archive-plugin dunst arandr upower -y

# Installing Other less important Programs
"${SUDO_CMD}" apt-get install xbindkeys xdotool fzf jq libnotify-bin trash-cli flameshot psmisc neovim papirus-icon-theme lxappearance lightdm xclip bat multitail tree zoxide bash-completion ripgrep alacritty gimp inkscape gimp libreoffice fonts-liberation fonts-noto-color-emoji -y

# For flameshot screenshots
mkdir -p "$USER_HOME/Pictures"
# fix permissions
"${SUDO_CMD}" chown -R $USER:$USER "$USER_HOME/Pictures"

# Enable graphical login and change target from CLI to GUI
"${SUDO_CMD}" systemctl enable lightdm
"${SUDO_CMD}" systemctl set-default graphical.target

echo_success "Dependencies installed!"
