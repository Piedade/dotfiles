#!/usr/bin/env bash
set -euo pipefail

# Never run this without a human at the keyboard (cron, systemd timer, CI, etc.)
# — the process is manual by design (backup, confirmations, visual validation
# of the local site before pushing). No tty on stdin is the reliable signal
# that nobody is there to answer the prompts.
if [[ ! -t 0 ]]; then
    echo "This script requires an interactive shell — never run via cron/systemd/non-tty. Aborted." >&2
    exit 1
fi

# PrestaShop production (LIVE) upgrade
#
# Runs top to bottom in one go, but stops at every step that TOUCHES
# production and asks for explicit confirmation before continuing. The
# "pushes" to production (steps 7 and 8) are manual commands scoped to this
# file only — deliberately NOT turned into .bashrc functions (get_site_files/
# get_database are read-only against production by design; writing to
# production stays scoped to this script).
#
# Usage: ./upgrade_prestashop_LIVEv1.sh <production_domain>
# Ex:    ./upgrade_prestashop_LIVEv1.sh shop.redpost.pt

DOMAIN="${1:?Usage: $0 <production_domain> (ex: shop.redpost.pt)}"
LOCAL_DOMAIN="${DOMAIN%.*}.test"
LOCAL_DIR="/var/www/${LOCAL_DOMAIN}"

# Toolkit functions (get_site_files, get_database, update_prestashop,
# whm_account_by_domain, echo_production_warning, ...) aren't "export -f"'d,
# so they don't reach a new process just by living in .bashrc — they need to
# be sourced here explicitly for the script to work even when run as
# `bash upgrade_prestashop_LIVEv1.sh ...` outside an interactive shell. Done
# before resuming/creating BACKUP_DIR below so echo_*/read prompts there can
# already use the toolkit's styled output.
for file in "$HOME/.dotfiles/.bash"/*.sh; do
    # shellcheck disable=SC1090
    source "$file"
done

# Resume support: an earlier attempt interrupted mid-run (power loss, a
# lockup, etc.) leaves its own timestamped BACKUP_DIR marked incomplete via
# its .state file (LAST_STEP != done). Offer to reuse that exact directory —
# steps 1-3 still always re-run regardless of resuming (cheap, and this
# re-validates instead of trusting stale state), but step 4 can offer to
# skip the full DB pull if it finds an already-valid dump inside.
RESUME_DIR=""
for d in $(find "$HOME/Downloads/.upgrade-backups" -maxdepth 1 -type d -name "${DOMAIN}_*" 2>/dev/null | sort -r); do
    if [ -f "$d/.state" ] && ! grep -qx "LAST_STEP=done" "$d/.state"; then
        RESUME_DIR="$d"
        break
    fi
done

if [ -n "$RESUME_DIR" ]; then
    LAST_STEP=$(grep "^LAST_STEP=" "$RESUME_DIR/.state" | cut -d= -f2)
    echo_info "Found an incomplete previous attempt: $RESUME_DIR (reached step: ${LAST_STEP:-unknown})"
    read -rp "Resume from there instead of starting a fresh run? [y/N]: " resume_answer
    case "$resume_answer" in
        [Yy]*) BACKUP_DIR="$RESUME_DIR" ;;
        *) RESUME_DIR="" ;;
    esac
fi

if [ -z "$RESUME_DIR" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="$HOME/Downloads/.upgrade-backups/${DOMAIN}_${TIMESTAMP}"
    mkdir -p "$BACKUP_DIR"
fi

exec > >(tee -a "$BACKUP_DIR/upgrade.log") 2>&1

# Records progress in BACKUP_DIR/.state so an interrupted run can be resumed
# later (see RESUME_DIR above) — called after each step succeeds; "done" once
# step 9 finishes, so a completed run is never offered up for resuming.
save_state() {
    echo "LAST_STEP=$1" > "$BACKUP_DIR/.state"
}

confirm_production() {
    echo_error "⚠️  PRODUCTION ($DOMAIN) — $1. Continue? [y/N]"
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]] || { echo_error "Aborted."; exit 1; }
}

# `set -e` only catches a failing exit code — an ssh/mysqldump that "succeeds"
# but produces an empty or truncated file (wrong prefix, empty result set,
# connection hiccup mid-transfer) would otherwise pass silently. Same
# completion marker get_database (mysql.sh) already checks for its own dumps.
check_dump() {
    local file="$1"
    [ -s "$file" ] || { echo_error "Dump '$file' is empty or missing."; exit 1; }
    tail -n 5 "$file" | grep -q -- "-- Dump completed on" \
        || { echo_error "Dump '$file' looks incomplete/corrupted (no 'Dump completed on' marker)."; exit 1; }
}

# get_site_files/get_database/update_prestashop all follow the same exit-code
# convention (0 success, 2 the user declined one of their own internal [y/N]
# prompts, 1 any other failure — see each function's own doc comment). Called
# as bare statements they'd otherwise let `set -e` kill the whole script with
# no indication of which of the two happened, or what the real error was.
run_or_abort() {
    local label="$1"; shift
    local result=0
    "$@" || result=$?
    if [ "$result" -eq 2 ]; then
        echo_error "You declined $label — aborting the whole upgrade."
        exit 1
    elif [ "$result" -ne 0 ]; then
        echo_error "$label failed (exit $result) — aborting the whole upgrade. See the error above for why."
        exit 1
    fi
}

echo_prestashop "======================================================"
echo_prestashop " PrestaShop LIVE upgrade — $DOMAIN"
echo_prestashop " Log: $BACKUP_DIR/upgrade.log"
echo_prestashop "======================================================"
confirm_production "start of the full process (backup, maintenance, upgrade, push)"

# cPanel account and production folder (same WHM resolution used by get_site_files/get_database)
ACCOUNT=$(whm_account_by_domain "$DOMAIN") || { echo_error "Domain '$DOMAIN' not found on the server."; exit 1; }
DOC_ROOT=$(whm_docroot_by_domain "$DOMAIN") || { echo_error "Could not get the documentroot for '$DOMAIN'."; exit 1; }
# Same validation get_site_files (site.sh) does on this exact extraction — an
# unusual account layout where DOC_ROOT doesn't start with /home/$ACCOUNT/
# would otherwise leave ROOT_DIR as the untouched full path, silently
# corrupting every ~/${ROOT_DIR} remote path and rsync destination below.
if [[ "$DOC_ROOT" != "/home/${ACCOUNT}/"* ]]; then
    echo_error "Unexpected documentroot '$DOC_ROOT' for account '$ACCOUNT' (doesn't start with /home/$ACCOUNT/)."
    read -rp "Production folder (ex: public_html): " ROOT_DIR
else
    ROOT_DIR="${DOC_ROOT#/home/${ACCOUNT}/}"
fi
if [ -z "$ROOT_DIR" ] || [[ "$ROOT_DIR" == /* ]] || [[ "$ROOT_DIR" == *".."* ]]; then
    echo_error "Invalid production folder: '$ROOT_DIR'."
    exit 1
fi

# Real production DB name — try to auto-detect it from production's own config
# first (same approach clone_to_staging uses in staging.sh), falling back to
# interactive selection (SHOW DATABASES + fzf, what get_database itself does
# when no name is given) only if the config can't be read/parsed. Resolved
# here, once, because step 1 (maintenance) and step 2 (shop_url snapshot)
# need it BEFORE step 4 (which would otherwise only get it from local files,
# and those only exist after step 3).
DATABASE_NAME=$(ssh "${ACCOUNT}@server" "
    grep -oP \"(?<=define\\('_DB_NAME_', ')[^']+\" ~/${ROOT_DIR}/config/settings.inc.php 2>/dev/null ||
    grep -oP \"(?<='database_name' => ')[^']+\" ~/${ROOT_DIR}/app/config/parameters.php 2>/dev/null
" 2>/dev/null | head -n1)
DATABASE_SOURCE="production config"

if [ -z "$DATABASE_NAME" ]; then
    DATABASE_NAME=$(ssh root@server "mysql -N -e 'SHOW DATABASES' 2>/dev/null" | grep -Ev '^(information_schema|mysql|performance_schema|sys)$' | fzf --prompt="Select production DB for $DOMAIN: ")
    [ -z "$DATABASE_NAME" ] && { echo_error "Production database is required."; exit 1; }
    DATABASE_SOURCE="manual selection"
fi

# Real table prefix (may not be "ps_"), same detection used by get_database (mysql.sh).
# Resolved here, once, because it's needed by maintenance mode (step 1), by
# the shop_url snapshot (step 2), and by the restore after the DB push (step 8).
PS_SHOP_URL_TABLE=$(ssh root@server "mysql -N -e \"SELECT TABLE_NAME FROM information_schema.tables WHERE table_schema='${DATABASE_NAME}' AND TABLE_NAME LIKE '%\\\\_shop\\\\_url' ORDER BY LENGTH(TABLE_NAME) ASC LIMIT 1\"")
[ -z "$PS_SHOP_URL_TABLE" ] && { echo_error "Could not find a *_shop_url table in '$DATABASE_NAME' — is this really a PrestaShop database?"; exit 1; }
PS_PREFIX="${PS_SHOP_URL_TABLE%_shop_url}"

# The confirmation at the top of the script happens BEFORE any of the values
# above are resolved — it's a blind "do you want to start?". This is the one
# place all of them get printed, right before Step 1 makes its first change to
# production — the last chance to catch a wrong auto-detected value.
echo_info "------------------------------------------------------"
echo_info "   Domain:      $DOMAIN"
echo_info "   Account:     $ACCOUNT"
echo_info "   Doc root:    ~/$ROOT_DIR"
echo_info "   Database:    $DATABASE_NAME ($DATABASE_SOURCE)"
echo_info "   Prefix:      ${PS_PREFIX}_"
echo_info "   Local dir:   $LOCAL_DIR"
echo_info "------------------------------------------------------"
confirm_production "everything above is correct"

# ────────────────────────────────────────────────────────────────
# Step 1 - Turn on maintenance mode in production
# ────────────────────────────────────────────────────────────────
# Done first, before even the (cheap, read-only) shop_url snapshot below —
# step 2 doesn't depend on this having run yet, so there's no reason to delay
# blocking writes by even one extra SSH round-trip once the run is confirmed.
# No separate confirm_production here — the "everything above is correct"
# confirmation right before step 1 already covers it, and maintenance ON is
# the very next action after that.
echo_prestashop "Step 1: maintenance ON"
ssh root@server "mysql ${DATABASE_NAME} -e \"UPDATE ${PS_PREFIX}_configuration SET value=0 WHERE name='PS_SHOP_ENABLE';\""
save_state 1

# ────────────────────────────────────────────────────────────────
# Step 2 - Snapshot the real production domain(s) (cheap, read-only —
# the files/DB backups are NOT taken here; see steps 3/4 below, which reuse
# what those steps already download instead of transferring everything
# a second time over the network)
# ────────────────────────────────────────────────────────────────
echo_prestashop "Step 2: snapshot production shop_url"
# get_database (step 4) rewrites ${PREFIX}_shop_url's domain/domain_ssl to
# *.test for local dev use. Without capturing the real values now, pushing
# the migrated local DB back to production in step 8 would overwrite
# production with the local .test domain and break every request (PrestaShop
# matches the incoming host against this table). Saved as ready-to-run UPDATE
# statements (QUOTE() handles escaping), so restoring after the step 8 import
# is a plain `mysql < file`, no bash-side parsing — correct for multistore
# too, since each row restores independently.
ssh root@server "mysql ${DATABASE_NAME} -N -e \"SELECT CONCAT('UPDATE ${PS_PREFIX}_shop_url SET domain=', QUOTE(domain), ', domain_ssl=', QUOTE(domain_ssl), ' WHERE id_shop_url=', id_shop_url, ';') FROM ${PS_PREFIX}_shop_url\"" > "$BACKUP_DIR/shop_url_restore.sql"
[ -s "$BACKUP_DIR/shop_url_restore.sql" ] \
    || { echo_error "shop_url_restore.sql is empty — check PS_PREFIX ('$PS_PREFIX') and the ${PS_PREFIX}_shop_url table before continuing."; exit 1; }
echo_success "Domain snapshot saved to: $BACKUP_DIR/shop_url_restore.sql"
save_state 2

# ────────────────────────────────────────────────────────────────
# Step 3 - Bring production files down to local (read-only against
# production; get_site_files already has its own dry-run + confirmation)
# ────────────────────────────────────────────────────────────────
echo_prestashop "Step 3: get_site_files"
run_or_abort "get_site_files" get_site_files "$DOMAIN" "$LOCAL_DOMAIN" # já tem o create_domain — RSYNC_EXCLUDES (site.sh) já protege _upgrade_fixes.sh

# Sanity check the pulled files are actually a PrestaShop install before
# spending time on step 4 (pulling + importing the whole production DB).
# detect_ps_version's first method needs a local DB, but with none imported
# yet it just falls through to its file-based fallbacks (Version.php,
# AppKernel.php, settings.inc.php) — all of which only need the files step 3
# just pulled, so this check is meaningful here, before step 4 even starts.
detect_ps_version "$LOCAL_DIR" >/dev/null \
    || { echo_error "Could not detect a PrestaShop version in '$LOCAL_DIR' — did get_site_files pull a valid install?"; exit 1; }

# Sanity check: local config's own database_name must match $DATABASE_NAME
# (resolved from production earlier). get_site_files only SEEDS config when
# none exists yet — it never corrects an already-existing one — so a
# $LOCAL_DIR reused from an older run/site (or a production DB that got
# renamed since) can carry a stale database_name pointing at a DB that
# doesn't match what step 4 is about to import. Left uncaught, this only
# surfaces much later as a cryptic "PrestaShopException ... DbPDO ...
# Unknown database" deep inside update_prestashop (step 5) — catch it here
# instead, before step 4 spends time importing the whole production DB.
LOCAL_DB_NAME=$(
    grep -oP "(?<=define\\('_DB_NAME_', ')[^']+" "$LOCAL_DIR/config/settings.inc.php" 2>/dev/null ||
    grep -oP "(?<='database_name' => ')[^']+" "$LOCAL_DIR/app/config/parameters.php" 2>/dev/null
)
if [ -n "$LOCAL_DB_NAME" ] && [ "$LOCAL_DB_NAME" != "$DATABASE_NAME" ]; then
    echo_error "Local config's database_name ('$LOCAL_DB_NAME') doesn't match production's ('$DATABASE_NAME') — '$LOCAL_DIR' likely has stale config from an earlier run/site. Fix app/config/parameters.php (or config/settings.inc.php) before continuing."
    exit 1
fi

# Files backup (rollback safety net): archive the copy get_site_files just
# pulled down instead of doing a separate remote tar+scp — get_site_files
# already moved every file over the network once (rsync), so a second
# production->local transfer here would just repeat that for no benefit.
# Taken now, before update_prestashop (step 5) touches anything. pv gives
# visible progress (this can be the whole site's uploads/img folders), same
# convention used for the DB dumps below — size estimated via `du` since tar
# doesn't know the final archive size upfront. zstd -T0 (already installed,
# no extra package needed) spreads compression across every core instead of
# gzip's single-threaded squeeze — much faster on a big uploads/img tree.
echo_prestashop "Archiving files for backup..."
FILES_SIZE=$(du -sb "$LOCAL_DIR" | cut -f1)
tar -cf - -C "$(dirname "$LOCAL_DIR")" "$(basename "$LOCAL_DIR")" \
    | pv --force -s "$FILES_SIZE" \
    | zstd -T0 > "$BACKUP_DIR/files_pre_upgrade.tar.zst" \
    || { echo_error "Archiving '$LOCAL_DIR' failed (tar/pv/zstd)."; exit 1; }
[ -s "$BACKUP_DIR/files_pre_upgrade.tar.zst" ] \
    || { echo_error "files_pre_upgrade.tar.zst is empty — check '$LOCAL_DIR' before continuing."; exit 1; }
echo_success "Files backup saved to: $BACKUP_DIR/files_pre_upgrade.tar.zst"
save_state 3

# ────────────────────────────────────────────────────────────────
# Step 4 - Bring the production DB down to local (name already resolved
# above; get_database already has its own dump validation — --yes only
# skips its "Continue? [y/N]" prompt, not the corrupted-dump one)
# ────────────────────────────────────────────────────────────────
# This is the one step worth offering to skip on resume: unlike step 3's
# rsync (naturally incremental — reruns fast if most files are already
# there), get_database drops+recreates the whole local DB from scratch every
# time, so re-pulling after an interruption redoes 100% of a possibly large
# transfer for no reason if a valid pull is already sitting right here from
# the previous attempt (same BACKUP_DIR) and the local DB it produced is
# still around.
SKIP_DB_PULL=0
if [ -s "$BACKUP_DIR/db_pre_upgrade.sql" ] \
    && tail -n 5 "$BACKUP_DIR/db_pre_upgrade.sql" | grep -q -- "-- Dump completed on" \
    && mysql -h 127.0.0.1 --protocol=TCP -N -e "SHOW DATABASES LIKE '${DATABASE_NAME}'" | grep -qx "$DATABASE_NAME"; then
    echo_info "Found an already-pulled, valid database backup from a previous attempt ($BACKUP_DIR/db_pre_upgrade.sql), and the local database still exists."
    read -rp "Reuse it and skip re-pulling from production? [y/N]: " reuse_answer
    case "$reuse_answer" in
        [Yy]*) SKIP_DB_PULL=1 ;;
    esac
fi

if [ "$SKIP_DB_PULL" = "1" ]; then
    echo_prestashop "Step 4: get_database — skipped, reusing the previous pull"
else
    echo_prestashop "Step 4: get_database — pulling '$DATABASE_NAME' from production to local"
    run_or_abort "get_database" get_database --yes --skip-dev "$DATABASE_NAME"

    # DB backup (rollback safety net): get_database already downloaded the raw,
    # untouched production dump to this exact path before importing/mutating it
    # locally — reuse it instead of running a second mysqldump against production.
    check_dump "$HOME/Downloads/${DATABASE_NAME}.sql"
    cp "$HOME/Downloads/${DATABASE_NAME}.sql" "$BACKUP_DIR/db_pre_upgrade.sql"
    echo_success "Database backup saved to: $BACKUP_DIR/db_pre_upgrade.sql"
fi
save_state 4

# ────────────────────────────────────────────────────────────────
# Step 5 - Update locally
# ────────────────────────────────────────────────────────────────
echo_prestashop "Step 5: update_prestashop"
# update_prestashop now handles its own loop-until-stable, PHP-compatibility
# switching (as PS_VERSION climbs across majors), and final autoupgrade-module
# cleanup internally — this used to all live here, moved into the function
# itself so it also benefits standalone/interactive calls (prestashop.sh).
# --no-backup: steps 3/4 already took a full files+DB backup of production
# before touching anything, so the Update Assistant's own backup:create here
# would just be a second, redundant local backup.
run_or_abort "update_prestashop" update_prestashop --no-backup "$LOCAL_DOMAIN"
save_state 5

# ────────────────────────────────────────────────────────────────
# Step 6 - Compatibility fixes
# ────────────────────────────────────────────────────────────────
echo_prestashop "Step 6: compatibility fixes"
if [ -f "${LOCAL_DIR}/_upgrade_fixes.sh" ]; then
    bash "${LOCAL_DIR}/_upgrade_fixes.sh" "$LOCAL_DIR"
else
    echo_error "${LOCAL_DIR}/_upgrade_fixes.sh not found — apply the manual fixes before continuing. Continue anyway? [y/N]"
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]] || { echo_error "Aborted before applying compatibility fixes."; exit 1; }
fi
save_state 6

# ────────────────────────────────────────────────────────────────
# Manual confirmation - validate the local site before touching production again
# ────────────────────────────────────────────────────────────────
echo_error "Confirm that https://${LOCAL_DOMAIN} is all OK (homepage, product, checkout) before continuing. [y/N]"
read -r answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo_error "Aborted before the push to production. Nothing was written to production."; exit 1; }

# ────────────────────────────────────────────────────────────────
# Step 7 - Push files to production (dry-run first, always)
# ────────────────────────────────────────────────────────────────
RSYNC_EXCLUDES="--exclude=/config/settings.inc.php --exclude=/app/config/parameters.php --exclude=/app/config/parameters.yml --exclude=/.htaccess --exclude=/.env --exclude=/.git/ --exclude=/_upgrade_fixes.sh"
RSYNC_EXCLUDES="$RSYNC_EXCLUDES --exclude=/cache/ --exclude=/var/cache/ --exclude=/var/logs/"
RSYNC_EXCLUDES="$RSYNC_EXCLUDES --exclude=/img/p/"

confirm_production "send files to production (dry-run first)"
echo_prestashop "Step 7a: rsync --dry-run (local -> production)"
DRY_OUTPUT=$(rsync -an --itemize-changes --delete $RSYNC_EXCLUDES "${LOCAL_DIR}/" "${ACCOUNT}@server:/home/${ACCOUNT}/${ROOT_DIR}/" 2>&1) \
    || { echo_error "rsync --dry-run failed — nothing was sent to production. Output:"; echo "$DRY_OUTPUT"; exit 1; }
# `tail -n 30` alone can hide changes on a big diff — for a --delete rsync
# into PRODUCTION that's not acceptable: deletions (marked "*deleting" by
# --itemize-changes) are shown in full regardless of size, plus a total count
# (`grep -c .` guarded with `|| true`: it exits 1 on a zero count, which would
# otherwise trip `set -e` on a perfectly fine "nothing to sync" run), with the
# tail only as a quick preview of what the diff generally looks like.
DELETIONS=$(echo "$DRY_OUTPUT" | grep '^\*deleting' || true)
CHANGE_COUNT=$(echo "$DRY_OUTPUT" | grep -vE '^(sending incremental file list$|sent .* bytes|total size is)' | grep -c . || true)
if [ -n "$DELETIONS" ]; then
    echo_error "Files that will be DELETED from production:"
    echo "$DELETIONS"
fi
echo "$DRY_OUTPUT" | tail -n 30
echo_info "Changes previewed: $CHANGE_COUNT (source: $LOCAL_DIR -> destination: ${ACCOUNT}@server:~/$ROOT_DIR)"

confirm_production "apply the rsync for real against production (no --dry-run)"
echo_prestashop "Step 7b: real rsync (local -> production)"
rsync -a --delete --info=progress2 $RSYNC_EXCLUDES "${LOCAL_DIR}/" "${ACCOUNT}@server:/home/${ACCOUNT}/${ROOT_DIR}/" \
    || { echo_error "File push to production FAILED — production files may be left in a partial state. Fix the issue, then re-run manually: rsync -a --delete $RSYNC_EXCLUDES '${LOCAL_DIR}/' '${ACCOUNT}@server:/home/${ACCOUNT}/${ROOT_DIR}/'"; exit 1; }
save_state 7

# ────────────────────────────────────────────────────────────────
# Step 8 - Push the migrated DB to production
# ────────────────────────────────────────────────────────────────
confirm_production "import the migrated local DB into production (replaces the current DB for '$DOMAIN')"
echo_prestashop "Step 8: push the database"
echo_info "Dump upgraded database from local..."
# Likely the biggest dump in the whole run (production DB, post-upgrade) — pv
# gives visible progress, same convention get_database (mysql.sh) already uses,
# including the DB_SIZE_ESTIMATE_FACTOR correction (defined there, already in
# scope from the sourcing loop above) for the gap between information_schema's
# raw table size and the bigger text-dump size.
DB_MIGRATED_ESTIMATE=$(mysql -h 127.0.0.1 --protocol=TCP -N -e "SELECT SUM(data_length + index_length) FROM information_schema.tables WHERE table_schema='${DATABASE_NAME}'")
DB_MIGRATED_ESTIMATE=$(( ${DB_MIGRATED_ESTIMATE:-0} * DB_SIZE_ESTIMATE_FACTOR / 100 ))
mysqldump -h 127.0.0.1 --protocol=TCP --single-transaction --quick "$DATABASE_NAME" \
    | pv --force -s "$DB_MIGRATED_ESTIMATE" > "$BACKUP_DIR/db_migrated.sql" \
    || { echo_error "Local dump of '$DATABASE_NAME' failed."; exit 1; }
check_dump "$BACKUP_DIR/db_migrated.sql"

# Size known exactly now (file already on disk) — real %/ETA, not an estimate.
DB_MIGRATED_SIZE=$(stat -c %s "$BACKUP_DIR/db_migrated.sql")
# mysql stops at the first failing statement (no --force), so a mid-dump error
# can leave production with some tables migrated and others not — point
# straight at the pre-upgrade backup rather than just letting `set -e` abort
# with a generic message. `pipefail` (set at the top) makes `||` see ssh/mysql's
# exit code here, not pv's.
echo_info "Upload updated database to production..."
pv --force -s "$DB_MIGRATED_SIZE" "$BACKUP_DIR/db_migrated.sql" | ssh root@server "mysql ${DATABASE_NAME}" \
    || { echo_error "DB import into production FAILED — production may be left in a partial state. Restore from: $BACKUP_DIR/db_pre_upgrade.sql"; exit 1; }

# The dump above carries the *.test domain get_database wrote into
# ${PREFIX}_shop_url for local dev use — restore the real production domain(s)
# captured in step 2 before anyone hits the site again.
echo_prestashop "Step 8b: restore production domain(s) in ${PS_PREFIX}_shop_url"
ssh root@server "mysql ${DATABASE_NAME}" < "$BACKUP_DIR/shop_url_restore.sql" \
    || { echo_error "shop_url restore FAILED — production likely still has the .test domain from the DB import. Re-run manually: ssh root@server \"mysql ${DATABASE_NAME}\" < $BACKUP_DIR/shop_url_restore.sql"; exit 1; }
save_state 8

# ────────────────────────────────────────────────────────────────
# Step 9 - Validate, then turn maintenance off
# ────────────────────────────────────────────────────────────────
# Validate BEFORE going public, not after: maintenance mode still lets the
# backoffice through, and the front office too for any IP allow-listed in
# PS_MAINTENANCE_IP — turning maintenance off first and only asking to
# validate afterwards would mean real customers can hit a broken site before
# anyone confirms the migration actually worked.
# Best-effort admin folder guess from $LOCAL_DIR — it mirrors production 1:1
# after step 7's push, and the admin folder's random slug name isn't stored
# anywhere else this script has access to. Same candidate list guess_ps_admin_dir
# (prestashop.sh) uses for its own fzf pre-fill; here there's no fzf, so it's
# only usable when exactly one directory survives the filter.
ADMIN_DIR_GUESS=$(list_ps_admin_dir_candidates "$LOCAL_DIR" || true)
ADMIN_DIR_COUNT=$(printf '%s\n' "$ADMIN_DIR_GUESS" | grep -c . || true)

echo_info "Validate PRODUCTION now: homepage, product, checkout, etc.."
if [ "$ADMIN_DIR_COUNT" -eq 1 ]; then
    echo_info "Admin: https://$DOMAIN/$ADMIN_DIR_GUESS"
else
    echo_info "Admin: couldn't auto-detect the admin folder name — check $LOCAL_DIR manually."
fi
confirm_production "turn off maintenance mode (site becomes public again)"
ssh root@server "mysql ${DATABASE_NAME} -e \"UPDATE ${PS_PREFIX}_configuration SET value=1 WHERE name='PS_SHOP_ENABLE';\""

save_state done

echo_success "✅ Upgrade finished! The site is public again: https://$DOMAIN"
echo_info "Rollback available in: $BACKUP_DIR"
echo_info "  Files: files_pre_upgrade.tar.zst"
echo_info "  DB before: db_pre_upgrade.sql"
