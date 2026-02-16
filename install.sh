#!/bin/bash

LOG_FILE="../install.log"

source ./scripts/utils.sh
source ./scripts/check_env.sh

enable_log

source ./scripts/vim.sh
sleep 1

# audio should be installed before hyprland because xdg-desktop-portal-hyprland
source ./scripts/audio.sh
sleep 1

# for hyprpolkitagent
sudo apt-get install -y polkitd pkexec

source "./scripts/hyprland/install.sh"
sleep 1

source ./scripts/sddm.sh
sleep 1

source ./scripts/alacritty.sh
sleep 1

source ./scripts/thunar.sh
sleep 1

source ./scripts/rofi.sh
sleep 1

source ./scripts/wl-copy.sh
sleep 1

source ./scripts/swaybg.sh
sleep 1

# system
# source ./scripts/dependencies.sh
# source ./scripts/github.sh
source ./scripts/git-delta.sh
sleep 1

source ./scripts/fonts.sh
sleep 1

source ./scripts/starship.sh
sleep 1

source ./scripts/vscode.sh
sleep 1

source ./scripts/chrome.sh
sleep 1

# source ./scripts/tableplus.sh
source ./scripts/beekeeperstudio.sh
sleep 1

source ./scripts/anydesk.sh
sleep 1

# source ./scripts/lightdm.sh

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

source ./scripts/gimp.sh
sleep 1

source ./scripts/inkscape.sh
sleep 1

source ./scripts/libreoffice.sh
sleep 1

source ./scripts/direnv.sh
sleep 1

source ./scripts/dnsmasq.sh
sleep 1

source ./scripts/link_config.sh
sleep 1

"${SUDO_CMD}" systemctl reboot
