#!/bin/bash

LOG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install.log"
source ./scripts/check_env.sh

enable_log

# Ask if user wants to install backports kernel first
while true; do
    read -rp "Do you want to install the latest kernel from backports before proceeding? [y/n] " answer
    case "${answer,,}" in
        y) bash "$(dirname "${BASH_SOURCE[0]}")/backports.sh"
           echo_info "Resuming installation..."
           break ;;
        n) break ;;
        *) echo "Please answer y or n." ;;
    esac
done

sudo apt autoremove -y

sudo apt-get install pv -y
mkdir -p "${HOME}/Downloads"
mkdir -p "${HOME}/Screenshots"

source ./scripts/vim.sh
source ./scripts/lxpolkit.sh

# audio should be installed before hyprland because xdg-desktop-portal-hyprland
source ./scripts/audio.sh

# # não é necessario porque estamos a utilizar gnome-keyring
# source ./scripts/ssh-agent.sh

source ./scripts/sway.sh
source ./scripts/nwg-displays.sh
source ./scripts/nwg-look.sh
source ./scripts/swaync.sh
source ./scripts/satty.sh
source ./scripts/alacritty.sh
source ./scripts/thunar.sh
source ./scripts/fuzzel.sh
source ./scripts/wl-copy.sh
source ./scripts/swaybg.sh

# FONTS
source ./scripts/fonts.sh

source ./scripts/starship.sh
source ./scripts/vscode.sh
source ./scripts/chrome.sh
source ./scripts/beekeeperstudio.sh
source ./scripts/anydesk.sh

# web
source ./scripts/firewall.sh
source ./scripts/apache.sh
source ./scripts/mysql.sh
source ./scripts/psql.sh
source ./scripts/php.sh
source ./scripts/mkcert.sh
source ./scripts/nvm.sh
source ./scripts/composer.sh
source ./scripts/mailpit.sh

source ./scripts/obsidian.sh
source ./scripts/bruno.sh
source ./scripts/gimp.sh
source ./scripts/inkscape.sh
source ./scripts/libreoffice.sh
source ./scripts/galculator.sh
source ./scripts/direnv.sh
source ./scripts/dnsmasq.sh
source ./scripts/qemu.sh
source ./scripts/android.sh
source ./scripts/mouse.sh
source ./scripts/print.sh

source ./scripts/link_config.sh

sudo systemctl reboot
