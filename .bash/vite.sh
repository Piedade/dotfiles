#!/bin/bash

# Deploys a local Laravel project to its cPanel account: pushes the local git
# repo, uploads the Vite build output (public/build, gitignored so git alone
# never carries it), then pulls on the account so its working copy matches
# what was just pushed. Replaces the copy-pasted per-project deploy.sh scripts
# (see /var/www/vousetmoi.test/deploy.sh, /var/www/gridal.test/deploy.sh) that
# hardcode ACCOUNT and DOMAIN_FOLDER and never touch git at all.
#
# Domain and account are auto-detected: the local folder name (ex:
# /var/www/gridal.test) gives the domain's base name ("gridal"), which is
# matched against the server's domain list (/etc/userdomains) to find the real
# production domain (ex: "gridal.pt") — the local ".test" TLD is never the
# same as production's, so it can't be guessed, only matched. The owning
# cPanel account is then resolved from that domain (whm_account_by_domain,
# whm.sh), never guessed from the folder name directly. The documentroot
# (whm_docroot_by_domain, whm.sh) is resolved via WHM too, instead of assuming
# "public_html" like the old per-project scripts did.
#
# Uso: deploy_laravel [dominio_producao]
# dominio_producao (opcional): força o domínio em vez de o adivinhar a partir da pasta local.
deploy_laravel() {
    local CURRENT_DIR
    CURRENT_DIR=$(pwd)

    if [[ ! "$CURRENT_DIR" =~ ^/var/www ]]; then
        echo_error "Current directory is not inside /var/www."
        return 1
    fi

    if [ ! -f "artisan" ]; then
        echo_error "No 'artisan' file found here — this doesn't look like a Laravel project."
        return 1
    fi

    if [ ! -f "vite.config.js" ] && [ ! -f "vite.config.ts" ]; then
        echo_error "No vite.config.js/.ts found here — this doesn't look like a Vite project."
        return 1
    fi

    if [ -n "$(git status --porcelain)" ]; then
        echo_error "There are uncommitted changes. Commit or stash them before deploying."
        return 1
    fi

    local LOCAL_DOMAIN
    LOCAL_DOMAIN=$(basename "$CURRENT_DIR")
    local BASE="${LOCAL_DOMAIN%.test}"

    local DOMAIN="$1"
    if [ -z "$DOMAIN" ]; then
        local MATCHES MATCH_COUNT
        MATCHES=$(ssh "$SERVER" "awk -F': ' '{print \$1}' /etc/userdomains" 2>/dev/null | grep -E "^${BASE}\.")
        MATCH_COUNT=$(echo "$MATCHES" | grep -c . || true)

        if [ "$MATCH_COUNT" -eq 1 ]; then
            DOMAIN="$MATCHES"
            echo_info "Domain detected: $DOMAIN"
        elif [ "$MATCH_COUNT" -gt 1 ]; then
            DOMAIN=$(echo "$MATCHES" | fzf --prompt="Select domain: ")
            [ -z "$DOMAIN" ] && { echo_error "Domain is required."; return 1; }
        else
            echo_info "No domain found on the server matching '${BASE}.*'."
            DOMAIN=$(select_domain_global) || { echo_error "Domain is required."; return 1; }
        fi
    fi

    local ACCOUNT
    ACCOUNT=$(whm_account_by_domain "$DOMAIN") || { echo_error "Domain '$DOMAIN' not found on the server."; return 1; }

    local ROOT_DIR DOC_ROOT
    DOC_ROOT=$(whm_docroot_by_domain "$DOMAIN")
    if [ -n "$DOC_ROOT" ] && [[ "$DOC_ROOT" == "/home/${ACCOUNT}/"* ]]; then
        ROOT_DIR="${DOC_ROOT#/home/${ACCOUNT}/}"
    else
        ROOT_DIR="public_html"
        echo_info "Could not detect the documentroot via WHM — assuming '$ROOT_DIR'."
    fi

    # Some Laravel setups point the docroot straight at the project's public/
    # folder (ex: public_html/public), keeping .env/vendor/storage out of the
    # web root, instead of at the project root (ex: public_html) itself. The
    # git repo and .env always live in the project root, so it's what "git
    # pull" needs to run in — while build assets always land in its public/
    # subfolder, so it's what the docroot resolves to either way.
    local PROJECT_DIR BUILD_DIR
    if [[ "$ROOT_DIR" == */public ]]; then
        PROJECT_DIR="${ROOT_DIR%/public}"
        BUILD_DIR="${ROOT_DIR}/build"
    else
        PROJECT_DIR="$ROOT_DIR"
        BUILD_DIR="${ROOT_DIR}/public/build"
    fi

    echo_laravel "Deploy target -> account: $ACCOUNT, domain: $DOMAIN, folder: ~/$PROJECT_DIR"
    echo_production_warning || return 1

    local BUMP
    read -rp "Bump version first (npm version patch)? [y/N]: " BUMP
    if [[ "$BUMP" == "y" || "$BUMP" == "Y" ]]; then
        npm version patch || { echo_error "Failed to bump version."; return 1; }
        echo_info "Version: $(npm pkg get version | xargs echo)"
    fi

    # Prefer a dedicated "build:production" script (ex: gridal.test) when present,
    # falling back to the plain "build" script (ex: vousetmoi.test) otherwise.
    local BUILD_SCRIPT="build"
    grep -q '"build:production"[[:space:]]*:' package.json 2>/dev/null && BUILD_SCRIPT="build:production"

    echo_info "Building ($BUILD_SCRIPT)..."
    npm run "$BUILD_SCRIPT" || { echo_error "Build failed."; return 1; }

    if [ ! -d "public/build" ]; then
        echo_error "'public/build' does not exist after the build."
        return 1
    fi

    echo_info "Pushing to git..."
    git push || { echo_error "git push failed."; return 1; }

    check_shell_access "$ACCOUNT" 1
    case $? in
        1)
            echo_info "Enabling shell access..."
            add_shell_access "$ACCOUNT" || { echo_error "Failed to enable shell access."; return 1; }
            ;;
        2) echo_error "$ACCOUNT not found."; return 1 ;;
        3) echo_error "$ACCOUNT has an unusual shell. Please check manually."; return 1 ;;
    esac
    setup_ssh_key "$ACCOUNT"

    echo_info "Uploading build files..."
    # --delete: Vite hashes filenames per build, so stale assets from previous
    # builds would otherwise pile up in public/build forever.
    rsync -a --delete --progress "public/build/" "${ACCOUNT}@server:/home/${ACCOUNT}/${BUILD_DIR}/" \
        || { echo_error "Failed to deploy build files."; return 1; }

    echo_info "Pulling on $ACCOUNT..."
    # -t: without a pty, git pull's internal "ssh git@github.com" has nowhere to
    # prompt for the account's SSH key passphrase and just fails outright; -t lets
    # that prompt reach this terminal (same as running git pull by hand over ssh).
    ssh -t "${ACCOUNT}@server" "cd ~/${PROJECT_DIR} && git pull" \
        || { echo_error "git pull failed on $ACCOUNT."; return 1; }

    echo_success "🚀 Deployed to https://$DOMAIN ($ACCOUNT:~/$PROJECT_DIR)"
}

# ─────────────── AUTO-COMPLETE OPCIONAL ───────────────
_deploy_laravel_autocomplete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ $COMP_CWORD -eq 1 ]]; then
        local domains
        domains=$(ssh "$SERVER" "awk -F': ' '{print \$1}' /etc/userdomains" 2>/dev/null)
        COMPREPLY=( $(compgen -W "$domains" -- "$cur") )
    fi
}
complete -F _deploy_laravel_autocomplete deploy_laravel
