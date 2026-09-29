#!/bin/bash

check_shell_access() {
    if [ -z "$1" ]; then
       echo_error "No user account defined!"
       return 1
    fi

    local ACCOUNT="$1"
    if [[ ! "$ACCOUNT" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo_error "Invalid account name: '$ACCOUNT'"
        return 1
    fi

    local entry
    entry=$(ssh root@server "getent passwd $ACCOUNT" 2>/dev/null || true)

    if [[ -z "$entry" ]]; then
        return 2 # user not found
    fi

    local shell
    shell=$(printf '%s' "$entry" | cut -d: -f7)
    case "$shell" in
    */bin/bash|*/bin/sh|*/usr/bin/bash)
        if [ -z "$2" ]; then
            echo_success "$ACCOUNT has shell access."
        fi
        return 0
        ;;
    */noshell|*/usr/local/cpanel/bin/noshell|*/sbin/nologin|*/bin/false)
        echo_error "no shell access."
        return 1
        ;;
    *)
        echo_info "$ACCOUNT has an unusual shell: $shell"
        return 3
        ;;
    esac
}

add_shell_access() {
    if [ -z "$1" ]; then
       echo_error "No user account defined!"
       return 1
    fi

    local ACCOUNT="$1"
    if [[ ! "$ACCOUNT" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo_error "Invalid account name: '$ACCOUNT'"
        return 1
    fi

    ssh root@server "usermod -s /bin/bash $ACCOUNT"
    echo_success "Shell Access activated for $ACCOUNT."
}


remove_shell_access() {
    if [ -z "$1" ]; then
       echo_error "No user account defined!"
       return 1
    fi

    local ACCOUNT="$1"
    if [[ ! "$ACCOUNT" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo_error "Invalid account name: '$ACCOUNT'"
        return 1
    fi

    ssh root@server "usermod -s /usr/local/cpanel/bin/noshell $ACCOUNT"
    echo_error "$ACCOUNT no longer has shell access."
}

# Verifies a set of PHP extensions are loaded for a given account/PHP binary before doing
# expensive work (build/upload/install) that would otherwise fail deep inside the app's own
# installer. Usage: check_php_extensions <account> <php_bin> ext1 ext2 ...
check_php_extensions() {
    local ACCOUNT="$1"
    local PHP_BIN="$2"
    shift 2
    local REQUIRED=("$@")

    local LOADED
    LOADED=$(ssh "${ACCOUNT}@server" "$PHP_BIN -m" 2>/dev/null)

    if [ -z "$LOADED" ]; then
        echo_error "Could not list PHP modules for $ACCOUNT (ssh/php failed)."
        return 1
    fi

    local MISSING=()
    local ext
    for ext in "${REQUIRED[@]}"; do
        grep -qix "$ext" <<< "$LOADED" || MISSING+=("$ext")
    done

    if [ ${#MISSING[@]} -eq 0 ]; then
        return 0
    fi

    echo_error "Missing PHP extensions for $ACCOUNT: ${MISSING[*]}"

    # Deriva a versão dotted (ex.: 8.4) do binário, para usar no PHP Selector do
    # CloudLinux via selectorctl --enable-user-extensions — o mesmo mecanismo por
    # trás do Multi-PHP Manager/PHP Selector no cPanel (ativar extensão em modo UI
    # dentro da conta), em vez de instalar pacotes ao nível do SO.
    local PHP_VER_NUM PHP_VER_DOTTED
    PHP_VER_NUM=$(grep -oP 'php\K[0-9]{2}' <<< "$PHP_BIN" | head -n1)
    if [ -z "$PHP_VER_NUM" ]; then
        echo_error "Enable them via the PHP Selector (Multi-PHP Manager) in cPanel before retrying."
        return 1
    fi
    PHP_VER_DOTTED="${PHP_VER_NUM:0:1}.${PHP_VER_NUM:1:1}"

    read -rp "Enable ${MISSING[*]} for $ACCOUNT via PHP Selector (PHP $PHP_VER_DOTTED) now? [Y/n]: " _install_ext
    case "$_install_ext" in
        [Nn]*)
            echo_error "Enable them via the PHP Selector (Multi-PHP Manager) in cPanel before retrying."
            return 1
            ;;
    esac

    local MISSING_CSV
    MISSING_CSV=$(IFS=,; echo "${MISSING[*]}")
    echo_info "Enabling ${MISSING[*]} via PHP Selector..."
    ssh root@server "selectorctl --interpreter=php --user='${ACCOUNT}' --version='${PHP_VER_DOTTED}' --enable-user-extensions='${MISSING_CSV}'" \
        || { echo_error "Failed to enable ${MISSING[*]} via PHP Selector."; return 1; }

    LOADED=$(ssh "${ACCOUNT}@server" "$PHP_BIN -m" 2>/dev/null)
    local STILL_MISSING=()
    for ext in "${MISSING[@]}"; do
        grep -qix "$ext" <<< "$LOADED" || STILL_MISSING+=("$ext")
    done

    if [ ${#STILL_MISSING[@]} -gt 0 ]; then
        echo_error "Still missing after enabling via PHP Selector: ${STILL_MISSING[*]}"
        return 1
    fi

    echo_success "PHP extensions enabled for $ACCOUNT: ${MISSING[*]}"
    return 0
}

# Checks whether a path (relative to the account's home) already exists remotely.
# Usage: remote_file_exists <account> <relative_path>
remote_file_exists() {
    local ACCOUNT="$1"
    local REL_PATH="$2"
    ssh "${ACCOUNT}@server" "[ -e ~/${REL_PATH} ]"
}

# Checks whether a directory (relative to the account's home) exists remotely and already
# has files in it. Catches the case a specific "is this app already installed" check (e.g.
# wp-config.php/parameters.php) would miss: some unrelated content (a different app, a
# cPanel default placeholder page, leftovers from a previous failed attempt) already sitting
# in the target folder, which unzip -o / wp core download would otherwise mix into.
# Usage: remote_dir_nonempty <account> <relative_path>
remote_dir_nonempty() {
    local ACCOUNT="$1"
    local REL_PATH="$2"
    ssh "${ACCOUNT}@server" "[ -d ~/${REL_PATH} ] && [ -n \"\$(ls -A ~/${REL_PATH} 2>/dev/null)\" ]"
}

# Lists every domain (main + addon + sub) already on this account, with its docroot — via
# `uapi DomainInfo domains_data`, run as the account itself (no root/WHM API needed). Meant to
# be shown before the user picks a ROOT_DIR or decides on MultiPHP in create_wordpress/
# create_prestashop — a domain sharing docroot with an existing site changes both answers, and
# there was previously no way to see that up front. Parked domains are skipped: uapi reports
# them as bare names with no docroot of their own (they inherit their target's).
# uapi's plain-text output sorts each hash's keys alphabetically, so "documentroot:" always
# comes before "domain:" within the same entry — pairing on that order (print + reset once
# both are seen) avoids needing to track the different list markers main_domain/addon_domains/
# sub_domains each use.
# Usage: list_account_vhosts <account>
# Prints one "<domain>|<documentroot>" line per domain (nothing if the account has none, or the
# uapi call fails).
list_account_vhosts() {
    local ACCOUNT="$1"
    ssh "${ACCOUNT}@server" "uapi DomainInfo domains_data" 2>/dev/null | awk '
        /^[[:space:]]*documentroot:/ { doc=$2 }
        /^[[:space:]]*domain:/ { dom=$2; if (doc!="") { print dom"|"doc; doc=""; dom="" } }
    '
}

# Checks whether a MySQL database already exists on the account (cPanel-level, uapi).
# Usage: mysql_database_exists <account> <db_name>
mysql_database_exists() {
    local ACCOUNT="$1"
    local DB_NAME="$2"
    local DB_LIST
    DB_LIST=$(ssh "${ACCOUNT}@server" "uapi Mysql list_databases" 2>/dev/null)
    grep -qE "^[[:space:]]*database:[[:space:]]*${DB_NAME}\$" <<< "$DB_LIST"
}

# Checks whether a MySQL user already exists on the account (cPanel-level, uapi).
# Usage: mysql_user_exists <account> <db_user>
mysql_user_exists() {
    local ACCOUNT="$1"
    local DB_USER="$2"
    local USERS_LIST
    USERS_LIST=$(ssh "${ACCOUNT}@server" "uapi Mysql list_users" 2>/dev/null)
    grep -qE "^[[:space:]]*user:[[:space:]]*${DB_USER}\$" <<< "$USERS_LIST"
}

# Checks whether an email account already exists on the account (cPanel-level, uapi).
# Usage: email_account_exists <account> <email>
email_account_exists() {
    local ACCOUNT="$1"
    local EMAIL="$2"
    local POP_LIST
    POP_LIST=$(ssh "${ACCOUNT}@server" "uapi Email list_pops" 2>/dev/null)
    grep -qE "^[[:space:]]*email:[[:space:]]*${EMAIL}\$" <<< "$POP_LIST"
}

server() {
    local ACCOUNT
    if [ -z "$1" ]; then
        ACCOUNT=$(select_account) || { echo_error "No user account defined!"; return 1; }
    else
        ACCOUNT="$1"
    fi
    if [[ ! "$ACCOUNT" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo_error "Invalid account name: '$ACCOUNT'"
        return 1
    fi

    # Check shell access
    check_shell_access "$ACCOUNT" 1
    case $? in
        0) ;;
        1)
            read -rp "Do you want to activate shell access for '$ACCOUNT'? [y/N]: " answer
            case "$answer" in
                [Yy]* )
                    echo "Activating shell access..."
                    add_shell_access "$ACCOUNT" || { echo_error "Failed to activate shell"; return 1; }
                    ;;
                * )
                    echo "Shell access not changed."
                    return 0
                    ;;
            esac
            ;;
        2)
            echo_error "$ACCOUNT not found."
            return 1
            ;;
        3)
            echo_error "$ACCOUNT has an unusual shell. Please check manually."
            return 1
            ;;
    esac

    # Authenticating SSH key
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$ACCOUNT@server" "true" 2>/dev/null; then
        read -rp "SSH key not authorized for '$ACCOUNT'. Copy key to server? [y/N]: " answer
        case "$answer" in
            [Yy]*)
                setup_ssh_key "$ACCOUNT" || { echo_error "Failed to copy SSH key"; return 1; }
                ssh -o BatchMode=yes -o ConnectTimeout=5 "$ACCOUNT@server" "true" || { echo_error "SSH authentication failed"; return 1; }
                ;;
            *)
                echo_error "SSH authentication failed"
                return 1
                ;;
        esac
    fi

    connect_server "$ACCOUNT"

}


connect_server() {
    if [ -z "$1" ]; then
        echo_error "No user account defined!"
        return 1
    fi

    local ACCOUNT="$1"

    echo_info "************************************"
    echo_info "* RED - Production server ($ACCOUNT)"
    echo_info "************************************"
    ssh "$ACCOUNT@server"
}

echo_production_warning() {
    echo_error "Are you sure you want to deploy to PRODUCTION? [y/N]"
    read answer

    case "$answer" in
        [Yy]) ;; # echo "Deploying...";;
        *) echo "Aborted."; return 1;;
    esac
}

export -f echo_production_warning

# ─────────────── AUTO-COMPLETE OPCIONAL ───────────────
_server_account_autocomplete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local accounts
    if [[ $COMP_CWORD -eq 1 ]]; then
        accounts=$(ssh "$SERVER" "cut -d: -f1 /etc/trueuserowners" 2>/dev/null)
        COMPREPLY=( $(compgen -W "$accounts" -- "$cur") )
    fi
}
complete -F _server_account_autocomplete server
