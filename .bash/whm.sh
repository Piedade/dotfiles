#!/bin/bash

# Testa se um domínio já é apanhado pelo bloco Apache
# (SetEnvIf Host ... NOINDEX_DOMAIN / Header X-Robots-Tag noindex) que aplica
# noindex a nível de servidor. Mantém as mesmas 4 regras desse .conf — se essas
# regras mudarem no Apache, atualizar aqui também. Usado por create_wordpress
# para saber se ainda precisa de bloquear indexação/visibilidade por outro meio
# (ex: Elementor maintenance mode) num domínio "real" fora desses padrões.
# Uso: is_noindex_domain <dominio>
is_noindex_domain() {
    local DOMAIN=$1
    [[ "$DOMAIN" =~ \.dev\.red\.com\.pt$ ]] && return 0
    [[ "$DOMAIN" =~ \.dev\.red-agency\.pt$ ]] && return 0
    [[ "$DOMAIN" =~ \.desenvolvimento\.redpost\.pt$ ]] && return 0
    [[ "$DOMAIN" =~ (^|\.)staging\. ]] && return 0
    return 1
}

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

# Devolve o documentroot (caminho absoluto) de um domínio, ou falha se não existir.
# Uso interno por outros scripts (ex: staging.sh) que precisem saber a pasta
# real do domínio em vez de adivinhar (public_html vs. nome do domínio).
whm_docroot_by_domain() {
    local DOMAIN=$1
    local DOCROOT
    DOCROOT=$(ssh "$SERVER" "whmapi1 domainuserdata domain=${DOMAIN}" | grep "documentroot:" | head -n1 | awk '{print $2}')

    if [ -z "$DOCROOT" ] || [ "$DOCROOT" = "~" ]; then
        return 1
    fi

    echo "$DOCROOT"
}

# Devolve a versão de PHP (ex: ea-php84) configurada em produção via MultiPHP
# Manager para um domínio, ou falha se não existir/não for detetável. Best-effort:
# quem chama (ex: get_site_files) deve lidar com falha/valor vazio sem bloquear o
# fluxo — nunca é garantido que o formato de saída do whmapi1 seja estável entre
# versões de WHM, por isso valida-se sempre o resultado antes de confiar nele.
whm_php_version_by_domain() {
    local DOMAIN=$1
    local VERSION
    VERSION=$(ssh "$SERVER" "whmapi1 php_get_vhost_versions" 2>/dev/null | awk -v domain="$DOMAIN" '
        /^[[:space:]]*-[[:space:]]*$/ { ver=""; vh="" }
        /version:/ { ver=$2 }
        /vhost:/ { vh=$2 }
        (vh==domain && ver!="") { print ver; exit }
    ')

    if [[ ! "$VERSION" =~ ^ea-php[0-9]+$ ]]; then
        return 1
    fi

    echo "$VERSION"
}

# Devolve a versão de PHP atual da conta, perguntando diretamente à conta via
# selectorctl (--user-current), em vez de inferir por um domínio específico.
# Preferir isto sempre que possível a whm_php_version_by_domain/whm_resolve_php_version
# quando o que se quer é "o que esta conta usa", não "o que este vhost em concreto
# tem configurado" — os dois podem divergir (MultiPHP Manager permite pinar um
# domínio a uma versão diferente do default da conta), e para um domínio novo
# que ainda nem existe como vhost, é a única forma de saber alguma coisa.
# Falha se a conta ainda não tiver shell access/chave SSH configurada.
# Uso: whm_php_version_by_account <conta>
whm_php_version_by_account() {
    local ACCOUNT=$1
    local VERSION
    VERSION=$(ssh "${ACCOUNT}@server" "selectorctl --interpreter=php --user-current" 2>/dev/null | awk '{print $1}')

    if [[ ! "$VERSION" =~ ^[0-9]\.[0-9]+$ ]]; then
        return 1
    fi

    echo "$VERSION"
}

# Devolve a versão de PHP (ex: ea-php84 ou alt-php84) forçada via .htaccess no
# documentroot de um domínio ("AddHandler application/x-httpd-{ea,alt}-phpNN___lsphp",
# o mecanismo clássico do PHP Selector/MultiPHP INI Editor), ou falha se essa
# diretiva não existir. Isto tem prioridade sobre whm_php_version_by_domain: o
# .htaccess é o que a conta realmente aplica a este domínio específico, enquanto a
# API do MultiPHP Manager reflete o default da conta/vhost — que este .htaccess
# pode estar a substituir (comum em domínios adicionais/subdomínios configurados
# à parte do domínio principal da conta).
# Uso: htaccess_php_version <conta> <pasta_relativa_ao_home>
htaccess_php_version() {
    local ACCOUNT=$1
    local ROOT_DIR=$2
    local VERSION
    VERSION=$(ssh "${ACCOUNT}@server" "grep -oP '(?<=x-httpd-)(ea|alt)-php[0-9]+(?=___lsphp)' ~/${ROOT_DIR}/.htaccess 2>/dev/null" 2>/dev/null | head -n1)

    if [[ ! "$VERSION" =~ ^(ea|alt)-php[0-9]+$ ]]; then
        return 1
    fi

    echo "$VERSION"
}

check_domain() {
    local DOMAIN=$1

    if [ -z "$DOMAIN" ]; then
        echo_error "Usage: check_domain <domain>"
        return 1
    fi

    local ACCOUNT
    ACCOUNT=$(whm_account_by_domain "$DOMAIN") || {
        echo_error "domain not found."
        local NS
        NS=$(dig NS "$DOMAIN" +short)
        if [ -n "$NS" ]; then
            echo_info "NS for $DOMAIN:"
            echo "$NS"
        fi
        return 1
    }

    echo_success "$DOMAIN -> $ACCOUNT"
}

# Resolve a versão de PHP de um domínio, tentando primeiro htaccess_php_version
# (mais específico: o que a conta realmente aplica a este documentroot) e só
# depois whm_php_version_by_domain (default da conta/vhost via MultiPHP Manager).
# Devolve "versão_dotted|origem|valor_bruto" (ex: "8.4|.htaccess|ea-php84"), ou
# falha se nada for detetável. Uso interno (get_php_by_domain, get_site_files).
whm_resolve_php_version() {
    local DOMAIN=$1
    local ACCOUNT=$2
    local ROOT_DIR=$3

    local RAW SOURCE
    RAW=$(htaccess_php_version "$ACCOUNT" "$ROOT_DIR")
    if [ -n "$RAW" ]; then
        SOURCE=".htaccess"
    else
        RAW=$(whm_php_version_by_domain "$DOMAIN")
        SOURCE="default da conta (MultiPHP Manager)"
    fi

    if [ -z "$RAW" ]; then
        return 1
    fi

    local DOTTED
    DOTTED=$(echo "$RAW" | sed -E 's/^(ea|alt)-php([0-9])([0-9])$/\2.\3/')
    if [[ ! "$DOTTED" =~ ^[0-9]\.[0-9]$ ]]; then
        return 1
    fi

    echo "${DOTTED}|${SOURCE}|${RAW}"
}

# Mostra a versão de PHP em uso por um domínio de produção (via .htaccess ou, na
# falta desse override, o default MultiPHP da conta). Não precisa de shell access
# nem de chave SSH configurada na conta — se o .htaccess não for alcançável, cai
# sem drama para o default da conta (que só depende de root@server).
# Uso: get_php_by_domain [dominio]
get_php_by_domain() {
    local DOMAIN=$1
    if [ -z "$DOMAIN" ]; then
        DOMAIN=$(select_domain_global) || { echo_error "Domain is required."; return 1; }
    fi

    local ACCOUNT
    ACCOUNT=$(whm_account_by_domain "$DOMAIN")
    if [ -z "$ACCOUNT" ]; then
        echo_error "Domínio '$DOMAIN' não encontrado no servidor."
        return 1
    fi

    local DOC_ROOT ROOT_DIR
    DOC_ROOT=$(whm_docroot_by_domain "$DOMAIN")
    if [ -n "$DOC_ROOT" ] && [[ "$DOC_ROOT" == "/home/${ACCOUNT}/"* ]]; then
        ROOT_DIR="${DOC_ROOT#/home/${ACCOUNT}/}"
    else
        echo_error "Não consegui determinar o documentroot de '$DOMAIN' via WHM."
        return 1
    fi

    local RESULT
    RESULT=$(whm_resolve_php_version "$DOMAIN" "$ACCOUNT" "$ROOT_DIR")
    if [ -z "$RESULT" ]; then
        echo_error "Não consegui detetar a versão de PHP de '$DOMAIN'."
        return 1
    fi

    local DOTTED SOURCE RAW
    IFS='|' read -r DOTTED SOURCE RAW <<< "$RESULT"

    echo_success "$DOMAIN -> PHP $DOTTED ($RAW, via $SOURCE)"
}

# ─────────────── AUTO-COMPLETE OPCIONAL ───────────────
_get_php_by_domain_autocomplete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ $COMP_CWORD -eq 1 ]]; then
        local domains
        domains=$(ssh "$SERVER" "awk -F': ' '{print \$1}' /etc/userdomains" 2>/dev/null)
        COMPREPLY=( $(compgen -W "$domains" -- "$cur") )
    fi
}
complete -F _get_php_by_domain_autocomplete get_php_by_domain
