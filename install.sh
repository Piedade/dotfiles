#!/bin/bash

LOG_FILE="../install.log"

source ./scripts/utils.sh
source ./scripts/check_env.sh

enable_log

sudo apt autoremove -y

sudo apt-get install pv
mkdir -p "${HOME}/Downloads"
mkdir -p "${HOME}/Screenshots"

source ./scripts/vim.sh
sleep 1

source "./scripts/lxpolkit.sh"
sleep 1

# audio should be installed before hyprland because xdg-desktop-portal-hyprland
source ./scripts/audio.sh
sleep 1

# # não é necessario porque estamos a utilizar gnome-keyring
# source "./scripts/ssh-agent.sh"

source "./scripts/sway.sh"
sleep 1

source ./scripts/nwg-displays.sh
sleep 1

source ./scripts/nwg-look.sh
sleep 1

source ./scripts/swaync.sh
sleep 1

source ./scripts/satty.sh
sleep 1

source ./scripts/alacritty.sh
sleep 1

source ./scripts/thunar.sh
sleep 1

# source ./scripts/rofi.sh
source ./scripts/fuzzel.sh
sleep 1

source ./scripts/wl-copy.sh
sleep 1

source ./scripts/swaybg.sh
sleep 1

# source ./scripts/github.sh
# source ./scripts/git-delta.sh
# sleep 1

# FONTS
source ./scripts/fonts.sh
sleep 1

source ./scripts/starship.sh
sleep 1

source ./scripts/vscode.sh
sleep 1

source ./scripts/chrome.sh
sleep 1

source ./scripts/tableplus.sh
sleep 1

source ./scripts/beekeeperstudio.sh
sleep 1

source ./scripts/anydesk.sh
sleep 1

# web
source ./scripts/firewall.sh
sleep 1

source ./scripts/apache.sh
sleep 1

source ./scripts/mysql.sh
sleep 1

source ./scripts/psql.sh
sleep 1

source ./scripts/php.sh
sleep 1

source ./scripts/mkcert.sh
sleep 1

source ./scripts/nvm.sh
sleep 1

source ./scripts/composer.sh
sleep 1

source ./scripts/mailpit.sh
sleep 1

source ./scripts/obsidian.sh
sleep 1

source ./scripts/bruno.sh
sleep 1

source ./scripts/gimp.sh
sleep 1

source ./scripts/inkscape.sh
sleep 1

source ./scripts/libreoffice.sh
sleep 1

source ./scripts/galculator.sh
sleep 1

source ./scripts/direnv.sh
sleep 1

source ./scripts/dnsmasq.sh
sleep 1

source ./scripts/qemu.sh
sleep 1

source ./scripts/android.sh
sleep 1

source ./scripts/mouse.sh
sleep 1

source ./scripts/print.sh
sleep 1

source ./scripts/link_config.sh
sleep 1

"${SUDO_CMD}" systemctl reboot
