#!/bin/bash

check_shell_access() {
    if [ -z "$1" ]; then
       echo_error "No user account defined!"
       return 1
    fi

    local ACCOUNT="$1"

    entry=$(ssh root@server "getent passwd $ACCOUNT" 2>/dev/null || true)

    if [[ -z "$entry" ]]; then
        return 2 # user not found
    fi

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

    ssh root@server "usermod -s /bin/bash $ACCOUNT"
    echo_success "Shell Access activated for $ACCOUNT."
}


remove_shell_access() {
    if [ -z "$1" ]; then
       echo_error "No user account defined!"
       return 1
    fi

    local ACCOUNT="$1"

    ssh root@server "usermod -s /usr/local/cpanel/bin/noshell $ACCOUNT"
    echo_error "$ACCOUNT no longer has shell access."
}

server() {
    if [ -z "$1" ]; then
        echo_error "No user account defined!"
        return 1
    fi

    local ACCOUNT="$1"

    # Check shell access
    check_shell_access "$ACCOUNT" 1
    case $? in
        0)
            connect_server "$ACCOUNT"
            ;;
        1)
            # User exists but no shell → ask if should activate
            read -rp "Do you want to activate shell access for '$ACCOUNT'? [y/N]: " answer
            case "$answer" in
                [Yy]* )
                    echo "Activating shell access..."
                    add_shell_access "$ACCOUNT" || { echo_error "Failed to activate shell"; return; }
                    connect_server "$ACCOUNT"
                    ;;
                * )
                    echo "Shell access not changed."
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
        *) echo "Aborted."; exit 1;;
    esac
}

export -f echo_production_warning
