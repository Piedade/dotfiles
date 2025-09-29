#!/bin/bash

LOG_FILE="../install.log"

source ./scripts/utils.sh
source ./scripts/check_env.sh

enable_log

# system
source ./scripts/dependencies.sh
source ./scripts/github.sh
source ./scripts/git_delta.sh
source ./scripts/fonts.sh
source ./scripts/starship.sh
source ./scripts/vscode.sh
source ./scripts/chrome.sh
source ./scripts/tableplus.sh
source ./scripts/beekeeperstudio.sh
source ./scripts/anydesk.sh
source ./scripts/lightdm.sh

# web
source ./scripts/firewall.sh
source ./scripts/apache.sh
source ./scripts/mysql.sh
source ./scripts/psql.sh
source ./scripts/php.sh
source ./scripts/phprc.sh
source ./scripts/mkcert.sh
source ./scripts/nvm.sh
source ./scripts/composer.sh
source ./scripts/mailpit.sh
source ./scripts/obsidian.sh
source ./scripts/dnsmasq.sh

# bash config
source ./scripts/link_config.sh

"${SUDO_CMD}" apt modernize-sources -y
"${SUDO_CMD}" systemctl reboot
