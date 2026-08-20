# Sincroniza o filestore de um staging Odoo (dev.odoo.com) para o filestore local,
# via rsync sobre SSH. Só LÊ o staging (rsync como origem); nunca escreve nada lá.
#
# Uso: get_odoo_filestorage [ssh user@host-do-staging]
# A ligação SSH muda a cada build do staging, por isso é sempre passada como argumento
# (nunca fixa no script); se não for dada, pergunta-se interativamente. O nome da pasta
# do filestore remoto é derivado do próprio hostname (ex: server-red-group-staging-36080941.dev.odoo.com
# -> .../filestore/server-red-group-staging-36080941), nunca pedido à parte.
get_odoo_filestorage() {
    local SSH_TARGET=$1
    shift

    # Aceita o "ssh user@host" colado direto do staging, quer como um único argumento
    # ("ssh user@host") quer como dois (ssh user@host, sem aspas) — e também só "user@host".
    if [ "$SSH_TARGET" = "ssh" ]; then
        SSH_TARGET=$1
        shift
    else
        SSH_TARGET="${SSH_TARGET#ssh }"
    fi

    if [ -z "$SSH_TARGET" ]; then
        read -rp "Ligação SSH ao staging (ex: ssh user@host.dev.odoo.com): " SSH_TARGET
        SSH_TARGET="${SSH_TARGET#ssh }"
    fi

    local LOCAL_DIR="/home/piedade/.local/share/Odoo/filestore/red/"

    if [ -z "$SSH_TARGET" ] || [[ "$SSH_TARGET" != *@* ]]; then
        echo_error "Uso: get_odoo_filestorage ssh user@host-do-staging.dev.odoo.com"
        return 1
    fi

    local HOST="${SSH_TARGET#*@}"

    # SAFETY: só aceita hosts *.dev.odoo.com — nunca produção (odoo.com "a secas")
    if [[ "$HOST" != *.dev.odoo.com ]]; then
        echo_error "SAFETY: '$HOST' não parece um staging (*.dev.odoo.com). A abortar."
        return 1
    fi

    local REMOTE_DB="${HOST%.dev.odoo.com}"
    local REMOTE_FILESTORE="/home/odoo/data/filestore/${REMOTE_DB}"

    echo_info "Staging:          $SSH_TARGET"
    echo_info "Filestore remoto: $REMOTE_FILESTORE"
    echo_info "Filestore local:  $LOCAL_DIR"

    ssh "$SSH_TARGET" "test -d '$REMOTE_FILESTORE'" \
        || { echo_error "Pasta remota não encontrada: $REMOTE_FILESTORE"; return 1; }

    mkdir -p "$LOCAL_DIR"

    # --delete só afeta o destino (local): apaga ficheiros locais que já não existem no
    # staging. O staging é sempre a origem no rsync, por isso nunca é tocado/apagado.
    echo_info "A calcular alterações (dry-run, inclui remoções locais)..."
    rsync -an --delete --itemize-changes -e ssh "${SSH_TARGET}:${REMOTE_FILESTORE}/" "$LOCAL_DIR" | tail -n 15

    read -rp "Sincronizar ficheiros (rsync real, só lê o staging; pode apagar ficheiros locais)? [y/N]: " CONFIRM
    case "$CONFIRM" in
        [Yy]*) ;;
        *) echo_error "Operação cancelada."; return 1 ;;
    esac

    echo_info "A sincronizar filestore..."
    rsync -a --delete --info=progress2 -e ssh "${SSH_TARGET}:${REMOTE_FILESTORE}/" "$LOCAL_DIR" \
        || { echo_error "rsync falhou."; return 1; }

    echo_success "Filestore sincronizado para $LOCAL_DIR"
}

# Sincroniza a BD de um staging Odoo (dev.odoo.com) para a BD local "red". O Postgres
# do staging não aceita ligações TCP diretas de fora (só é alcançável via SSH), por
# isso o pg_dump corre remotamente por SSH e o resultado é só o stream de volta — nunca
# escreve nada no staging. DROP/CREATE DATABASE e pg_restore correm sempre no Postgres local.
#
# Uso: get_odoo_database [ssh user@host-do-staging]
# A ligação SSH muda a cada build do staging, por isso é sempre passada como argumento
# (nunca fixa no script); se não for dada, pergunta-se interativamente. O nome da BD
# remota é derivado do próprio hostname, tal como em get_odoo_filestorage.
get_odoo_database() {
    local SSH_TARGET=$1
    shift

    # Aceita o "ssh user@host" colado direto do staging, quer como um único argumento
    # ("ssh user@host") quer como dois (ssh user@host, sem aspas) — e também só "user@host".
    if [ "$SSH_TARGET" = "ssh" ]; then
        SSH_TARGET=$1
        shift
    else
        SSH_TARGET="${SSH_TARGET#ssh }"
    fi

    if [ -z "$SSH_TARGET" ]; then
        read -rp "Ligação SSH ao staging (ex: ssh user@host.dev.odoo.com): " SSH_TARGET
        SSH_TARGET="${SSH_TARGET#ssh }"
    fi

    if [ -z "$SSH_TARGET" ] || [[ "$SSH_TARGET" != *@* ]]; then
        echo_error "Uso: get_odoo_database ssh user@host-do-staging.dev.odoo.com"
        return 1
    fi

    local HOST="${SSH_TARGET#*@}"

    # SAFETY: só aceita hosts *.dev.odoo.com — nunca produção
    if [[ "$HOST" != *.dev.odoo.com ]]; then
        echo_error "SAFETY: '$HOST' não parece um staging (*.dev.odoo.com). A abortar."
        return 1
    fi

    local REMOTE_DB="${HOST%.dev.odoo.com}"
    local LOCAL_DB="red"
    local DUMP_PATH="$HOME/Downloads/${LOCAL_DB}_staging.dump"

    echo_info "Staging:   $SSH_TARGET"
    echo_info "BD remota: $REMOTE_DB"
    echo_info "BD local:  $LOCAL_DB"

    echo_info "A criar dump do staging via SSH (só leitura)..."
    ssh "$SSH_TARGET" "pg_dump --format=custom --no-owner --no-privileges '$REMOTE_DB'" | pv > "$DUMP_PATH"
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        echo_error "pg_dump remoto falhou."
        return 1
    fi

    if [ ! -s "$DUMP_PATH" ]; then
        echo_error "Dump '$DUMP_PATH' está vazio ou não foi criado."
        return 1
    fi

    read -rp "Isto vai APAGAR a BD local '$LOCAL_DB' e recriá-la a partir do dump. Continuar? [y/N]: " CONFIRM
    case "$CONFIRM" in
        [Yy]*) ;;
        *) echo_error "Operação cancelada. Dump fica em $DUMP_PATH"; return 1 ;;
    esac

    echo_info "A recriar BD local '$LOCAL_DB'..."
    dropdb --if-exists "$LOCAL_DB" && createdb "$LOCAL_DB" \
        || { echo_error "Falha a recriar a BD local."; return 1; }

    echo_info "A importar dump..."
    pg_restore --no-owner --no-privileges -d "$LOCAL_DB" "$DUMP_PATH" \
        || echo_error "pg_restore terminou com avisos/erros — confirma o output acima."

    echo_info "A correr post_dump_fix..."
    /var/www/odoo/scripts/post_dump_fix.sh "$LOCAL_DB" \
        || { echo_error "post_dump_fix.sh falhou."; return 1; }

    echo_success "Base de dados '$LOCAL_DB' importada a partir do staging."
}

build_odoo_module() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: build_odoo_module <module_dir> [module_dir...]" >&2
        return 1
    fi

    local module_dirs=("$@")
    local module_dir module_dir_abs module dest

    for module_dir in "${module_dirs[@]}"; do
        module_dir_abs=$(builtin cd "$module_dir" 2>/dev/null && pwd) || {
            echo "❌ Directory not found: $module_dir"
            continue
        }

        module=$(basename "$module_dir_abs")
        dest="$(dirname "$module_dir_abs")/${module}.tar.gz"

        tar -czf "$dest" \
            --exclude='*/node_modules' \
            --exclude='*/app' \
            --exclude='*/__pycache__' \
            --exclude='*.pyc' \
            --exclude='*/.pytest_cache' \
            -C "$(dirname "$module_dir_abs")" "$module"/

        echo "✅ Created: $dest"
    done
}
