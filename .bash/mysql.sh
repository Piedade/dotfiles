#!/bin/bash

get_database(){
    if [ -z "$1" ]; then
        DATABASE_NAME=$(ssh root@server "mysql -N -e 'SHOW DATABASES' 2>/dev/null" | grep -Ev '^(information_schema|mysql|performance_schema|sys)$' | fzf --prompt="Select database: ")
        if [ -z "$DATABASE_NAME" ]; then
            echo -e "${RED}No database provided$RESET"
            return 1
        fi
    else
        DATABASE_NAME="$1"
    fi

    # echo -e "${BLUE}Detecting PrestaShop prefix...$RESET"
    DETECTED_TABLE=$(ssh root@server "mysql -N -e \"SELECT TABLE_NAME FROM information_schema.tables WHERE table_schema='${DATABASE_NAME}' AND TABLE_NAME LIKE '%_configuration' LIMIT 1\" 2>/dev/null")

    if [ -n "$DETECTED_TABLE" ]; then
        DATABASE_PREFIX="${DETECTED_TABLE%_configuration}"
        echo -e "${BLUE_PRESTASHOP}󱇕 PrestaShop detected$RESET"
    else
        DATABASE_PREFIX="false"
        echo -e "${BLUE}Not a prestashop site...$RESET"
    fi

    echo -e "${WHITE}Database:$RESET $BOLD${DATABASE_NAME}$RESET"
    if [ "$DATABASE_PREFIX" != "false" ]; then
        echo -e "${WHITE}Prefix:$RESET $BOLD${DATABASE_PREFIX}$RESET"
    fi
    read -r -p "Continue? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Aborted.$RESET"
        return 1
    fi

    # Authenticating SSH key...
    ssh root@server "true" || { echo_error "SSH authentication failed"; exit 1; }

    if [ -z "$2" ]; then
        DATABASE_PATH="$HOME/Downloads/$DATABASE_NAME.sql"
        echo -e "$BOLD${YELLOW}Downloading...$RESET"

        # # Remote compress
        # ssh root@server "mysqldump --single-transaction --quick --ignore-table=${DATABASE_NAME}.${DATABASE_PREFIX}_layered_category $DATABASE_NAME | gzip -c" | pv > $DATABASE_PATH

        # Without compression
        # ssh root@server mysqldump --single-transaction --quick --ignore-table=${DATABASE_NAME}.${DATABASE_PREFIX}_layered_category $DATABASE_NAME | pv > $DATABASE_PATH
        ssh root@server mysqldump --single-transaction --quick $DATABASE_NAME | pv > $DATABASE_PATH
    else
        DATABASE_PATH="$2"
        echo -e "${GREEN}Getting already downloaded file: $DATABASE_PATH"
    fi

    if [ ! -s "$DATABASE_PATH" ]; then
        echo -e "${RED}Dump file '$DATABASE_PATH' is missing or empty.$RESET"
        return 1
    fi

    if ! tail -n 5 "$DATABASE_PATH" | grep -q -- "-- Dump completed on"; then
        echo -e "${RED}Dump seems incomplete/corrupted: no 'Dump completed on' marker at the end of '$DATABASE_PATH'.$RESET"
        read -r -p "Continue anyway? [y/N] " force_confirm
        if [[ ! "$force_confirm" =~ ^[Yy]$ ]]; then
            echo -e "${RED}Aborted.$RESET"
            return 1
        fi
    fi

    # Todos os comandos que apagam/alteram dados abaixo correm SEMPRE contra o
    # mysql local (127.0.0.1), nunca contra o servidor de produção. O SSH ao
    # servidor remoto só é usado para SHOW DATABASES e mysqldump (leitura).
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
    FILE_SIZE=$(stat -c %s "$DATABASE_PATH")
    pv -s "$FILE_SIZE" "$DATABASE_PATH" | "${LOCAL_MYSQL[@]}" ${DATABASE_NAME}

    if [ "$DATABASE_PREFIX" != "false" ]; then
"${LOCAL_MYSQL[@]}" <<EOF
use ${DATABASE_NAME};
UPDATE ${DATABASE_PREFIX}_configuration SET value = 0 WHERE name = 'PS_SMARTY_CACHE';
UPDATE ${DATABASE_PREFIX}_configuration SET value = 0 WHERE name = 'PS_CSS_THEME_CACHE';
UPDATE ${DATABASE_PREFIX}_configuration SET value = 0 WHERE name = 'PS_JS_THEME_CACHE';
UPDATE ${DATABASE_PREFIX}_configuration SET value = 1 WHERE name = 'PS_SSL_ENABLED';
UPDATE ${DATABASE_PREFIX}_configuration SET value = 1 WHERE name = 'PS_SSL_ENABLED_EVERYWHERE';
UPDATE ${DATABASE_PREFIX}_configuration SET value = NULL WHERE name = 'PS_MAIL_USER';
UPDATE ${DATABASE_PREFIX}_configuration SET value = NULL WHERE name = 'PS_MAIL_PASSWD';
UPDATE ${DATABASE_PREFIX}_configuration SET value = NULL WHERE name = 'PS_MAIL_SMTP_ENCRYPTION';
UPDATE ${DATABASE_PREFIX}_configuration SET value = 1025 WHERE name = 'PS_MAIL_SMTP_PORT';
UPDATE ${DATABASE_PREFIX}_configuration SET value = 'localhost' WHERE name = 'PS_MAIL_SERVER';
UPDATE ${DATABASE_PREFIX}_configuration SET value = 1 WHERE name = 'PS_SHOP_ENABLE';
UPDATE ${DATABASE_PREFIX}_configuration SET value = NULL WHERE name = 'PS_MEDIA_SERVER_1';
UPDATE ${DATABASE_PREFIX}_configuration SET value = NULL WHERE name = 'PS_MEDIA_SERVER_2';
UPDATE ${DATABASE_PREFIX}_configuration SET value = NULL WHERE name = 'PS_MEDIA_SERVER_3';
DELETE FROM ${DATABASE_PREFIX}_module WHERE name = 'klaviyops';
DELETE FROM ${DATABASE_PREFIX}_module WHERE name = 'cdc_googletagmanager';
DELETE FROM ${DATABASE_PREFIX}_module WHERE name = 'klarnapayment';
DELETE FROM ${DATABASE_PREFIX}_module WHERE name like '%recaptcha%';
EOF
        file=`"${LOCAL_MYSQL[@]}" -se "SELECT count(*) as count FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='${DATABASE_NAME}' AND TABLE_NAME='${DATABASE_PREFIX}_moloni'" | cut -d \t -f 2`
        if [ $file == "1" ];
        then
            "${LOCAL_MYSQL[@]}" ${DATABASE_NAME} -se "TRUNCATE TABLE ${DATABASE_PREFIX}_moloni;";
        fi

        domains=( $("${LOCAL_MYSQL[@]}" ${DATABASE_NAME} -se "SELECT domain FROM ${DATABASE_PREFIX}_shop_url") )
        for i in "${domains[@]}"; do
            # domain=$( echo "$i" | perl -pe 's/\.[^.]{2,3}(?:\.[^.]{2,3})?$/.test/s' )
            domain=$( echo "$i" | perl -pe 's/\.[^.]{2,3}(\.red\-agency|\.red\.com)?(\.[^.]{2,3})?$/.test/s' )
            "${LOCAL_MYSQL[@]}" ${DATABASE_NAME} -se "UPDATE ${DATABASE_PREFIX}_shop_url set domain=\"${domain}\", domain_ssl=\"${domain}\" where domain=\"$i\";"
        done
    fi

    echo -e "$BOLD${GREEN}Done!$RESET"
}

# ─────────────── AUTO-COMPLETE OPCIONAL ───────────────
_get_database_autocomplete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local databases
    if [[ $COMP_CWORD -eq 1 ]]; then
        databases=$(ssh root@server "mysql -N -e 'SHOW DATABASES' 2>/dev/null" | grep -Ev '^(information_schema|mysql|performance_schema|sys)$')
        COMPREPLY=( $(compgen -W "$databases" -- "$cur") )
    fi
}
complete -F _get_database_autocomplete get_database
