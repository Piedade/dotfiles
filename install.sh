#!/bin/bash

source ./scripts/utils.sh
source ./scripts/check_env.sh

# Define the log file path
LOG_FILE="$USER_HOME/install.log"

# Redirect both stdout and stderr to the log file and display in the terminal
exec > >(tee -a "$LOG_FILE") 2>&1

# system
source ./scripts/dependencies.sh
source ./scripts/github.sh
source ./scripts/fonts.sh
source ./scripts/starship.sh
source ./scripts/vscode.sh
source ./scripts/chrome.sh
source ./scripts/anydesk.sh
source ./scripts/lightdm.sh

# web
source ./scripts/firewall.sh
source ./scripts/apache.sh
source ./scripts/mysql.sh
source ./scripts/php.sh
source ./scripts/phprc.sh
source ./scripts/dnsmasq.sh
source ./scripts/mkcert.sh
source ./scripts/nvm.sh
source ./scripts/composer.sh

# bash config
source ./scripts/link_config.sh

"${SUDO_CMD}" apt modernize-sources -y
"${SUDO_CMD}" systemctl reboot
