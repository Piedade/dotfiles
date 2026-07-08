#!/bin/bash

# Devolve a conta (user) dona de um domínio, ou falha se não existir.
# Uso interno por outros scripts (ex: emails.sh) que precisem resolver
# domínio -> conta sem imprimir mensagens.
whm_account_by_domain() {
    local DOMAIN=$1
    local ACCOUNT
    ACCOUNT=$(ssh "$SERVER" "whmapi1 getdomainowner domain=${DOMAIN}" | grep "user:" | head -n1 | awk '{print $2}')

    if [ -z "$ACCOUNT" ] || [ "$ACCOUNT" = "~" ]; then
        return 1
    fi

    echo "$ACCOUNT"
}

get_domain_account() {
    local DOMAIN=$1

    if [ -z "$DOMAIN" ]; then
        echo_error "Usage: get_domain_account <domain>"
        return 1
    fi

    local ACCOUNT
    ACCOUNT=$(whm_account_by_domain "$DOMAIN") || { echo_error "Domain not found: $DOMAIN"; return 1; }

    echo_success "$DOMAIN -> $ACCOUNT"
}
