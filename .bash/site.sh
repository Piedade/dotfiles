#!/bin/bash

# Atualiza um site LOCAL (ex: /var/www/redpost.test) a partir do site de
# PRODUÇÃO no cPanel (ex: redpost.pt): só os FICHEIROS, via rsync. Corre
# localmente, ligando por SSH com o user cPanel do próprio domínio (nunca
# root, mesmo princípio do clone_to_staging em staging.sh).
#
# Uso: get_site_files <dominio_producao> [dominio_local]
# dominio_local (default: <dominio_producao sem TLD>.test, ex: redpost.test)
#
# A pasta local é sempre /var/www/<dominio_local>. Se o vhost local ainda não
# existir, cria-o automaticamente via create_domain (apache.sh: pasta em
# /var/www, vhost Apache, certificado mkcert).
#
# A base de dados NÃO é duplicada automaticamente — no final, o script mostra
# o comando para o fazeres manualmente: get_database <bd_produção> (mysql.sh),
# que já trata PrestaShop/WordPress e importa localmente com o mesmo nome.
#
# Plataformas suportadas na configuração local (wp-config.php, settings.inc.php,
# parameters.php/yml, .env do Laravel): user/password/host da BD apontados para o
# mysql local; .env do Laravel tem ainda o APP_URL reescrito para o domínio local
# (não há BD envolvida nisso, ao contrário do WordPress/PrestaShop).
#
# MySQL local: assume utilizador root com password "admin".
#
# IMPORTANTE (segurança): em todo o fluxo, a produção é só LIDA (rsync como
# origem). Todas as operações destrutivas (rsync --delete) só podem apontar
# para variáveis LOCAL_*, nunca para DOMAIN/ROOT_DIR (produção).
get_site_files() {
    local DOMAIN=$1
    local LOCAL_DOMAIN=$2

    if [ -z "$DOMAIN" ]; then
        DOMAIN=$(select_domain_global) || { echo_error "Domain is required."; return 1; }
    fi

    if [[ "$DOMAIN" == *.test ]]; then
        echo_error "'$DOMAIN' parece já ser um domínio local. Indica o domínio de PRODUÇÃO (ex: redpost.pt)."
        return 1
    fi

    # A conta cPanel é sempre derivada do domínio, nunca pedida à parte.
    local ACCOUNT
    ACCOUNT=$(whm_account_by_domain "$DOMAIN")
    if [ -z "$ACCOUNT" ]; then
        echo_error "Domínio '$DOMAIN' não encontrado no servidor."
        return 1
    fi
    echo_info "Conta cPanel: $ACCOUNT (dona de $DOMAIN)"

    # Pasta de produção: vai buscar o documentroot real do domínio ao WHM
    # (não se adivinha public_html vs. nome do domínio).
    local ROOT_DIR
    local DOC_ROOT
    DOC_ROOT=$(whm_docroot_by_domain "$DOMAIN")
    if [ -n "$DOC_ROOT" ] && [[ "$DOC_ROOT" == "/home/${ACCOUNT}/"* ]]; then
        ROOT_DIR="${DOC_ROOT#/home/${ACCOUNT}/}"
        echo_success "Pasta de produção detetada: ~/$ROOT_DIR"
    else
        echo_error "Não consegui determinar o documentroot de '$DOMAIN' via WHM."
        read -rp "Pasta de produção (ex: public_html): " ROOT_DIR
    fi
    if [ -z "$ROOT_DIR" ] || [[ "$ROOT_DIR" == /* ]] || [[ "$ROOT_DIR" == *".."* ]]; then
        echo_error "Pasta de produção inválida: '$ROOT_DIR'."
        return 1
    fi

    # Domínio local: mesmo nome, TLD trocado por .test (ex: redpost.pt -> redpost.test)
    [ -z "$LOCAL_DOMAIN" ] && LOCAL_DOMAIN="${DOMAIN%.*}.test"
    # Guarda-redes: LOCAL_DIR é construído diretamente a partir disto e depois alvo de
    # rsync --delete, por isso não pode conter '/' nem '..' (evita sair de /var/www).
    if [[ "$LOCAL_DOMAIN" != *.test ]] || [[ "$LOCAL_DOMAIN" == *".."* ]] || [[ "$LOCAL_DOMAIN" == */* ]]; then
        echo_error "'$LOCAL_DOMAIN' não é um domínio local válido (esperado algo tipo *.test, sem '/' nem '..')."
        return 1
    fi

    # Pasta local: sempre /var/www/<dominio_local> (mesma convenção do create_domain/apache.sh)
    local LOCAL_DIR="/var/www/${LOCAL_DOMAIN}"

    echo_info "======================================================"
    echo_info " GET SITE FILES — atualizar ficheiros do site local a partir da produção"
    echo_info "======================================================"
    echo_info "PRODUÇÃO (só leitura, nunca modificada):"
    echo_info "  Domínio: $DOMAIN"
    echo_info "  Conta:   $ACCOUNT"
    echo_info "  Pasta:   ~/$ROOT_DIR"
    echo
    echo_success "LOCAL (vai ser sobrescrito):"
    echo_success "  Domínio: $LOCAL_DOMAIN"
    echo_success "  Pasta:   $LOCAL_DIR"
    echo_error "  ATENÇÃO: rsync --delete — ficheiros locais fora dos excludes que"
    echo_error "  não existam na produção serão APAGADOS a cada sincronização."
    echo_info "======================================================"
    echo

    read -rp "Continuar? [y/N]: " CONFIRM
    case "$CONFIRM" in
        [Yy]*) ;;
        *) echo_error "Operação cancelada."; return 1 ;;
    esac

    # Shell + SSH key da conta (mesmo fluxo do staging.sh/server.sh), para o rsync dos ficheiros.
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

    if [ ! -d "$LOCAL_DIR" ]; then
        echo_info "Site local '$LOCAL_DOMAIN' não existe. A criar vhost com create_domain..."
        create_domain "$LOCAL_DOMAIN" || { echo_error "Falha a criar o site local '$LOCAL_DOMAIN'."; return 1; }
    fi

    # --- Ficheiros: preview (dry-run) antes de qualquer alteração real ---
    # Ficheiros de configuração, .htaccess e .env ficam de fora do rsync: depois de
    # existirem uma vez localmente, não devem ser pisados pela cópia de produção
    # nos refreshes seguintes (senão perdíamos sempre a ligação à BD local). .git
    # também fica de fora — nunca faria sentido apagar o histórico local (commits
    # não enviados) só porque a produção não tem repositório.
    # Pastas de cache/logs e as pastas de media pesadas também ficam de fora — não
    # fazem falta para desenvolver localmente e só desperdiçam tempo/espaço a copiar:
    # img/p (só as imagens de produto — o resto de img/, tipo categorias/logo/tema,
    # sincroniza normalmente) e upload são do PrestaShop, wp-content/uploads é do
    # WordPress, storage/*/bootstrap-cache são do Laravel.
    local RSYNC_EXCLUDES="--exclude=/wp-config.php --exclude=/config/settings.inc.php --exclude=/app/config/parameters.php --exclude=/app/config/parameters.yml --exclude=/.htaccess --exclude=/.env --exclude=/.git/"
    RSYNC_EXCLUDES="$RSYNC_EXCLUDES --exclude=/cache/ --exclude=/var/cache/ --exclude=/var/logs/ --exclude=/wp-content/cache/"
    RSYNC_EXCLUDES="$RSYNC_EXCLUDES --exclude=/img/p/ --exclude=/upload/ --exclude=/wp-content/uploads/"
    RSYNC_EXCLUDES="$RSYNC_EXCLUDES --exclude=/storage/framework/cache/ --exclude=/storage/framework/sessions/ --exclude=/storage/framework/views/ --exclude=/storage/logs/ --exclude=/storage/app/public/ --exclude=/bootstrap/cache/"

    echo_info "A calcular alterações de ficheiros (dry-run)..."
    local DRY_OUTPUT
    DRY_OUTPUT=$(rsync -an --itemize-changes --delete $RSYNC_EXCLUDES "${ACCOUNT}@server:/home/${ACCOUNT}/${ROOT_DIR}/" "${LOCAL_DIR}/" 2>&1)
    local CHANGE_COUNT
    CHANGE_COUNT=$(echo "$DRY_OUTPUT" | grep -vE '^(sending incremental file list$|sent .* bytes|total size is)' | grep -c .)
    echo "$DRY_OUTPUT" | tail -n 15
    echo_info "Alterações previstas: $CHANGE_COUNT (origem: ${ACCOUNT}@server:~/$ROOT_DIR -> destino: $LOCAL_DIR)"

    read -rp "Aplicar rsync real dos ficheiros? [y/N]: " answer
    case "$answer" in
        [Yy]*) ;;
        *) echo_error "Operação cancelada."; return 1 ;;
    esac

    echo_info "A sincronizar ficheiros..."
    rsync -a --delete --info=progress2 $RSYNC_EXCLUDES "${ACCOUNT}@server:/home/${ACCOUNT}/${ROOT_DIR}/" "${LOCAL_DIR}/" \
        || { echo_error "rsync falhou."; return 1; }

    # .htaccess: só semeia a partir da produção se ainda não existir localmente
    if [ ! -f "${LOCAL_DIR}/.htaccess" ]; then
        scp -q "${ACCOUNT}@server:/home/${ACCOUNT}/${ROOT_DIR}/.htaccess" "${LOCAL_DIR}/.htaccess" 2>/dev/null
    fi

    # --- Configuração local: só semeia a partir da produção se ainda não existir
    # nenhum ficheiro de configuração localmente (primeira sincronização deste site) ---
    if [ ! -f "${LOCAL_DIR}/wp-config.php" ] && [ ! -f "${LOCAL_DIR}/config/settings.inc.php" ] \
        && [ ! -f "${LOCAL_DIR}/app/config/parameters.php" ] && [ ! -f "${LOCAL_DIR}/app/config/parameters.yml" ] \
        && [ ! -f "${LOCAL_DIR}/.env" ]; then
        echo_info "Nenhuma configuração local encontrada: a semear a partir da produção (BD local: user root / password admin)..."
        local rel
        for rel in "wp-config.php" "config/settings.inc.php" "app/config/parameters.php" "app/config/parameters.yml" ".env"; do
            mkdir -p "$(dirname "${LOCAL_DIR}/${rel}")"
            scp -q "${ACCOUNT}@server:/home/${ACCOUNT}/${ROOT_DIR}/${rel}" "${LOCAL_DIR}/${rel}" 2>/dev/null
        done

        local f="${LOCAL_DIR}/wp-config.php"
        if [ -f "$f" ]; then
            sed -i "s/define( *'DB_USER', *'[^']*'/define( 'DB_USER', 'root'/" "$f"
            sed -i "s/define( *'DB_PASSWORD', *'[^']*'/define( 'DB_PASSWORD', 'admin'/" "$f"
            sed -i "s/define( *'DB_HOST', *'[^']*'/define( 'DB_HOST', '127.0.0.1'/" "$f"
        fi

        f="${LOCAL_DIR}/config/settings.inc.php"
        if [ -f "$f" ]; then
            sed -i "s/define('_DB_USER_', *'[^']*')/define('_DB_USER_', 'root')/" "$f"
            sed -i "s/define('_DB_PASSWD_', *'[^']*')/define('_DB_PASSWD_', 'admin')/" "$f"
            sed -i "s/define('_DB_SERVER_', *'[^']*')/define('_DB_SERVER_', '127.0.0.1')/" "$f"
        fi

        f="${LOCAL_DIR}/app/config/parameters.php"
        if [ -f "$f" ]; then
            sed -i "s/'database_user' => '[^']*'/'database_user' => 'root'/" "$f"
            sed -i "s/'database_password' => '[^']*'/'database_password' => 'admin'/" "$f"
            sed -i "s/'database_host' => '[^']*'/'database_host' => '127.0.0.1'/" "$f"
        fi

        f="${LOCAL_DIR}/app/config/parameters.yml"
        if [ -f "$f" ]; then
            sed -i "s/database_user:.*/database_user: root/" "$f"
            sed -i "s/database_password:.*/database_password: admin/" "$f"
            sed -i "s/database_host:.*/database_host: 127.0.0.1/" "$f"
        fi

        # Laravel: DB_DATABASE fica intacto (mesma convenção das outras plataformas —
        # a BD local usa sempre o mesmo nome da de produção). APP_URL é reescrito porque,
        # ao contrário do WordPress/PrestaShop, o Laravel não guarda o domínio na BD —
        # não há outro sítio para o corrigir a não ser aqui.
        f="${LOCAL_DIR}/.env"
        if [ -f "$f" ]; then
            sed -i "s/^DB_HOST=.*/DB_HOST=127.0.0.1/" "$f"
            sed -i "s/^DB_USERNAME=.*/DB_USERNAME=root/" "$f"
            sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=admin/" "$f"
            sed -i "s#^APP_URL=.*#APP_URL=https://${LOCAL_DOMAIN}#" "$f"
        fi
    fi

    echo
    echo_success "Ficheiros do site local atualizados a partir da produção!"
    echo "🌍 Local: https://$LOCAL_DOMAIN"
    echo "📁 Pasta: $LOCAL_DIR"
    echo

    # O nome da BD só serve para pré-preencher a sugestão abaixo — lê-se dos ficheiros
    # de configuração já sincronizados localmente (rsync/seeding acima), sem precisar
    # de voltar a ligar por SSH. Nota: nenhum ramo pode terminar em "| tr" aqui — tr
    # devolve sempre exit 0 mesmo com entrada vazia, o que quebraria o encadeamento ||
    # e faria os ramos seguintes nunca correr; a limpeza fica toda no fim.
    local DB_NAME
    DB_NAME=$({
        grep -oP "(?<=define\('DB_NAME', ')[^']+" "${LOCAL_DIR}/wp-config.php" 2>/dev/null ||
        grep -oP "(?<=define\('_DB_NAME_', ')[^']+" "${LOCAL_DIR}/config/settings.inc.php" 2>/dev/null ||
        grep -oP "(?<='database_name' => ')[^']+" "${LOCAL_DIR}/app/config/parameters.php" 2>/dev/null ||
        grep -oP "(?<=database_name:).*" "${LOCAL_DIR}/app/config/parameters.yml" 2>/dev/null ||
        grep -oP "(?<=^DB_DATABASE=).*" "${LOCAL_DIR}/.env" 2>/dev/null
    } | head -n1 | tr -d " '\"\r")

    echo_info "Para ir buscar a base de dados:"
    echo_info "  get_database ${DB_NAME:-<bd_produção>}"
    echo
}

# ─────────────── AUTO-COMPLETE OPCIONAL ───────────────
_get_site_files_autocomplete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local domains
    if [[ $COMP_CWORD -eq 1 ]]; then
        domains=$(ssh "$SERVER" "awk -F': ' '{print \$1}' /etc/userdomains" 2>/dev/null | grep -v '^staging\.')
        COMPREPLY=( $(compgen -W "$domains" -- "$cur") )
    fi
}
complete -F _get_site_files_autocomplete get_site_files
