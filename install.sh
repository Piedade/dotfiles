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

source "./scripts/hyprland/install.sh"
sleep 1

source ./scripts/sddm.sh
sleep 1

source ./scripts/alacritty.sh
sleep 1

source ./scripts/thunar.sh
sleep 1

# system
# source ./scripts/dependencies.sh
# source ./scripts/github.sh
# source ./scripts/git_delta.sh
# source ./scripts/fonts.sh
# source ./scripts/starship.sh
source ./scripts/vscode.sh
source ./scripts/chrome.sh
# source ./scripts/tableplus.sh
# source ./scripts/beekeeperstudio.sh
# source ./scripts/anydesk.sh
# source ./scripts/lightdm.sh

# web
# source ./scripts/firewall.sh
# source ./scripts/apache.sh
# source ./scripts/mysql.sh
# source ./scripts/psql.sh
# source ./scripts/php.sh
# source ./scripts/phprc.sh
# source ./scripts/mkcert.sh
# source ./scripts/nvm.sh
# source ./scripts/composer.sh
# source ./scripts/mailpit.sh
# source ./scripts/obsidian.sh
# source ./scripts/dnsmasq.sh

# bash config
# source ./scripts/link_config.sh

"${SUDO_CMD}" systemctl reboot
