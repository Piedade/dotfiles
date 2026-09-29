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
# /var/www, vhost Apache, certificado mkcert), tentando usar a mesma versão de
# PHP (MultiPHP) da produção — só se já estiver instalada localmente, senão
# cai no default do create_domain.
#
# Laravel: se o docroot do vhost for .../public, sobe automaticamente para a
# pasta do projeto (artisan/app/vendor/.env) quando confirma que existe artisan
# lá — senão só avisa e pergunta antes de sincronizar a pasta pai.
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
#
# Exit codes: 0 sucesso, 2 o utilizador recusou um dos prompts [y/N] (não é
# uma falha real), 1 qualquer outra falha. Mesma convenção do update_prestashop
# (prestashop.sh) — pensada para quem chama isto programaticamente e precisa
# de tratar "cancelaste tu" de forma diferente de "algo correu mal".
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

    # Laravel: o docroot do vhost costuma apontar para .../public (o front
    # controller), mas o projeto real (artisan, app/, routes/, vendor/, .env) fica
    # na pasta pai — sincronizar só o docroot dava só os assets públicos e o
    # index.php, sem a aplicação. Deteta-se via SSH root (leitura, sem precisar de
    # shell access ainda na conta, que só é ativado mais abaixo) se a pasta pai tem
    # artisan; se detetar, sobe logo. Se a pasta se chamar "public" mas não for
    # Laravel confirmado, só avisa e pergunta.
    if [ "$(basename "$ROOT_DIR")" = "public" ]; then
        local PARENT_ROOT_DIR
        PARENT_ROOT_DIR=$(dirname "$ROOT_DIR")
        if ssh "$SERVER" "test -f /home/${ACCOUNT}/${PARENT_ROOT_DIR}/artisan" 2>/dev/null; then
            echo_laravel "Laravel detetado: pasta do vhost é 'public/', mas o projeto está em ~/$PARENT_ROOT_DIR — a sincronizar a partir daí."
            ROOT_DIR="$PARENT_ROOT_DIR"
        else
            echo_error "A pasta do vhost chama-se 'public' mas não encontrei 'artisan' em ~/$PARENT_ROOT_DIR — pode não ser Laravel."
            local USE_PARENT
            read -rp "Sincronizar a partir de ~/$PARENT_ROOT_DIR em vez de ~/$ROOT_DIR? [y/N]: " USE_PARENT
            case "$USE_PARENT" in
                [Yy]*) ROOT_DIR="$PARENT_ROOT_DIR" ;;
            esac
        fi
    fi

    # Domínio local: mesmo nome, TLD trocado por .test (ex: redpost.pt -> redpost.test).
    # Domínios de dev da agência (conta.dev.red.com.pt e afins — ver
    # strip_agency_dev_suffix em whm.sh) têm o sufixo inteiro trocado, não só o TLD
    # (ex: digiwest.dev.red.com.pt -> digiwest.test, não digiwest.dev.red.com.test).
    if [ -z "$LOCAL_DOMAIN" ]; then
        local BASE_NAME
        if BASE_NAME=$(strip_agency_dev_suffix "$DOMAIN"); then
            LOCAL_DOMAIN="${BASE_NAME}.test"
        else
            LOCAL_DOMAIN="${DOMAIN%.*}.test"
        fi
    fi
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
        *) echo_error "Operação cancelada."; return 2 ;;
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

        # Tenta usar a mesma versão de PHP da produção no vhost local, para não
        # arrancar sempre no default do create_domain (whm_resolve_php_version, em
        # whm.sh, tenta primeiro o .htaccess do domínio e só depois o default da
        # conta via MultiPHP Manager — ver comentário lá). Best-effort: só se aplica
        # se já estiver instalada localmente — caso contrário fica-se pelo default
        # (nunca vale a pena criar um vhost com um php-fpm que nem sequer existe na
        # máquina).
        local PROD_PHP_VERSION=""
        local RESULT
        RESULT=$(whm_resolve_php_version "$DOMAIN" "$ACCOUNT" "$ROOT_DIR")
        local CANDIDATE SOURCE RAW
        [ -n "$RESULT" ] && IFS='|' read -r CANDIDATE SOURCE RAW <<< "$RESULT"
        if [ -z "$RESULT" ] || [ "$SOURCE" != ".htaccess" ]; then
            # Sem override .htaccess — RESULT (se existir) vem do "default da conta" que o
            # MultiPHP Manager reporta, mas neste servidor CloudLinux esse "default" não é
            # necessariamente o que está mesmo em produção: o selectorctl da conta tem
            # precedência quando não há pin explícito (confirmado ao vivo — ver
            # project_cpanel_deploy_scripts). Substitui por esse valor quando disponível.
            local ACCOUNT_PHP
            ACCOUNT_PHP=$(whm_php_version_by_account "$ACCOUNT")
            if [ -n "$ACCOUNT_PHP" ]; then
                CANDIDATE="$ACCOUNT_PHP"
                SOURCE="conta (selectorctl)"
                RAW="$ACCOUNT_PHP"
            fi
        fi

        if [ -n "$CANDIDATE" ]; then
            if dpkg -s "php${CANDIDATE}-fpm" &>/dev/null; then
                PROD_PHP_VERSION="$CANDIDATE"
                echo_info "PHP de produção: $RAW (via $SOURCE) -> a usar php${PROD_PHP_VERSION}-fpm localmente."
            else
                echo_info "PHP de produção ($RAW, via $SOURCE) não está instalado localmente — a usar o default do create_domain."
            fi
        fi

        if [ -n "$PROD_PHP_VERSION" ]; then
            create_domain "$LOCAL_DOMAIN" "$PROD_PHP_VERSION" || { echo_error "Falha a criar o site local '$LOCAL_DOMAIN'."; return 1; }
        else
            create_domain "$LOCAL_DOMAIN" || { echo_error "Falha a criar o site local '$LOCAL_DOMAIN'."; return 1; }
        fi
    fi

    # --- Ficheiros: preview (dry-run) antes de qualquer alteração real ---
    # Ficheiros de configuração, .htaccess e .env ficam de fora do rsync: depois de
    # existirem uma vez localmente, não devem ser pisados pela cópia de produção
    # nos refreshes seguintes (senão perdíamos sempre a ligação à BD local). .git
    # também fica de fora — nunca faria sentido apagar o histórico local (commits
    # não enviados) só porque a produção não tem repositório. _upgrade_fixes.sh
    # (usado pelo UPGRADE_PRESTASHOP.sh) é a mesma história: só existe localmente,
    # nunca é enviado para produção.
    # Pastas de cache/logs também ficam de fora — não fazem falta para desenvolver
    # localmente e só desperdiçam tempo/espaço a copiar: img/p (só as imagens de
    # produto — o resto de img/, tipo categorias/logo/tema, sincroniza normalmente)
    # é do PrestaShop, storage/framework/*+bootstrap/cache são do Laravel. upload/,
    # wp-content/uploads/ e storage/app/ (uploads do Laravel) sincronizam normalmente
    # por default — só ficam de fora se o tamanho em produção disparar o aviso mais
    # abaixo e a resposta for não.
    local RSYNC_EXCLUDES="--exclude=/wp-config.php --exclude=/config/settings.inc.php --exclude=/app/config/parameters.php --exclude=/app/config/parameters.yml --exclude=/.htaccess --exclude=/.env --exclude=/.git/ --exclude=/_upgrade_fixes.sh"
    RSYNC_EXCLUDES="$RSYNC_EXCLUDES --exclude=/cache/ --exclude=/var/cache/ --exclude=/var/logs/ --exclude=/wp-content/cache/"
    RSYNC_EXCLUDES="$RSYNC_EXCLUDES --exclude=/img/p/"
    RSYNC_EXCLUDES="$RSYNC_EXCLUDES --exclude=/storage/framework/cache/ --exclude=/storage/framework/sessions/ --exclude=/storage/framework/views/ --exclude=/storage/logs/ --exclude=/bootstrap/cache/"
    # cgi-bin/ e .well-known são geridos pelo cPanel/host, não pela app — e lixo comum
    # de zips/erros que não interessa levar para local: __MACOSX/ (sobra de zips feitos
    # em macOS), error_log, .user.ini e php.ini (overrides de configuração PHP por
    # pasta, tal como .htaccess, o PHP lê-os em qualquer subpasta) podem aparecer em
    # qualquer subpasta, por isso sem a "/" inicial. O html de verificação do Google
    # Search Console (googleXXXXXXXXXXXXXXXX.html) é sempre na raiz e específico de
    # produção — não faz sentido para um domínio .test. node_modules/ e .direnv/ sem
    # "/" inicial porque podem existir em mais do que uma pasta — reinstala-se
    # localmente com npm/yarn e direnv, não vale a pena copiar.
    # vendor/ (composer) fica de fora desta lista de propósito — sincroniza normalmente.
    RSYNC_EXCLUDES="$RSYNC_EXCLUDES --exclude=/cgi-bin/ --exclude=/.well-known/ --exclude=__MACOSX/ --exclude=error_log --exclude=.user.ini --exclude=php.ini --exclude=/google*.html --exclude=node_modules/ --exclude=.direnv/"

    # Pastas de media (storage/app do Laravel, wp-content/uploads do WordPress,
    # upload/ do PrestaShop) sincronizam por default, mas podem ser gigantes sem
    # nenhuma vantagem para dev local — em vez de excluir sempre ou nunca, pergunta-se
    # quando uma delas passa de MEDIA_SIZE_THRESHOLD_MB em produção (via root@server,
    # leitura, sem precisar de shell access na conta ainda).
    local MEDIA_SIZE_THRESHOLD_MB=500
    local MEDIA_DIR
    for MEDIA_DIR in "storage/app" "wp-content/uploads" "upload"; do
        local MEDIA_SIZE_MB
        MEDIA_SIZE_MB=$(ssh "$SERVER" "du -sm '/home/${ACCOUNT}/${ROOT_DIR}/${MEDIA_DIR}' 2>/dev/null" | awk '{print $1}')
        if [ -n "$MEDIA_SIZE_MB" ] && [ "$MEDIA_SIZE_MB" -ge "$MEDIA_SIZE_THRESHOLD_MB" ]; then
            echo_error "'$MEDIA_DIR' tem ${MEDIA_SIZE_MB}MB em produção."
            local SYNC_MEDIA
            read -rp "Sincronizar '$MEDIA_DIR' mesmo assim? [y/N]: " SYNC_MEDIA
            case "$SYNC_MEDIA" in
                [Yy]*) ;;
                *) RSYNC_EXCLUDES="$RSYNC_EXCLUDES --exclude=/${MEDIA_DIR}/" ;;
            esac
        fi
    done

    echo_info "A calcular alterações de ficheiros (dry-run)..."
    local DRY_OUTPUT
    DRY_OUTPUT=$(rsync -an --itemize-changes --delete $RSYNC_EXCLUDES "${ACCOUNT}@server:/home/${ACCOUNT}/${ROOT_DIR}/" "${LOCAL_DIR}/" 2>&1)
    local CHANGE_COUNT
    # `grep -c .` exits 1 when the count is 0 (nothing to sync) — harmless when
    # this function runs under a caller with no `set -e` (its usual case), but
    # a caller that DOES have errexit on (e.g. a script that sources this file)
    # would otherwise die right here on a perfectly fine "already in sync" run.
    CHANGE_COUNT=$(echo "$DRY_OUTPUT" | grep -vE '^(sending incremental file list$|sent .* bytes|total size is)' | grep -c . || true)
    echo "$DRY_OUTPUT"
    echo_info "Alterações previstas: $CHANGE_COUNT (origem: ${ACCOUNT}@server:~/$ROOT_DIR -> destino: $LOCAL_DIR)"

    read -rp "Aplicar rsync real dos ficheiros? [y/N]: " answer
    case "$answer" in
        [Yy]*) ;;
        *) echo_error "Operação cancelada."; return 2 ;;
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

            # SMTP: aponta para o Mailpit local em vez do servidor de mail de produção
            # (evita enviar emails a sério a partir do dev, e limpa a password de
            # produção que o scp acima acabou de copiar tal e qual para o ficheiro local).
            # sed -i "s/define( *'SMTP_HOST', *'[^']*'/define( 'SMTP_HOST', '127.0.0.1'/" "$f"
            sed -i "s/define( *'SMTP_AUTH', *[0-9]*/define( 'SMTP_AUTH', 0/" "$f"
            sed -i "s/define( *'SMTP_USER', *'[^']*'/define( 'SMTP_USER', ''/" "$f"
            sed -i "s/define( *'SMTP_PASS', *'[^']*'/define( 'SMTP_PASS', ''/" "$f"
            # Mailpit escuta em 1025, não na porta SMTP normal (25/587) — sem isto o
            # mail continua a tentar sair pela porta de produção. Se já existir a
            # constante, só reescreve o valor; senão insere-a a seguir a SMTP_HOST.
            if grep -q "define( *'SMTP_PORT'" "$f"; then
                sed -i "s/define( *'SMTP_PORT', *[0-9]*/define( 'SMTP_PORT', 1025/" "$f"
            else
                sed -i "/define( *'SMTP_HOST'/a define( 'SMTP_PORT', 1025 );" "$f"
            fi
            # sed -i "s/define( *'SMTP_FROM', *'[^']*'/define( 'SMTP_FROM', 'dev@${LOCAL_DOMAIN}'/" "$f"
            # sed -i "s/define( *'SMTP_FROMNAME', *'[^']*'/define( 'SMTP_FROMNAME', '${LOCAL_DOMAIN}'/" "$f"
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
    # \K em vez de lookbehind (?<=...): o grep desta máquina é o ugrep, cujo PCRE2
    # exige lookbehind de largura fixa — não dava para tolerar espaço opcional (ex:
    # "define( 'DB_NAME'," vs "define('DB_NAME',") com (?<=...\s*...). \K não tem
    # essa restrição. Confirmado com um caso real (sucessoemvendas.test) que usa
    # "define( 'DB_NAME', ...)" com espaço a seguir ao parêntesis — o lookbehind
    # antigo, sem \s*, nunca dava match nesse formato.
    local DB_NAME
    DB_NAME=$({
        grep -oP "define\(\s*'DB_NAME'\s*,\s*'\K[^']+" "${LOCAL_DIR}/wp-config.php" 2>/dev/null ||
        grep -oP "define\(\s*'_DB_NAME_'\s*,\s*'\K[^']+" "${LOCAL_DIR}/config/settings.inc.php" 2>/dev/null ||
        grep -oP "'database_name'\s*=>\s*'\K[^']+" "${LOCAL_DIR}/app/config/parameters.php" 2>/dev/null ||
        grep -oP "database_name:\K.*" "${LOCAL_DIR}/app/config/parameters.yml" 2>/dev/null ||
        grep -oP "^DB_DATABASE=\K.*" "${LOCAL_DIR}/.env" 2>/dev/null
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
