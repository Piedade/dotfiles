#!/bin/bash

# Ctrl + L is enough (write something then run it)
# # Bind Ctrl+k to clear terminal
# bind '"\C-k": "\C-e\C-u clear\n"'

# SHOW
echo_error() {
    local message="${1:-Error}"
    echo -e "${BOLD}${RED} ${message}${RESET}"
}
export -f echo_error

echo_success() {
    local message="${1:-Success}"
    echo -e "${BOLD}${GREEN}${message}${RESET}"
}
export -f echo_success

echo_info() {
    local message="${1:-Info}"
    echo -e "${BOLD}${YELLOW}${message}${RESET}"
}
export -f echo_info

# Function to check and display file or directory permissions
check_permission() {
    if [ -z "$1" ]; then
        echo "Usage: permission <file_or_directory>"
        return 1
    fi

    if [ ! -e "$1" ]; then
        echo_info "File or directory does not exist: $1"
        return 1
    fi

    stat -c "%a %n" "$1"
}

gen_pass() {
  openssl rand -base64 18 | tr -dc 'A-Za-z0-9!@#$%^&*()_+=' | head -c 20
}

run_remote() {
  local CMD="$1"
  ssh "$ACCOUNT@server" "$CMD"
  local STATUS=$?
  if [ $STATUS -ne 0 ]; then
        echo_error "Command failed: $CMD (Exit status: $STATUS)"
        read -r  # mantém terminal aberto
        exit $STATUS
  fi
}

select_account() {
    local account
    account=$(ssh root@server "cut -d: -f1 /etc/trueuserowners" | fzf --prompt="Select account: ")
    [[ -z "$account" ]] && return 1
    echo "$account"
}

# select_email() {
#     local account=$1
#     local domain
#     domain=$(ssh "$SERVER" "grep '^DNS=' /var/cpanel/users/$account | cut -d= -f2")
#     [[ -z "$domain" ]] && { echo "Domain not found for $account"; return 1; }

#     local options=("info@$domain" "geral@$domain" "support@$domain" "admin@$domain")
#     local email
#     email=$(printf "%s\n" "${options[@]}" | fzf --prompt="Select email: ")
#     [[ -z "$email" ]] && return 1
#     echo "$email"
# }
