#!/bin/bash

get_database(){
    if [ -z "$1" ]; then
        echo -e "${RED}No database provided$RESET"
        return 1
    else
        DATABASE_NAME="$1"
        echo "Database: ${DATABASE_NAME}"
    fi

    if [ -z "$2" ]; then
        DATABASE_PREFIX="false"
        echo -e "${BLUE}Not a prestashop site...$RESET"
    else
        DATABASE_PREFIX="$2"
        echo -e "${BLUE_PRESTASHOP}󱇕 PrestaShop$RESET"
        echo -e "${WHITE}Database Prefix:$RESET ${DATABASE_PREFIX}"

        if [ -z "$4" ]; then
            SSL="1"
        else
            SSL="$4"
        fi
        echo -e "${WHITE}SSL:$RESET ${SSL}"
    fi

    if [ -z "$3" ]; then
        DATABASE_PATH="$HOME/Downloads/$DATABASE_NAME.sql"
        echo -e "$BOLD${YELLOW}Downloading...$RESET"

        # # Remote compress
        # ssh root@server "mysqldump --single-transaction --quick --ignore-table=${DATABASE_NAME}.${DATABASE_PREFIX}_layered_category $DATABASE_NAME | gzip -c" | pv > $DATABASE_PATH

        # Without compression
        # ssh root@server mysqldump --single-transaction --quick --ignore-table=${DATABASE_NAME}.${DATABASE_PREFIX}_layered_category $DATABASE_NAME | pv > $DATABASE_PATH
        ssh root@server mysqldump --single-transaction --quick $DATABASE_NAME | pv > $DATABASE_PATH
    else
        DATABASE_PATH="$3"
        echo -e "${GREEN}Getting already downloaded file: $DATABASE_PATH"
    fi

    if [ -z "$DATABASE_PREFIX" ] || [ -z "$DATABASE_NAME" ]; then
        echo "No update"
    else
        echo -e "$BOLD${YELLOW}Importing...$RESET"
mysql <<EOF
DROP DATABASE IF EXISTS ${DATABASE_NAME};
CREATE DATABASE ${DATABASE_NAME};
EOF

        # # With compression
        # UNCOMPRESSED_SIZE=$(gzip -l $DATABASE_PATH | awk 'NR==2 {print $2}')
        # gunzip -c $DATABASE_PATH | pv -s $UNCOMPRESSED_SIZE | mysql ${DATABASE_NAME}

        # without compression
        FILE_SIZE=$(stat -c %s "$DATABASE_PATH")
        pv -s "$FILE_SIZE" "$DATABASE_PATH" | mysql ${DATABASE_NAME}

        if [ "$DATABASE_PREFIX" != "false" ]; then
mysql <<EOF
use ${DATABASE_NAME};
UPDATE ${DATABASE_PREFIX}_configuration SET value = 0 WHERE name = 'PS_CSS_THEME_CACHE';
UPDATE ${DATABASE_PREFIX}_configuration SET value = 0 WHERE name = 'PS_JS_THEME_CACHE';
UPDATE ${DATABASE_PREFIX}_configuration SET value = ${SSL} WHERE name = 'PS_SSL_ENABLED';
UPDATE ${DATABASE_PREFIX}_configuration SET value = ${SSL} WHERE name = 'PS_SSL_ENABLED_EVERYWHERE';
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
            file=`mysql -se "SELECT count(*) as count FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='${DATABASE_NAME}' AND TABLE_NAME='${DATABASE_PREFIX}_moloni'" | cut -d \t -f 2`
            if [ $file == "1" ];
            then
                mysql ${DATABASE_NAME} -se "TRUNCATE TABLE ${DATABASE_PREFIX}_moloni;";
            fi

            domains=( $(mysql ${DATABASE_NAME} -se "SELECT domain FROM ${DATABASE_PREFIX}_shop_url") )
            for i in "${domains[@]}"; do
                # domain=$( echo "$i" | perl -pe 's/\.[^.]{2,3}(?:\.[^.]{2,3})?$/.test/s' )
                domain=$( echo "$i" | perl -pe 's/\.[^.]{2,3}(\.red\-agency|\.red\.com)?(\.[^.]{2,3})?$/.test/s' )
                mysql ${DATABASE_NAME} -se "UPDATE ${DATABASE_PREFIX}_shop_url set domain=\"${domain}\", domain_ssl=\"${domain}\" where domain=\"$i\";"
            done
        fi

        echo -e "$BOLD${GREEN}Done!$RESET"
    fi
}
