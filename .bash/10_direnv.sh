#!/bin/bash

# Composer
export COMPOSER_MEMORY_LIMIT=-1

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Suppress direnv logs
export DIRENV_LOG_FORMAT=""

setup_direnv() {
    #local PHP_VERSION="$(php -r 'echo PHP_VERSION;' 2>/dev/null)"
    #local NODE_VERSION="$(node -v 2>/dev/null)"
    local PHP_VERSION=""
    local NODE_VERSION=""
    local COMPOSER_VERSION=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --php)
                PHP_VERSION="$2"
                shift 2
                ;;
            --node)
                NODE_VERSION="$2"
                shift 2
                ;;
            --composer)
                COMPOSER_VERSION="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done

    # local PHP_VERSION="${PHP:-}"
    # local NODE_VERSION="${NODE:-}"
    # local COMPOSER_VERSION="${COMPOSER:-}"

    # Ensure direnv bin folder exists
    mkdir -p "$PWD/.direnv"
    export PATH="$PWD/.direnv:$PATH"

    # PHP
    if [[ -n $PHP_VERSION ]]; then
        # export PHP_BIN="/usr/bin/php$PHP_VERSION"
        # echo "Using PHP $PHP_VERSION"
        if [[ -x "/usr/bin/php$PHP_VERSION" ]]; then
            ln -sf "/usr/bin/php$PHP_VERSION" "$PWD/.direnv/php"
        else
            echo_error "PHP version $PHP_VERSION is not installed!"
        fi
    fi

    # Node
    if [[ -n $NODE_VERSION ]]; then
        # Load nvm inside the function
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

        local locally_resolved_nvm_version
        # `nvm ls` will check all locally-available versions
        # If there are multiple matching versions, take the latest one
        # Remove the `->` and `*` characters and spaces
        # `locally_resolved_nvm_version` will be `N/A` if no local versions are found
        locally_resolved_nvm_version=$(nvm ls --no-colors "${NODE_VERSION}" | command tail -1 | command tr -d '\->*' | command tr -d '[:space:]')

        # If it is not already installed, install it
        # `nvm install` will implicitly use the newly-installed version
        if [ "${locally_resolved_nvm_version}" = 'N/A' ]; then
            nvm install "${NODE_VERSION}";
            locally_resolved_nvm_version=$(nvm ls --no-colors "${NODE_VERSION}" | command tail -1 | command tr -d '\->*' | command tr -d '[:space:]')
        fi

        # Use NVM
        if [ "$(nvm current)" != "${locally_resolved_nvm_version}" ]; then
            nvm use "${NODE_VERSION}" --silent
        fi
        #
        # OR MANUAL
        # # add global packages to bash PATH
        # export PATH="$HOME/.nvm/versions/node/$locally_resolved_nvm_version/bin:$PWD/.direnv/bin:$PATH"

        # ln -sf "$HOME/.nvm/versions/node/$locally_resolved_nvm_version/bin/node" "$PWD/.direnv/node"
        # ln -sf "$HOME/.nvm/versions/node/$locally_resolved_nvm_version/bin/npm" "$PWD/.direnv/npm"
        # ln -sf "$HOME/.nvm/versions/node/$locally_resolved_nvm_version/bin/npx" "$PWD/.direnv/npx"
    fi

    # Composer
    if [[ -n $COMPOSER_VERSION ]]; then
        if [[ -x "/usr/local/bin/composer$COMPOSER_VERSION" ]]; then
            ln -sf "/usr/local/bin/composer$COMPOSER_VERSION" "$PWD/.direnv/composer"
        else
            echo_error "Composer version $COMPOSER_VERSION is not installed!"
        fi
    fi
}

export -f setup_direnv

create_envrc() {
    local dir="$PWD"
    local env_file="$dir/.envrc"

        if [[ ! -f "$env_file" ]]; then
cat > "$env_file" << EOF
PHP=$(php -v 2>/dev/null | grep -oP '(?<=PHP )\d+\.\d+' | head -1)
NODE=
COMPOSER=

setup_direnv \\
    --php "\$PHP" \\
    --node "\$NODE" \\
    --composer "\$COMPOSER"
EOF

        direnv allow
        echo_success "Created .envrc in $dir"
    else
        echo_error ".envrc already exists in $dir"
    fi
}

# # Function to search for a .phprc file and set PHP_BIN
# autoload_php() {
#   local dir="$PWD"
#   local php_bin

#   while [[ "$dir" != "/" ]]; do
#     if [[ -f "$dir/.phprc" ]]; then
#       php_bin=php$(<"$dir/.phprc")
#       if command -v "$php_bin" >/dev/null 2>&1; then
#         export PHP_BIN="$php_bin"
#         # echo "[phprc] Using PHP: $PHP_BIN"
#         return
#       else
#         echo "[.phprc] Invalid PHP binary: $php_bin"
#         break
#       fi
#     fi
#     dir=$(dirname "$dir")
#   done

#   # No .phprc found or invalid: fallback
#   export PHP_BIN="/usr/bin/php"
#   # echo "[phprc] Using default PHP: $PHP_BIN"
# }

# # Override php command to use PHP_BIN
# php() {
#   "$PHP_BIN" "$@"
# }

# # Run autoload_php every time you change directory
# PROMPT_COMMAND="autoload_php;$PROMPT_COMMAND"
