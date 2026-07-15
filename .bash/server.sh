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

    if [ ${#MISSING[@]} -gt 0 ]; then
        echo_error "Missing PHP extensions for $ACCOUNT: ${MISSING[*]}"
        echo_error "Install them via WHM EasyApache (e.g. ea-php84-php-${MISSING[0]}) before retrying."
        return 1
    fi

    return 0
}

# Checks whether a path (relative to the account's home) already exists remotely.
# Usage: remote_file_exists <account> <relative_path>
remote_file_exists() {
    local ACCOUNT="$1"
    local REL_PATH="$2"
    ssh "${ACCOUNT}@server" "[ -e ~/${REL_PATH} ]"
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
