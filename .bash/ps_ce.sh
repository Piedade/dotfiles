#!/bin/bash

sync_ce_tables() {
    if [ -z "$1" ]; then
        echo_error "Usage: sync_ce_tables <database_name>"
        return 1
    fi

    local DATABASE_NAME="$1"
    local SSH_USER="${DATABASE_NAME%%_*}"
    local DUMP_PATH="$HOME/Downloads/${DATABASE_NAME}_ce.sql"

    echo -e "${BOLD}${RED}"
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║  ⚠  PRODUCTION SYNC — THIS OVERWRITES REMOTE   ║"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo -e "$RESET"
    echo -e "  ${WHITE}Database:${RESET} $DATABASE_NAME"
    echo -e "  ${WHITE}Target:${RESET}   $SSH_USER@server"
    echo -e "  ${WHITE}Tables:${RESET}   all ps_ce_* will be overwritten on remote"
    echo ""
    local CONFIRM
    read -rp "  Type the database name to confirm: " CONFIRM
    if [ "$CONFIRM" != "$DATABASE_NAME" ]; then
        echo_error "Aborted."
        return 1
    fi

    # Verify SSH connectivity
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_USER@server" "true" 2>/dev/null; then
        echo_error "SSH authentication failed for $SSH_USER@server"
        return 1
    fi

    # Get list of ps_ce_* tables from local
    echo_info "Fetching ps_ce_* table list..."
    local TABLES
    TABLES=$(mysql -N -e "SHOW TABLES LIKE 'ps\_ce\_%'" "$DATABASE_NAME" 2>/dev/null)

    if [ -z "$TABLES" ]; then
        echo_error "No ps_ce_* tables found in $DATABASE_NAME"
        return 1
    fi

    echo -e "  ${WHITE}Tables found:${RESET}\n$TABLES\n"

    # Convert newlines to spaces for mysqldump
    local TABLES_SPACED
    TABLES_SPACED=$(echo "$TABLES" | tr '\n' ' ')

    # Export from local
    echo_info "Exporting from local..."
    mysqldump --single-transaction --quick "$DATABASE_NAME" $TABLES_SPACED > "$DUMP_PATH"
    if [ $? -ne 0 ] || [ ! -s "$DUMP_PATH" ]; then
        echo_error "mysqldump failed or produced an empty file"
        return 1
    fi

    # Import into remote
    echo_info "Importing into $SSH_USER@server..."
    local FILE_SIZE
    FILE_SIZE=$(stat -c %s "$DUMP_PATH")
    pv -s "$FILE_SIZE" "$DUMP_PATH" | ssh "root@server" "mysql $DATABASE_NAME"
    if [ ${PIPESTATUS[1]} -ne 0 ]; then
        echo_error "Remote import failed"
        return 1
    fi

    echo_success "Done! CE tables synced to remote $DATABASE_NAME."
}
