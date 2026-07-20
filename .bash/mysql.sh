#!/bin/bash

# Uso: get_database [--skip-dev] [nome_da_bd] [caminho_dump_ja_descarregado]
# --skip-dev salta a preparação da configuração do PrestaShop para
# desenvolvimento/teste (cache, SSL, mail, remoção de módulos, truncate à moloni)
# — mantém sempre a conversão de domínio para .test (shop_url/WordPress
# siteurl/home), que é o que torna o site utilizável localmente.
get_database(){
    local USAGE="Uso: get_database [--skip-dev] [nome_da_bd] [caminho_dump_ja_descarregado]"
    local SKIP_DEV=0
    local POSITIONAL=()
    local arg
    for arg in "$@"; do
        case "$arg" in
            --skip-dev) SKIP_DEV=1 ;;
            *) POSITIONAL+=("$arg") ;;
        esac
    done
    set -- "${POSITIONAL[@]}"

    # Nomes de BD nunca começam por "-" (o cPanel cria-as sempre com prefixo
    # "conta_"), por isso isto só pode ser uma opção mal escrita/desconhecida —
    # nunca uma base de dados real. Sem esta validação, ficava silenciosamente a
    # tratar a opção como nome da BD (ex: get_database --skip-devs, mal escrito
    # -> tentava duplicar uma BD chamada "--skip-devs").
    if [[ "$1" == -* ]]; then
        echo_error "Opção desconhecida: '$1'"
        echo "$USAGE"
        return 1
    fi

    local DATABASE_NAME
    if [ -z "$1" ]; then
        DATABASE_NAME=$(ssh root@server "mysql -N -e 'SHOW DATABASES' 2>/dev/null" | grep -Ev '^(information_schema|mysql|performance_schema|sys)$' | fzf --prompt="Select database: ")
        if [ -z "$DATABASE_NAME" ]; then
            echo_error "No database provided"
            return 1
        fi
    else
        DATABASE_NAME="$1"
    fi

    # Deteção de plataforma: PrestaShop e WordPress são detetados da mesma forma, no
    # mesmo sítio, via SSH à produção (leitura) — antes eram feitas em dois pontos
    # diferentes do fluxo (PrestaShop aqui, WordPress só depois de importar
    # localmente), o que era inconsistente e escondia o resultado do WordPress do
    # aviso de confirmação. Prefixo real, não "wp_"/"_shop_url" fixos: comum trocar
    # por segurança, deteta-se a partir da tabela mais curta que bate com o sufixo
    # e, no caso do WordPress, confirma-se com uma tabela "*users" correspondente
    # (evita apanhar por engano uma tabela de outra app qualquer chamada "options").
    local PS_SHOP_URL_TABLE
    PS_SHOP_URL_TABLE=$(ssh root@server "mysql -N -e \"SELECT TABLE_NAME FROM information_schema.tables WHERE table_schema='${DATABASE_NAME}' AND TABLE_NAME LIKE '%\\\\_shop\\\\_url' ORDER BY LENGTH(TABLE_NAME) ASC LIMIT 1\" 2>/dev/null")

    local PS_PREFIX=""
    if [ -n "$PS_SHOP_URL_TABLE" ]; then
        PS_PREFIX="${PS_SHOP_URL_TABLE%_shop_url}"
        echo_prestashop "PrestaShop detected (prefix: ${PS_PREFIX})"
    fi

    local WP_OPTIONS_TABLE
    WP_OPTIONS_TABLE=$(ssh root@server "mysql -N -e \"SELECT TABLE_NAME FROM information_schema.tables WHERE table_schema='${DATABASE_NAME}' AND TABLE_NAME LIKE '%options' ORDER BY LENGTH(TABLE_NAME) ASC LIMIT 1\" 2>/dev/null")

    local WP_PREFIX=""
    local WP_USERS_EXISTS=""
    if [ -n "$WP_OPTIONS_TABLE" ]; then
        WP_PREFIX="${WP_OPTIONS_TABLE%options}"
        WP_USERS_EXISTS=$(ssh root@server "mysql -N -e \"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DATABASE_NAME}' AND TABLE_NAME='${WP_PREFIX}users'\" 2>/dev/null")
        if [ "$WP_USERS_EXISTS" = "1" ]; then
            echo_wordpress "WordPress detected (prefix: ${WP_PREFIX})"
        fi
    fi

    echo -e "${WHITE}Database:$RESET $BOLD${DATABASE_NAME}$RESET"
    if [ "$SKIP_DEV" = "1" ]; then
        echo_info "--skip-dev: a ignorar as configurações para desenvolvimento/teste"
    fi

    local confirm
    read -r -p "Continue? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo_error "Aborted."
        return 1
    fi

    # Authenticating SSH key...
    ssh root@server "true" || { echo_error "SSH authentication failed"; return 1; }

    local DATABASE_PATH
    if [ -z "$2" ]; then
        DATABASE_PATH="$HOME/Downloads/$DATABASE_NAME.sql"
        echo_info "Downloading..."

        # # Remote compress
        # ssh root@server "mysqldump --single-transaction --quick --ignore-table=${DATABASE_NAME}.${PS_PREFIX}_layered_category $DATABASE_NAME | gzip -c" | pv > $DATABASE_PATH

        # Without compression
        # ssh root@server mysqldump --single-transaction --quick --ignore-table=${DATABASE_NAME}.${PS_PREFIX}_layered_category $DATABASE_NAME | pv > $DATABASE_PATH
        ssh root@server mysqldump --single-transaction --quick $DATABASE_NAME | pv > $DATABASE_PATH
        # PIPESTATUS[0] = exit code do ssh/mysqldump remoto (o do pipe seria só o do `pv`,
        # que "sucede" mesmo que o mysqldump falhe a meio e produza um dump vazio/truncado).
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            echo_error "mysqldump remoto falhou."
            return 1
        fi
    else
        DATABASE_PATH="$2"
        echo_success "Getting already downloaded file: $DATABASE_PATH"
    fi

    if [ ! -s "$DATABASE_PATH" ]; then
        echo_error "Dump file '$DATABASE_PATH' is missing or empty."
        return 1
    fi

    if ! tail -n 5 "$DATABASE_PATH" | grep -q -- "-- Dump completed on"; then
        echo_error "Dump seems incomplete/corrupted: no 'Dump completed on' marker at the end of '$DATABASE_PATH'."
        local force_confirm
        read -r -p "Continue anyway? [y/N] " force_confirm
        if [[ ! "$force_confirm" =~ ^[Yy]$ ]]; then
            echo_error "Aborted."
            return 1
        fi
    fi

    # Todos os comandos que apagam/alteram dados abaixo correm SEMPRE contra o
    # mysql local (127.0.0.1), nunca contra o servidor de produção. O SSH ao
    # servidor remoto só é usado para SHOW DATABASES, deteção de plataforma e
    # mysqldump (leitura).
    local LOCAL_MYSQL
    LOCAL_MYSQL=(mysql -h 127.0.0.1 --protocol=TCP)

    echo -e "$BOLD${MAGENTA}Importing...$RESET"
"${LOCAL_MYSQL[@]}" <<EOF
DROP DATABASE IF EXISTS ${DATABASE_NAME};
CREATE DATABASE ${DATABASE_NAME};
EOF

    # # With compression
    # UNCOMPRESSED_SIZE=$(gzip -l $DATABASE_PATH | awk 'NR==2 {print $2}')
    # gunzip -c $DATABASE_PATH | pv -s $UNCOMPRESSED_SIZE | mysql ${DATABASE_NAME}

    # without compression
    local FILE_SIZE
    FILE_SIZE=$(stat -c %s "$DATABASE_PATH")
    pv -s "$FILE_SIZE" "$DATABASE_PATH" | "${LOCAL_MYSQL[@]}" ${DATABASE_NAME}

    # Regex partilhada entre PrestaShop e WordPress para converter o domínio real em .test
    local DOMAIN_TO_TEST_REGEX='s/\.[^.]{2,3}(\.red\-agency|\.red\.com)?(\.[^.]{2,3})?$/.test/s'

    if [ -n "$PS_PREFIX" ]; then
        if [ "$SKIP_DEV" != "1" ]; then
"${LOCAL_MYSQL[@]}" <<EOF
use ${DATABASE_NAME};
UPDATE ${PS_PREFIX}_configuration SET value = 0 WHERE name = 'PS_SMARTY_CACHE';
UPDATE ${PS_PREFIX}_configuration SET value = 0 WHERE name = 'PS_CSS_THEME_CACHE';
UPDATE ${PS_PREFIX}_configuration SET value = 0 WHERE name = 'PS_JS_THEME_CACHE';
UPDATE ${PS_PREFIX}_configuration SET value = 1 WHERE name = 'PS_SSL_ENABLED';
UPDATE ${PS_PREFIX}_configuration SET value = 1 WHERE name = 'PS_SSL_ENABLED_EVERYWHERE';
UPDATE ${PS_PREFIX}_configuration SET value = NULL WHERE name = 'PS_MAIL_USER';
UPDATE ${PS_PREFIX}_configuration SET value = NULL WHERE name = 'PS_MAIL_PASSWD';
UPDATE ${PS_PREFIX}_configuration SET value = NULL WHERE name = 'PS_MAIL_SMTP_ENCRYPTION';
UPDATE ${PS_PREFIX}_configuration SET value = 1025 WHERE name = 'PS_MAIL_SMTP_PORT';
UPDATE ${PS_PREFIX}_configuration SET value = 'localhost' WHERE name = 'PS_MAIL_SERVER';
UPDATE ${PS_PREFIX}_configuration SET value = 1 WHERE name = 'PS_SHOP_ENABLE';
UPDATE ${PS_PREFIX}_configuration SET value = NULL WHERE name = 'PS_MEDIA_SERVER_1';
UPDATE ${PS_PREFIX}_configuration SET value = NULL WHERE name = 'PS_MEDIA_SERVER_2';
UPDATE ${PS_PREFIX}_configuration SET value = NULL WHERE name = 'PS_MEDIA_SERVER_3';
DELETE FROM ${PS_PREFIX}_module WHERE name = 'klaviyops';
DELETE FROM ${PS_PREFIX}_module WHERE name = 'cdc_googletagmanager';
DELETE FROM ${PS_PREFIX}_module WHERE name = 'klarnapayment';
DELETE FROM ${PS_PREFIX}_module WHERE name like '%recaptcha%';
EOF
            local file
            file=$("${LOCAL_MYSQL[@]}" -se "SELECT count(*) as count FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='${DATABASE_NAME}' AND TABLE_NAME='${PS_PREFIX}_moloni'" | cut -d \t -f 2)
            if [ "$file" == "1" ];
            then
                "${LOCAL_MYSQL[@]}" ${DATABASE_NAME} -se "TRUNCATE TABLE ${PS_PREFIX}_moloni;";
            fi
        fi

        local domains
        domains=( $("${LOCAL_MYSQL[@]}" ${DATABASE_NAME} -se "SELECT domain FROM ${PS_PREFIX}_shop_url") )
        local i domain
        for i in "${domains[@]}"; do
            # domain=$( echo "$i" | perl -pe 's/\.[^.]{2,3}(?:\.[^.]{2,3})?$/.test/s' )
            domain=$( echo "$i" | perl -pe "$DOMAIN_TO_TEST_REGEX" )
            "${LOCAL_MYSQL[@]}" ${DATABASE_NAME} -se "UPDATE ${PS_PREFIX}_shop_url set domain=\"${domain}\", domain_ssl=\"${domain}\" where domain=\"$i\";"
        done
    fi

    # WordPress: aponta siteurl/home para .test (mesma conversão de domínio do
    # PrestaShop), preservando esquema e path. Prefixo já detetado acima.
    if [ -n "$WP_OPTIONS_TABLE" ] && [ "$WP_USERS_EXISTS" = "1" ]; then
        local urls
        urls=( $("${LOCAL_MYSQL[@]}" ${DATABASE_NAME} -se "SELECT DISTINCT option_value FROM ${WP_OPTIONS_TABLE} WHERE option_name IN ('siteurl','home')") )
        local url scheme rest host path newhost newurl
        for url in "${urls[@]}"; do
            # Sem "://" o valor já vem malformado (não deveria acontecer num WP normal) —
            # sem isto, scheme ficava com a string toda e o rebuild abaixo dava um
            # disparate tipo "quintanimal.pt://quintanimal.test". Mais vale não tocar.
            if [[ "$url" != *"://"* ]]; then
                continue
            fi
            scheme="${url%%://*}"
            rest="${url#*://}"
            host="${rest%%/*}"
            path="${rest#$host}"
            newhost=$( echo "$host" | perl -pe "$DOMAIN_TO_TEST_REGEX" )
            newurl="${scheme}://${newhost}${path}"
            "${LOCAL_MYSQL[@]}" ${DATABASE_NAME} -se "UPDATE ${WP_OPTIONS_TABLE} SET option_value=\"${newurl}\" WHERE option_name IN ('siteurl','home') AND option_value=\"${url}\";"
        done
    fi

    echo_success "Done!"
}

# ─────────────── AUTO-COMPLETE OPCIONAL ───────────────
_get_database_autocomplete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local databases
    if [[ $COMP_CWORD -eq 1 ]]; then
        databases=$(ssh root@server "mysql -N -e 'SHOW DATABASES' 2>/dev/null" | grep -Ev '^(information_schema|mysql|performance_schema|sys)$')
        COMPREPLY=( $(compgen -W "--skip-dev $databases" -- "$cur") )
    fi
}
complete -F _get_database_autocomplete get_database
