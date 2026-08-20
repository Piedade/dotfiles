#!/bin/bash

# Like run_remote() (0_utils.sh), but filters out the multi-line "PHP: <date>
# [notice/warning X N][file::line] message ... [array ( ... )]" blocks that
# Elementor writes directly on shutdown when running under PHP 8.4 (e.g.
# atomic-global-styles.php), bypassing display_errors/error_reporting/error_log
# — no PHP flag silences these (tested: neither worked). Kept local to this
# file rather than in run_remote (0_utils.sh) so prestashop.sh/staging.sh/
# site.sh, which don't have this noise, aren't affected.
# The "PHP: " sometimes ends up glued to the end of a real output line (when
# the preceding command, e.g. a wp eval echo, doesn't end in a newline — seen
# as "Email sent successfullyPHP: ..."), so the match has to be by position
# within the line (match()+RSTART), not just by line start (^PHP:). Preserves
# whatever came before "PHP: " on that line, skips through to the closing
# ")]" line, then resumes normal printing from there. Also colorizes specific
# lines: "Email sent successfully" green, "Error:" red (same scheme as
# echo_success/echo_error in 0_utils.sh). PIPESTATUS[0] keeps ssh's exit status
# (not awk's) for the same fail-fast behavior as run_remote.
run_remote_wp() {
    local ACCOUNT="$1"
    local CMD="$2"
    ssh "$ACCOUNT@server" /bin/bash <<-EOF | awk 'function colorize(s,b,g,r,z){b="\033[1m";g="\033[32m";r="\033[31m";z="\033[0m";if(s~/Email sent successfully/)return b g s z;if(s~/^Error:/)return b r s z;return s} {if(!skip){if(match($0,/PHP: [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9] \[/)){pre=substr($0,1,RSTART-1);if(pre!="")print colorize(pre);skip=1;next}print colorize($0);next}if($0~/^\)\]?[ \t]*$/){skip=0};next}'
$CMD
EOF

    local STATUS=${PIPESTATUS[0]}
    if [ $STATUS -ne 0 ]; then
        echo_error "Command failed: $CMD (Exit status: $STATUS)"
        read -r  # mantém terminal aberto
        exit $STATUS
    fi
}

create_wordpress() {
    local ACCOUNT=$1
    local DOMAIN=$2
    local ROOT_DIR=$3
    local DB_NAME=$4
    local ENABLE_MULTI_PHP=$5

    # Se não passou ACCOUNT → fzf local
    if [ -z "$ACCOUNT" ]; then
        ACCOUNT=$(select_account) || { echo_error "Account is required."; return 1; }
    fi

    local _main_domain
    _main_domain=$(select_domain "$ACCOUNT") || _main_domain=""

    if [ $# -eq 0 ]; then
        local _default_domain="$ACCOUNT.dev.red.com.pt"
        read -rp "Domain [$_default_domain]: " DOMAIN
        [ -z "$DOMAIN" ] && DOMAIN="$_default_domain"

        local _default_root_dir="public_html"
        [ "$DOMAIN" != "$_default_domain" ] && [ "$DOMAIN" != "$_main_domain" ] && _default_root_dir="$DOMAIN"
        read -rp "Root directory [$_default_root_dir]: " ROOT_DIR
        [ -z "$ROOT_DIR" ] && ROOT_DIR="$_default_root_dir"

        local _default_db_name="site"
        [ "$DOMAIN" != "$_default_domain" ] && [ "$DOMAIN" != "$_main_domain" ] && _default_db_name="${DOMAIN%%.*}"
        _default_db_name="${_default_db_name//-/_}"
        read -rp "Database name [$_default_db_name]: " DB_NAME
        [ -z "$DB_NAME" ] && DB_NAME="$_default_db_name"

        read -rp "Site title [$ACCOUNT]: " SITE_TITLE
        [ -z "$SITE_TITLE" ] && SITE_TITLE="$ACCOUNT"

        # Mostra a versão de PHP que a conta/domínio já usa, para ajudar a decidir
        # se vale a pena forçar 8.4 via .htaccess (mesma lógica do get_site_files(),
        # em site.sh: whm_resolve_php_version tenta primeiro o .htaccess do domínio
        # e só depois o default da conta via MultiPHP Manager — ver comentário em
        # whm.sh). Best-effort: se o domínio ainda não tiver vhost (ex.: addon
        # domain a ser criado agora), a consulta falha e segue sem info extra.
        local RESULT
        RESULT=$(whm_resolve_php_version "$DOMAIN" "$ACCOUNT" "$ROOT_DIR")
        if [ -n "$RESULT" ]; then
            local CANDIDATE SOURCE RAW
            IFS='|' read -r CANDIDATE SOURCE RAW <<< "$RESULT"
            echo_info "PHP atual do domínio: $RAW (via $SOURCE)"
        else
            # Domínio novo ainda sem vhost (caso mais comum aqui) — não há
            # .htaccess nem entrada no MultiPHP Manager para ele ainda, por isso
            # whm_resolve_php_version falha sempre. Pergunta diretamente à conta
            # via selectorctl (ver nota em project_cpanel_deploy_scripts: MultiPHP
            # é opt-in por domínio, não garantidamente herdado — isto é só
            # indicativo, não o valor real que este domínio novo vai ter).
            local ACCOUNT_PHP
            ACCOUNT_PHP=$(whm_php_version_by_account "$ACCOUNT")
            if [ -n "$ACCOUNT_PHP" ]; then
                echo_info "PHP atual da conta: $ACCOUNT_PHP"
            fi
        fi

        read -rp "Enable MultiPHP? [y/N]: " _multi
        case "$_multi" in
            [Yy]*) ENABLE_MULTI_PHP="yes" ;;
            *) ENABLE_MULTI_PHP="" ;;
        esac
    else
        [ -z "$DOMAIN" ] && DOMAIN="$ACCOUNT.dev.red.com.pt"
        if [ -z "$ROOT_DIR" ]; then
            if [ "$DOMAIN" = "$ACCOUNT.dev.red.com.pt" ] || [ "$DOMAIN" = "$_main_domain" ]; then
                ROOT_DIR="public_html"
            else
                ROOT_DIR="$DOMAIN"
            fi
        fi
        if [ -z "$DB_NAME" ]; then
            if [ "$DOMAIN" = "$ACCOUNT.dev.red.com.pt" ] || [ "$DOMAIN" = "$_main_domain" ]; then
                DB_NAME="site"
            else
                DB_NAME="${DOMAIN%%.*}"
            fi
        fi
        [ -z "$SITE_TITLE" ] && SITE_TITLE="$ACCOUNT"
    fi

    # Validate DB_NAME: replace hyphens and enforce 16-char limit
    if [[ "$DB_NAME" == *-* ]]; then
        local _db_name_clean="${DB_NAME//-/_}"
        echo_error "DB_NAME '$DB_NAME' contains hyphens. Converting to '$_db_name_clean'."
        DB_NAME="$_db_name_clean"
    fi
    if [ ${#DB_NAME} -gt 16 ]; then
        local _db_name_truncated="${DB_NAME:0:16}"
        echo_error "DB_NAME '$DB_NAME' exceeds 16 characters. Truncating to '$_db_name_truncated'."
        DB_NAME="$_db_name_truncated"
    fi

    # Check domain ownership so the confirmation shows what will happen to it
    local DOMAIN_OWNER
    DOMAIN_OWNER=$(whm_account_by_domain "$DOMAIN")
    local DOMAIN_STATUS
    if [ -z "$DOMAIN_OWNER" ]; then
        DOMAIN_STATUS="will be created"
    elif [ "$DOMAIN_OWNER" != "$ACCOUNT" ]; then
        echo_error "Domain $DOMAIN already belongs to another account ($DOMAIN_OWNER). Aborting."
        return 1
    else
        DOMAIN_STATUS="already exists for this account"
    fi

    # Confirmation to the user that the variables are correct
    echo_info "Account: $ACCOUNT"
    echo_info "Domain: $DOMAIN ($DOMAIN_STATUS)"
    echo_info "Root: ~/$ROOT_DIR"
    echo_info "Database: $DB_NAME"
    if [ -n "$ENABLE_MULTI_PHP" ]; then
        echo_info "Enable MultiPHP: $ENABLE_MULTI_PHP"
    fi

    # Ask the user for confirmation if the variables are correct
    read -rp "Do you want to continue? [y/N]: " answer
    case "$answer" in
        [Yy]* )
            echo "Continuing..."
            ;;
        * )
            echo_error "Operation cancelled."
            return 1
            ;;
    esac


    # Check shell access
    check_shell_access "$ACCOUNT" 1
    case $? in
        1)
            # User exists but no shell → ask if should activate
            echo "Activating shell access..."
            add_shell_access "$ACCOUNT" || { echo_error "Failed to activate shell"; return; }
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

    setup_ssh_key "$ACCOUNT"

    # Abort early rather than hitting "wp core download" refusing to run on top of an existing
    # install (which would kill the whole session via run_remote's exit-on-failure) or generating
    # a fresh password that won't match an existing DB user's real one further down the line.
    if remote_file_exists "$ACCOUNT" "$ROOT_DIR/wp-config.php"; then
        echo_error "~/$ROOT_DIR already has an installed WordPress (wp-config.php found). Aborting."
        return 1
    fi
    if mysql_database_exists "$ACCOUNT" "${ACCOUNT}_${DB_NAME}"; then
        echo_error "Database ${ACCOUNT}_${DB_NAME} already exists. Aborting."
        return 1
    fi
    if mysql_user_exists "$ACCOUNT" "${ACCOUNT}_${DB_NAME}"; then
        echo_error "MySQL user ${ACCOUNT}_${DB_NAME} already exists. Aborting."
        return 1
    fi

    if [ -z "$DOMAIN_OWNER" ]; then
        # Este servidor não tem o módulo AddonDomain (nem em uapi nem em cpapi2).
        # Uma addon domain é, por baixo, um subdomínio interno com docroot próprio +
        # o domínio real "estacionado" (parked) nesse vhost — feito ao nível do WHM (root).
        if [ -z "$_main_domain" ]; then
            echo_error "Não consegui determinar o domínio principal de '$ACCOUNT' para criar '$DOMAIN'."
            return 1
        fi

        local SUBDOMAIN="${DOMAIN%%.*}"
        local INTERNAL_SUBDOMAIN="${SUBDOMAIN}.${_main_domain}"

        echo_info "Creating internal subdomain $INTERNAL_SUBDOMAIN..."
        ssh "$SERVER" "whmapi1 create_subdomain domain='${INTERNAL_SUBDOMAIN}' document_root='${ROOT_DIR}'" \
            || { echo_error "Falha a criar o subdomínio interno para '$DOMAIN'."; return 1; }

        if [ "$DOMAIN" != "$INTERNAL_SUBDOMAIN" ]; then
            echo_info "Creating $DOMAIN as addon domain (parked em $INTERNAL_SUBDOMAIN)..."
            ssh "$SERVER" "whmapi1 create_parked_domain_for_user domain='${DOMAIN}' username='${ACCOUNT}' web_vhost_domain='${INTERNAL_SUBDOMAIN}'" \
                || { echo_error "Falha a associar o domínio '$DOMAIN'."; return 1; }
        fi
    fi

    local DB_PASS=$(gen_pass)
    local WP_ADMIN_PASS=$(gen_pass)
    local EMAIL_PASS=$(gen_pass)
    local WP_BIN="/opt/alt/php84/usr/bin/php -d memory_limit=-1 /usr/local/bin/wp"

    if [ "$ENABLE_MULTI_PHP" = "yes" ] || [ "$ENABLE_MULTI_PHP" = "true" ]; then
        echo_info "MultiPHP enabled: skipping account-wide default (this domain forces 8.4 via .htaccess)."
    else
        echo_info "Setting PHP version to 8.4..."
        run_remote_wp "$ACCOUNT" "selectorctl --interpreter=php --set-user-current=8.4"
    fi

    echo_info "Checking required PHP extensions..."
    check_php_extensions "$ACCOUNT" "/opt/alt/php84/usr/bin/php" \
        curl dom fileinfo gd json mbstring mysqli openssl xml zip \
        || return 1

    echo_info "Creating database and user..."
    # run_remote_wp "$ACCOUNT" "uapi Mysql list_users"
    run_remote_wp "$ACCOUNT" "uapi Mysql create_database name='${ACCOUNT}_${DB_NAME}'"
    run_remote_wp "$ACCOUNT" "uapi Mysql create_user name='${ACCOUNT}_${DB_NAME}' password='${DB_PASS}'"
    run_remote_wp "$ACCOUNT" "uapi Mysql set_privileges_on_database user='${ACCOUNT}_${DB_NAME}' database='${ACCOUNT}_${DB_NAME}' privileges='ALL PRIVILEGES'"


    echo_info "Creating email..."
    run_remote_wp "$ACCOUNT" "uapi Email add_pop email='noreply@${DOMAIN}' password='${EMAIL_PASS}'"
    run_remote_wp "$ACCOUNT" "uapi Email suspend_incoming email='noreply@${DOMAIN}'"


    # NginxCaching não tem uma função UAPI de "status" (só clear/disable/enable/
    # reset_cache_config), mas o estado fica em /var/cpanel/userdata/<conta>/
    # nginx-cache.json ({"enabled": true|false}) — se já estiver false, poupa a
    # chamada UAPI (lenta) que iria de qualquer forma re-desativar algo já
    # desativado. Usa ssh direto, não run_remote_wp: um grep "não encontrado" é
    # um resultado esperado aqui (ficheiro pode não existir), não uma falha real.
    if ssh "${ACCOUNT}@server" "grep -q '\"enabled\"[[:space:]]*:[[:space:]]*false' /var/cpanel/userdata/${ACCOUNT}/nginx-cache.json 2>/dev/null"; then
        echo_info "Nginx cache already disabled."
    else
        echo_info "Disable Nginx cache..."
        run_remote_wp "$ACCOUNT" "uapi NginxCaching disable_cache"
    fi


    echo_info "Creating .htaccess..."
    local HTACCESS_CONTENT=""

    HTACCESS_CONTENT+="# http to https
RewriteEngine On
RewriteCond %{SERVER_PORT} 80
RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]

# www to non-www
RewriteCond %{HTTP_HOST} ^www\.(.*)$ [NC]
RewriteRule ^(.*)$ http://%1%{REQUEST_URI} [R=301,QSA,NC,L]

# Block WordPress xmlrpc.php requests
<Files xmlrpc.php>
order deny,allow
deny from all
</Files>

# Block wp-config.php
<files wp-config.php>
order allow,deny
deny from all
</files>

# Block the include-only files.
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^wp-admin/includes/ - [F,L]
RewriteRule !^wp-includes/ - [S=3]
RewriteRule ^wp-includes/[^/]+\.php$ - [F,L]
RewriteRule ^wp-includes/js/tinymce/langs/.+\.php - [F,L]
RewriteRule ^wp-includes/theme-compat/ - [F,L]
</IfModule>"

    if [ "$ENABLE_MULTI_PHP" = "yes" ] || [ "$ENABLE_MULTI_PHP" = "true" ]; then
        HTACCESS_CONTENT+="

# php -- BEGIN cPanel-generated handler, do not edit
# Set the “alt-php84” package as the default “PHP” programming language.
<IfModule mime_module>
  AddHandler application/x-httpd-alt-php84___lsphp .php .php8 .phtml
</IfModule>
# php -- END cPanel-generated handler, do not edit
"
    fi

HTACCESS_CONTENT+="

# BEGIN cPanel-generated php ini directives, do not edit
<IfModule php8_module>
   php_flag display_errors Off
   php_value max_execution_time 30
   php_value max_input_time 60
   php_value max_input_vars 1000
   php_value memory_limit 512M
   php_value post_max_size 32M
   php_value session.gc_maxlifetime 1440
   php_value session.save_path \"/var/cpanel/php/sessions/ea-php84\"
   php_value upload_max_filesize 16M
   php_flag zlib.output_compression Off
</IfModule>
<IfModule lsapi_module>
   php_flag display_errors Off
   php_value max_execution_time 30
   php_value max_input_time 60
   php_value max_input_vars 1000
   php_value memory_limit 512M
   php_value post_max_size 32M
   php_value session.gc_maxlifetime 1440
   php_value session.save_path \"/var/cpanel/php/sessions/ea-php84\"
   php_value upload_max_filesize 16M
   php_flag zlib.output_compression Off
</IfModule>
# END cPanel-generated php ini directives, do not edit"

    run_remote_wp "$ACCOUNT" "cat > ~/$ROOT_DIR/.htaccess <<EOL
$HTACCESS_CONTENT
EOL"

    echo_info "Installing WordPress..."
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN core download --locale='pt_PT'"
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN config create --dbname='${ACCOUNT}_${DB_NAME}' --dbuser='${ACCOUNT}_${DB_NAME}' --dbpass='${DB_PASS}'"
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN core install --url='https://${DOMAIN}' --title='${SITE_TITLE}' --admin_user='redpost' --admin_password='${WP_ADMIN_PASS}' --admin_email='webmaster@redpost.pt' --skip-email"

    echo_info "Setting permalink structure..."
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN rewrite structure '/%postname%/' --hard"

    echo_info "Deleting default post..."
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN post delete 1 --force"

    echo_info "Applying security settings..."
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN config shuffle-salts"
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN config set DISALLOW_FILE_EDIT true --raw"
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN config set WP_MEMORY_LIMIT 512M"


    echo_info "Disabling plugins..."
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN plugin install disable-xml-rpc disable-json-api simple-smtp elementor --activate"


    echo_info "Mail config..."
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN config set SMTP_HOST 'localhost'"
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN config set SMTP_AUTH 1 --raw"
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN config set SMTP_USER 'noreply@${DOMAIN}'"
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN config set SMTP_PASS '${EMAIL_PASS}'"
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN config set SMTP_FROM 'noreply@${DOMAIN}'"
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN config set SMTP_FROMNAME '${ACCOUNT}'"


    echo_info "Cleaning default plugins/themes..."
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN plugin delete hello akismet"
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN theme install hello-elementor --activate"
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN theme delete twentytwentytwo twentytwentythree twentytwentyfour twentytwentyfive"
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && $WP_BIN config set WP_DEFAULT_THEME hello-elementor"


    # Domínios fora dos padrões dev/staging (ver is_noindex_domain, em whm.sh) não
    # apanham o header X-Robots-Tag noindex do Apache — por omissão ficariam
    # publicamente visíveis/indexáveis assim que o DNS aponte para cá, mesmo que o
    # site ainda esteja a ser construído. Ativa o modo de manutenção do Elementor
    # com uma página mínima "Em manutenção" (bloqueia visitantes, exceto admins
    # logados); se o Elementor não estiver ativo por algum motivo, cai para
    # blog_public=0 (só desencoraja indexação, não bloqueia o acesso).
    # Nota: usa ssh direto em vez de run_remote — run_remote faz "exit" de toda a
    # sessão em caso de falha (ver comentário mais acima sobre "wp core download"),
    # o que não serve para um passo best-effort com fallback.
    if ! is_noindex_domain "$DOMAIN"; then
        echo_info "'$DOMAIN' não é um domínio dev/staging — a configurar visibilidade..."

        if ssh "${ACCOUNT}@server" "cd ~/$ROOT_DIR && $WP_BIN plugin is-active elementor" &>/dev/null; then
            # --porcelain só devia imprimir o ID, mas neste servidor os avisos de
            # deprecation do PHP 8.4 (ex.: Elementor atomic-global-styles.php) vão
            # para o stdout do CLI, não stderr — por isso filtra-se só a linha
            # puramente numérica em vez de confiar na saída toda.
            local PAGE_ID
            PAGE_ID=$(ssh "${ACCOUNT}@server" "cd ~/$ROOT_DIR && $WP_BIN post create --post_type=elementor_library --post_title='Em manutenção' --post_status=publish --porcelain" 2>/dev/null | grep -E '^[0-9]+$' | head -n1)

            if [[ "$PAGE_ID" =~ ^[0-9]+$ ]]; then
                # Título "Em manutenção" só serve para identificar a página na lista
                # do Elementor — conteúdo fica vazio de propósito (sem heading/texto).
                ssh "${ACCOUNT}@server" "
                    cd ~/$ROOT_DIR &&
                    $WP_BIN post meta update '$PAGE_ID' _elementor_template_type page &&
                    $WP_BIN post meta update '$PAGE_ID' _elementor_edit_mode builder &&
                    $WP_BIN post meta update '$PAGE_ID' _elementor_data '[]' &&
                    $WP_BIN option update elementor_maintenance_mode_template_id '$PAGE_ID' &&
                    $WP_BIN option update elementor_maintenance_mode_mode maintenance
                " &>/dev/null
                if [ $? -eq 0 ]; then
                    echo_info "Elementor maintenance mode ativado (página ID $PAGE_ID)."
                else
                    echo_error "Falha a configurar a página de manutenção do Elementor — a usar blog_public=0 como fallback."
                    ssh "${ACCOUNT}@server" "cd ~/$ROOT_DIR && $WP_BIN option update blog_public 0" &>/dev/null
                fi
            else
                echo_error "Falha a criar a página de manutenção do Elementor — a usar blog_public=0 como fallback."
                ssh "${ACCOUNT}@server" "cd ~/$ROOT_DIR && $WP_BIN option update blog_public 0" &>/dev/null
            fi
        else
            echo_info "Elementor não está ativo — a usar blog_public=0 como fallback."
            ssh "${ACCOUNT}@server" "cd ~/$ROOT_DIR && $WP_BIN option update blog_public 0" &>/dev/null
        fi
    fi


    echo_info "Setting permissions..."
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && find . -type d -exec chmod 755 {} \;"
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && find . -type f -exec chmod 644 {} \;"
    run_remote_wp "$ACCOUNT" "cd ~/$ROOT_DIR && chmod 400 wp-config.php"

    echo_info "Testing email..."
    run_remote_wp "$ACCOUNT" "
        cd ~/$ROOT_DIR && $WP_BIN eval \"
            if (wp_mail('webmaster@redpost.pt', 'Email Test from ${ACCOUNT}', 'This is a test email from your new WordPress site for https://${DOMAIN} (${ACCOUNT}).')) {
                echo 'Email sent successfully';
            } else {
                echo 'Failed to send email';
            }
        \"
    "

    echo "🌍 Site: https://$DOMAIN/wp-admin/admin.php?page=elementor-connect-account"
    echo
    echo "https://$DOMAIN"
    echo "user: redpost"
    echo "pass: $WP_ADMIN_PASS"
    echo

    echo "🗄️ Database:"
    echo "User: ${ACCOUNT}_${DB_NAME}"
    echo "Pass: $DB_PASS"

    echo "📧 Email:"
    echo "noreply@$DOMAIN"
    echo "Pass: $EMAIL_PASS"
}
