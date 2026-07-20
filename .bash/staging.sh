#!/bin/bash

# Clona um site de produção para um ambiente de staging (staging.<dominio>):
# rsync dos ficheiros + duplicação da base de dados. Corre localmente,
# ligando por SSH com o user cPanel do próprio domínio (nunca root),
# exatamente como um humano faria manualmente.
#
# Uso: clone_to_staging <dominio> [pasta_producao] [bd_producao]
# A conta cPanel é sempre derivada do domínio (whm_account_by_domain), nunca pedida à parte.
#
# IMPORTANTE (segurança): em todo o fluxo, a produção é só LIDA (mysqldump,
# rsync como origem). Todas as operações destrutivas (DROP DATABASE, rsync
# --delete) só podem apontar para variáveis STAGING_*, nunca para DOMAIN/
# ROOT_DIR/DB_NAME (produção). Há um assert explícito antes do DROP.
clone_to_staging() {
    local DOMAIN=$1
    local ROOT_DIR=$2
    local DB_NAME=$3

    if [ -z "$DOMAIN" ]; then
        DOMAIN=$(select_domain_global '^staging\.') || { echo_error "Domain is required."; return 1; }
    fi

    if [[ "$DOMAIN" == staging.* ]]; then
        echo_error "'$DOMAIN' já parece ser um staging. Não se clona um staging para outro staging."
        return 1
    fi

    # A conta cPanel é sempre derivada do domínio, nunca pedida à parte
    # (evita o caso de indicares um domínio e uma conta que não batem certo).
    local ACCOUNT
    ACCOUNT=$(whm_account_by_domain "$DOMAIN")
    if [ -z "$ACCOUNT" ]; then
        echo_error "Domínio '$DOMAIN' não encontrado no servidor."
        return 1
    fi
    echo_info "Conta cPanel: $ACCOUNT (dona de $DOMAIN)"

    local STAGING_DOMAIN="staging.${DOMAIN}"

    # Pasta de produção: vai buscar o documentroot real do domínio ao WHM
    # (o domínio já está ligado a uma pasta em concreto; não se adivinha).
    if [ -z "$ROOT_DIR" ]; then
        local DOC_ROOT
        DOC_ROOT=$(whm_docroot_by_domain "$DOMAIN")
        if [ -n "$DOC_ROOT" ] && [[ "$DOC_ROOT" == "/home/${ACCOUNT}/"* ]]; then
            ROOT_DIR="${DOC_ROOT#/home/${ACCOUNT}/}"
            echo_success "Pasta de produção detetada: ~/$ROOT_DIR"
        else
            echo_error "Não consegui determinar o documentroot de '$DOMAIN' via WHM."
            read -rp "Pasta de produção (ex: public_html): " ROOT_DIR
        fi
    fi
    # Sanitização: nunca aceitar caminhos vazios/absolutos/relativos perigosos
    if [ -z "$ROOT_DIR" ] || [[ "$ROOT_DIR" == /* ]] || [[ "$ROOT_DIR" == *".."* ]]; then
        echo_error "Pasta de produção inválida: '$ROOT_DIR'."
        return 1
    fi

    local STAGING_ROOT_DIR="$STAGING_DOMAIN"
    if [[ "$STAGING_ROOT_DIR" == "$ROOT_DIR"/* ]] || [[ "$ROOT_DIR" == "$STAGING_ROOT_DIR"/* ]]; then
        echo_error "Pasta de staging '$STAGING_ROOT_DIR' colide com a de produção '$ROOT_DIR'. A abortar."
        return 1
    fi

    # Tenta auto-detetar a BD de produção a partir da configuração, se não foi passada
    if [ -z "$DB_NAME" ]; then
        echo_info "A tentar detetar a base de dados a partir da configuração..."
        DB_NAME=$(ssh "${ACCOUNT}@server" "
            grep -oP \"(?<=define\\('DB_NAME', ')[^']+\" ~/${ROOT_DIR}/wp-config.php 2>/dev/null ||
            grep -oP \"(?<=define\\('_DB_NAME_', ')[^']+\" ~/${ROOT_DIR}/config/settings.inc.php 2>/dev/null ||
            grep -oP \"(?<='database_name' => ')[^']+\" ~/${ROOT_DIR}/app/config/parameters.php 2>/dev/null ||
            grep -oP \"(?<=^DB_DATABASE=).+\" ~/${ROOT_DIR}/.env 2>/dev/null
        " 2>/dev/null | head -n1)

        if [ -n "$DB_NAME" ]; then
            echo_success "BD detetada: $DB_NAME"
        else
            read -rp "Nome da base de dados de produção (ex: ${ACCOUNT}_site): " DB_NAME
        fi
    fi
    if [ -z "$DB_NAME" ]; then
        echo_error "Base de dados de produção é obrigatória."
        return 1
    fi

    # Nome da BD de staging: mesmo sufixo + _stg, respeitando o limite usado no resto dos scripts
    local DB_SUFFIX="${DB_NAME#${ACCOUNT}_}"
    local STAGING_SUFFIX="${DB_SUFFIX}_stg"
    if [ ${#STAGING_SUFFIX} -gt 16 ]; then
        STAGING_SUFFIX="${DB_SUFFIX:0:12}_stg"
    fi
    local STAGING_DB_NAME="${ACCOUNT}_${STAGING_SUFFIX}"

    # Guarda-redes (SAFETY): staging nunca pode coincidir com produção em nenhum eixo
    if [ "$STAGING_DOMAIN" = "$DOMAIN" ] || [ "$STAGING_ROOT_DIR" = "$ROOT_DIR" ] || [ "$STAGING_DB_NAME" = "$DB_NAME" ]; then
        echo_error "SAFETY: staging resolveu para o mesmo valor que produção. A abortar."
        return 1
    fi

    echo
    echo_info "======================================================"
    echo_info " CLONE PARA STAGING — conta: $ACCOUNT"
    echo_info "======================================================"
    echo_info "PRODUÇÃO (só leitura, nunca modificada):"
    echo_info "  Domínio: $DOMAIN"
    echo_info "  Pasta:   ~/$ROOT_DIR"
    echo_info "  BD:      $DB_NAME"
    echo
    echo_success "STAGING (vai ser sobrescrito):"
    echo_success "  Domínio: $STAGING_DOMAIN"
    echo_success "  Pasta:   ~/$STAGING_ROOT_DIR"
    echo_success "  BD:      $STAGING_DB_NAME"
    echo_info "======================================================"
    echo

    local CONFIRM
    read -rp "Continuar? [y/N]: " CONFIRM
    case "$CONFIRM" in
        [Yy]*) ;;
        *) echo_error "Operação cancelada."; return 1 ;;
    esac

    # Shell + SSH key da conta (mesmo fluxo do server.sh/create_wordpress)
    check_shell_access "$ACCOUNT" 1
    case $? in
        1)
            echo_info "Ativando shell access..."
            add_shell_access "$ACCOUNT" || { echo_error "Falha a ativar shell."; return 1; }
            ;;
        2) echo_error "$ACCOUNT não encontrada."; return 1 ;;
        3) echo_error "$ACCOUNT tem um shell invulgar. Verifica manualmente."; return 1 ;;
    esac
    setup_ssh_key "$ACCOUNT"

    # staging.<dominio> é um subdomínio de $DOMAIN (só cria se ainda não existir)
    local STAGING_OWNER
    STAGING_OWNER=$(whm_account_by_domain "$STAGING_DOMAIN")
    if [ -z "$STAGING_OWNER" ]; then
        echo_info "A criar subdomínio $STAGING_DOMAIN..."
        run_remote "$ACCOUNT" "uapi SubDomain addsubdomain domain='staging' rootdomain='${DOMAIN}' dir='${STAGING_ROOT_DIR}'"
    elif [ "$STAGING_OWNER" != "$ACCOUNT" ]; then
        echo_error "$STAGING_DOMAIN já existe e pertence a outra conta ($STAGING_OWNER). A abortar."
        return 1
    else
        echo_info "$STAGING_DOMAIN já existe para esta conta, a reutilizar."
    fi

    # --- Ficheiros: preview (dry-run) antes de qualquer alteração real ---
    # O ficheiro de configuração (wp-config.php / settings.inc.php / parameters.php) e o
    # .htaccess ficam de fora do rsync: depois de existirem uma vez em staging, não devem
    # ser pisados pela cópia de produção nos refreshes seguintes (senão perdíamos sempre a
    # ligação à BD de staging, ou quaisquer regras próprias do .htaccess de staging).
    # Pastas de cache/logs que só desperdiçam tempo e espaço a copiar (regeneram-se sozinhas)
    local RSYNC_EXCLUDES="--exclude=/wp-config.php --exclude=/config/settings.inc.php --exclude=/app/config/parameters.php --exclude=/.env --exclude=/.htaccess"
    RSYNC_EXCLUDES="$RSYNC_EXCLUDES --exclude=/cache/ --exclude=/var/cache/ --exclude=/var/logs/ --exclude=/wp-content/cache/"

    echo_info "A calcular alterações de ficheiros (dry-run)..."
    local DRY_OUTPUT
    DRY_OUTPUT=$(ssh "${ACCOUNT}@server" "rsync -an --itemize-changes --delete $RSYNC_EXCLUDES '/home/${ACCOUNT}/${ROOT_DIR}/' '/home/${ACCOUNT}/${STAGING_ROOT_DIR}/' 2>&1")
    local CHANGE_COUNT
    CHANGE_COUNT=$(echo "$DRY_OUTPUT" | grep -vE '^(sending incremental file list$|sent .* bytes|total size is)' | grep -c .)
    echo "$DRY_OUTPUT" | tail -n 15
    echo_info "Alterações previstas: $CHANGE_COUNT (origem: ~/$ROOT_DIR -> destino: ~/$STAGING_ROOT_DIR)"

    read -rp "Aplicar rsync real dos ficheiros? [y/N]: " answer
    case "$answer" in
        [Yy]*) ;;
        *) echo_error "Operação cancelada."; return 1 ;;
    esac

    echo_info "A sincronizar ficheiros..."
    ssh -t "${ACCOUNT}@server" "rsync -a --delete --info=progress2 $RSYNC_EXCLUDES '/home/${ACCOUNT}/${ROOT_DIR}/' '/home/${ACCOUNT}/${STAGING_ROOT_DIR}/'" \
        || { echo_error "rsync falhou."; return 1; }

    # .htaccess: só semeia a partir da produção se ainda não existir em staging (excluído do rsync acima)
    ssh "${ACCOUNT}@server" "
        if [ ! -f ~/${STAGING_ROOT_DIR}/.htaccess ] && [ -f ~/${ROOT_DIR}/.htaccess ]; then
            cp ~/${ROOT_DIR}/.htaccess ~/${STAGING_ROOT_DIR}/.htaccess
        fi
    "

    # --- Ribbon "Versão de demonstração" para distinguir staging de produção ---
    # auto_append_file em vez de tocar nos templates da app: o rsync --delete acima faria
    # -delete + repor esses ficheiros a partir da produção em cada refresh, apagando o ribbon.
    # Ficheiro estático (sem tags PHP) e a diretiva no .htaccess (excluído do rsync, persiste
    # entre refreshes) — por isso a diretiva só é acrescentada se ainda não lá estiver.
    # auto_append_file corre em TODO pedido PHP, incluindo endpoints AJAX/API que devolvem
    # JSON (ex: instalação de módulos) — sem este check, o ribbon era anexado a seguir ao
    # JSON e partia o parse no browser. Content-Type não chega: alguns endpoints AJAX
    # devolvem JSON com um Content-Type: text/html incorreto (ex: autoupgrade), o que já
    # partiu o parse mesmo com o check de Content-Type. Sec-Fetch-Dest é o sinal real: só
    # o browser o define, e só como "document" numa navegação de topo real — nunca em
    # XHR/fetch, e o servidor/app não o consegue falsificar.
    local RIBBON_FILE="_staging_ribbon.php"
    ssh "${ACCOUNT}@server" "cat > ~/${STAGING_ROOT_DIR}/${RIBBON_FILE}" <<'PHPEOF'
<?php
if (($_SERVER['HTTP_SEC_FETCH_DEST'] ?? '') === 'document'):
?>
<div class="staging-ribbon">Versão de demonstração</div>
<style>
.staging-ribbon {
    width: 22rem;
    padding: 16px;
    position: fixed;
    text-align: center;
    color: #ffffff;
    z-index: 999999999999;
    top: 4rem;
    right: -5.5rem;
    transform: rotate(45deg);
    background-color: #ff0044;
    text-transform: uppercase;
    font-size: 1rem;
    pointer-events: none;
}
</style>
<?php endif; ?>
PHPEOF

    if ! ssh "${ACCOUNT}@server" "grep -q 'BEGIN staging ribbon' ~/${STAGING_ROOT_DIR}/.htaccess 2>/dev/null"; then
        echo_info "A adicionar ribbon de staging ao .htaccess..."
        ssh "${ACCOUNT}@server" "cat >> ~/${STAGING_ROOT_DIR}/.htaccess" <<EOL

# BEGIN staging ribbon
<IfModule php8_module>
   php_value auto_append_file "/home/${ACCOUNT}/${STAGING_ROOT_DIR}/${RIBBON_FILE}"
</IfModule>
<IfModule lsapi_module>
   php_value auto_append_file "/home/${ACCOUNT}/${STAGING_ROOT_DIR}/${RIBBON_FILE}"
</IfModule>
# END staging ribbon
EOL
    fi

    # --- Base de dados: assert final antes de qualquer DROP ---
    if [ "$STAGING_DB_NAME" = "$DB_NAME" ]; then
        echo_error "SAFETY: ia fazer DROP na mesma BD de produção. A abortar sem tocar em nada."
        return 1
    fi

    local STAGING_DB_USER="$STAGING_DB_NAME"
    local STAGING_DB_PASS=""
    local CREATE_NEW_USER=1

    local USERS_LIST
    USERS_LIST=$(ssh "${ACCOUNT}@server" "uapi Mysql list_users" 2>/dev/null)
    if echo "$USERS_LIST" | grep -qE "^[[:space:]]*user:[[:space:]]*${STAGING_DB_USER}\$"; then
        CREATE_NEW_USER=0
        echo_info "Utilizador de staging '$STAGING_DB_USER' já existe."
    else
        STAGING_DB_PASS=$(gen_pass)
    fi

    echo_info "A duplicar base de dados ($DB_NAME -> $STAGING_DB_NAME)..."
    # A conta cPanel não tem .my.cnf com acesso MySQL direto (nem devia) — só o que
    # estritamente precisa de acesso direto ao mysql/mysqldump corre como root; a
    # gestão da conta (create_database/create_user/privilégios) continua via uapi na própria conta.
    ssh "$SERVER" "mysql -e \"DROP DATABASE IF EXISTS ${STAGING_DB_NAME};\"" \
        || { echo_error "Falha a apagar a BD de staging anterior."; return 1; }

    local ACCT_SCRIPT
    ACCT_SCRIPT="set -euo pipefail
uapi Mysql create_database name='${STAGING_DB_NAME}' >/dev/null 2>&1 || true"

    if [ "$CREATE_NEW_USER" = "1" ]; then
        ACCT_SCRIPT="$ACCT_SCRIPT
uapi Mysql create_user name='${STAGING_DB_USER}' password='${STAGING_DB_PASS}' >/dev/null"
    fi

    ACCT_SCRIPT="$ACCT_SCRIPT
uapi Mysql set_privileges_on_database user='${STAGING_DB_USER}' database='${STAGING_DB_NAME}' privileges='ALL PRIVILEGES' >/dev/null"

    echo "$ACCT_SCRIPT" | ssh "${ACCOUNT}@server" "bash -s" \
        || { echo_error "Falha a criar a BD/utilizador de staging."; return 1; }

    ssh -t "$SERVER" "mysqldump --single-transaction --quick '${DB_NAME}' | dd status=progress | mysql '${STAGING_DB_NAME}'" \
        || { echo_error "Falha a duplicar os dados da base de dados."; return 1; }

    if [ "$CREATE_NEW_USER" = "1" ]; then
        # Primeira vez para este staging: semeia o config a partir da produção (o rsync
        # ignorou-o de propósito) e aponta-o para a BD/utilizador novos.
        echo_info "A preparar a configuração de staging (utilizador novo: $STAGING_DB_USER)..."
        local CFG_SCRIPT
        CFG_SCRIPT=$(cat <<EOF
set -e
for rel in "wp-config.php" "config/settings.inc.php" "app/config/parameters.php" ".env"; do
    src=~/${ROOT_DIR}/\$rel
    dst=~/${STAGING_ROOT_DIR}/\$rel
    if [ -f "\$src" ]; then
        mkdir -p "\$(dirname "\$dst")"
        cp "\$src" "\$dst"
    fi
done

f=~/${STAGING_ROOT_DIR}/wp-config.php
if [ -f "\$f" ]; then
    sed -i "s/define( *'DB_NAME', *'${DB_NAME}'/define( 'DB_NAME', '${STAGING_DB_NAME}'/" "\$f"
    sed -i "s/define( *'DB_USER', *'[^']*'/define( 'DB_USER', '${STAGING_DB_USER}'/" "\$f"
    sed -i "s/define( *'DB_PASSWORD', *'[^']*'/define( 'DB_PASSWORD', '${STAGING_DB_PASS}'/" "\$f"
fi

f=~/${STAGING_ROOT_DIR}/config/settings.inc.php
if [ -f "\$f" ]; then
    sed -i "s/define('_DB_NAME_', *'${DB_NAME}')/define('_DB_NAME_', '${STAGING_DB_NAME}')/" "\$f"
    sed -i "s/define('_DB_USER_', *'[^']*')/define('_DB_USER_', '${STAGING_DB_USER}')/" "\$f"
    sed -i "s/define('_DB_PASSWD_', *'[^']*')/define('_DB_PASSWD_', '${STAGING_DB_PASS}')/" "\$f"
fi

f=~/${STAGING_ROOT_DIR}/app/config/parameters.php
if [ -f "\$f" ]; then
    sed -i "s/'database_name' => '${DB_NAME}'/'database_name' => '${STAGING_DB_NAME}'/" "\$f"
    sed -i "s/'database_user' => '[^']*'/'database_user' => '${STAGING_DB_USER}'/" "\$f"
    sed -i "s/'database_password' => '[^']*'/'database_password' => '${STAGING_DB_PASS}'/" "\$f"
fi

f=~/${STAGING_ROOT_DIR}/.env
if [ -f "\$f" ]; then
    sed -i "s/^DB_DATABASE=.*/DB_DATABASE=${STAGING_DB_NAME}/" "\$f"
    sed -i "s/^DB_USERNAME=.*/DB_USERNAME=${STAGING_DB_USER}/" "\$f"
    sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${STAGING_DB_PASS}/" "\$f"
fi
EOF
)
        echo "$CFG_SCRIPT" | ssh "${ACCOUNT}@server" "bash -s" \
            || echo_error "Não consegui preparar a configuração de staging — verifica manualmente wp-config.php / settings.inc.php / parameters.php."
    else
        # Confia que o config já existente aponta para o utilizador/BD certos; só avisa se não encontrar nenhum.
        if ! ssh "${ACCOUNT}@server" "test -f ~/${STAGING_ROOT_DIR}/wp-config.php -o -f ~/${STAGING_ROOT_DIR}/config/settings.inc.php -o -f ~/${STAGING_ROOT_DIR}/app/config/parameters.php -o -f ~/${STAGING_ROOT_DIR}/.env"; then
            echo_error "O utilizador '$STAGING_DB_USER' já existia mas não encontrei nenhum ficheiro de configuração em staging. Como a password não é recuperável, tens de configurar o ficheiro manualmente."
        fi
    fi

    # --- PrestaShop: muda os URLs guardados na BD para o domínio de staging ---
    local IS_PRESTASHOP=0
    ssh "${ACCOUNT}@server" "test -f ~/${STAGING_ROOT_DIR}/config/settings.inc.php -o -f ~/${STAGING_ROOT_DIR}/app/config/parameters.php" \
        && IS_PRESTASHOP=1

    if [ "$IS_PRESTASHOP" = "1" ]; then
        echo_prestashop "PrestaShop detetado: a atualizar URLs na BD de staging..."
        local PS_PREFIX
        PS_PREFIX=$(cat <<EOF | ssh "$SERVER" "mysql -N -B '${STAGING_DB_NAME}'" 2>/dev/null
SELECT TABLE_NAME FROM information_schema.tables WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME REGEXP '_shop_url\$' LIMIT 1;
EOF
)
        PS_PREFIX="${PS_PREFIX%_shop_url}"

        if [ -z "$PS_PREFIX" ]; then
            echo_error "Não encontrei a tabela *_shop_url na BD de staging; salta atualização de URLs."
        else
            local SQL
            SQL=$(cat <<EOF
UPDATE ${PS_PREFIX}_shop_url SET domain='${STAGING_DOMAIN}', domain_ssl='${STAGING_DOMAIN}';
UPDATE ${PS_PREFIX}_configuration SET value='${STAGING_DOMAIN}' WHERE name IN ('PS_SHOP_DOMAIN','PS_SHOP_DOMAIN_SSL');
UPDATE ${PS_PREFIX}_configuration SET value=0 WHERE name IN ('PS_SMARTY_CACHE','PS_CSS_THEME_CACHE','PS_JS_THEME_CACHE');
UPDATE ${PS_PREFIX}_configuration SET value=NULL WHERE name IN ('PS_MAIL_USER','PS_MAIL_PASSWD','PS_MAIL_SMTP_ENCRYPTION');
UPDATE ${PS_PREFIX}_configuration SET value='localhost' WHERE name='PS_MAIL_SERVER';
EOF
)
            echo "$SQL" | ssh "$SERVER" "mysql '${STAGING_DB_NAME}'" \
                && echo_success "URLs e definições de staging atualizadas (prefixo: ${PS_PREFIX})." \
                || echo_error "Falha ao atualizar URLs do PrestaShop em staging."
        fi
    fi

    # --- WordPress: muda os URLs guardados na BD para o domínio de staging ---
    local IS_WORDPRESS=0
    ssh "${ACCOUNT}@server" "test -f ~/${STAGING_ROOT_DIR}/wp-config.php" \
        && IS_WORDPRESS=1

    if [ "$IS_WORDPRESS" = "1" ]; then
        echo_wordpress "WordPress detetado: a atualizar URLs na BD de staging..."
        local WP_BIN="/opt/alt/php84/usr/bin/php -d memory_limit=-1 /usr/local/bin/wp"
        ssh "${ACCOUNT}@server" "
            cd ~/${STAGING_ROOT_DIR} &&
            $WP_BIN search-replace 'https://${DOMAIN}' 'https://${STAGING_DOMAIN}' --all-tables --precise --skip-columns=guid &&
            $WP_BIN search-replace 'http://${DOMAIN}' 'https://${STAGING_DOMAIN}' --all-tables --precise --skip-columns=guid
        " \
            && echo_success "URLs de staging atualizados no WordPress." \
            || echo_error "Falha ao atualizar URLs do WordPress em staging."
    fi

    # --- Laravel: aponta APP_URL para o domínio de staging ---
    local IS_LARAVEL=0
    ssh "${ACCOUNT}@server" "[ -f ~/${STAGING_ROOT_DIR}/artisan ] && [ -f ~/${STAGING_ROOT_DIR}/.env ]" \
        && IS_LARAVEL=1

    if [ "$IS_LARAVEL" = "1" ]; then
        echo_laravel "Laravel detetado: a atualizar APP_URL em staging..."
        ssh "${ACCOUNT}@server" "
            f=~/${STAGING_ROOT_DIR}/.env
            if grep -q '^APP_URL=' \"\$f\"; then
                sed -i \"s#^APP_URL=.*#APP_URL=https://${STAGING_DOMAIN}#\" \"\$f\"
            else
                echo 'APP_URL=https://${STAGING_DOMAIN}' >> \"\$f\"
            fi
            cd ~/${STAGING_ROOT_DIR} && /opt/alt/php84/usr/bin/php artisan config:clear 2>/dev/null || true
        " \
            && echo_success "APP_URL de staging atualizado no Laravel." \
            || echo_error "Falha ao atualizar APP_URL do Laravel em staging (verifica manualmente)."
    fi

    echo
    echo_success "Clone para staging concluído!"
    echo "🌍 Staging: https://$STAGING_DOMAIN"
    echo "📁 Pasta:   ~/$STAGING_ROOT_DIR"
    echo "🗄️  BD:      $STAGING_DB_NAME"
    echo "👤 DB User: $STAGING_DB_USER"
    if [ "$CREATE_NEW_USER" = "1" ]; then
        echo "🔑 DB Pass: $STAGING_DB_PASS"
    else
        echo "🔑 DB Pass: (utilizador reutilizado, password inalterada)"
    fi
    echo
}
