#!/bin/bash
# Test suite for ~/.dotfiles install scripts
# Run from the dotfiles directory: bash test.sh

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
INSTALL_SH="$DOTFILES_DIR/install.sh"

PASS=0
FAIL=0
WARN=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[1;34m'
RESET='\033[0m'

pass() { echo -e "  ${GREEN}✓${RESET} $1"; ((PASS++)); }
fail() { echo -e "  ${RED}✗ FAIL${RESET} $1"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}⚠ WARN${RESET} $1"; ((WARN++)); }
header() { echo -e "\n${BLUE}══ $1 ══${RESET}"; }

# Scripts known to NOT be in install.sh intentionally
EXCLUDED_FROM_INSTALL=(
    "check_env.sh"
    "utils.sh"
    "mouse-battery-notify.sh"
    "backports.sh"
    "wireless.sh"
    "rofi.sh"
    "swappy.sh"
    "tableplus.sh"
    "ssh-agent.sh"
    "github.sh"
)

is_excluded() {
    local name="$1"
    for ex in "${EXCLUDED_FROM_INSTALL[@]}"; do
        [[ "$ex" == "$name" ]] && return 0
    done
    return 1
}

# ─── 1. SYNTAX CHECK ─────────────────────────────────────────────────────────
header "Syntax Check (bash -n)"
for f in "$SCRIPTS_DIR"/*.sh "$INSTALL_SH"; do
    name=$(basename "$f")
    if bash -n "$f" 2>/dev/null; then
        pass "$name"
    else
        fail "$name — $(bash -n "$f" 2>&1)"
    fi
done

# ─── 2. SHEBANG ──────────────────────────────────────────────────────────────
header "Shebang (#!/bin/bash)"
for f in "$SCRIPTS_DIR"/*.sh; do
    name=$(basename "$f")
    if head -1 "$f" | grep -q '^#!/bin/bash'; then
        pass "$name"
    else
        fail "$name — missing or wrong shebang"
    fi
done

# ─── 3. SCRIPT_DIR BEFORE SOURCE ─────────────────────────────────────────────
header "SCRIPT_DIR defined before source check_env.sh"
for f in "$SCRIPTS_DIR"/*.sh; do
    name=$(basename "$f")
    [[ "$name" == "check_env.sh" || "$name" == "utils.sh" ]] && continue

    if grep -q 'source.*check_env' "$f"; then
        script_dir_line=$(grep -n 'SCRIPT_DIR' "$f" | head -1 | cut -d: -f1)
        source_line=$(grep -n 'source.*check_env' "$f" | head -1 | cut -d: -f1)
        if [[ -n "$script_dir_line" && "$script_dir_line" -lt "$source_line" ]]; then
            pass "$name"
        else
            fail "$name — SCRIPT_DIR not defined before source check_env.sh"
        fi
    fi
done

# ─── 4. QUOTED SOURCE ────────────────────────────────────────────────────────
header "Quoted source check_env.sh"
for f in "$SCRIPTS_DIR"/*.sh; do
    name=$(basename "$f")
    # Check for unquoted source $SCRIPT_DIR/check_env.sh
    if grep -q 'source \$SCRIPT_DIR/check_env' "$f" 2>/dev/null; then
        fail "$name — source \$SCRIPT_DIR/check_env.sh not quoted"
    elif grep -q 'source.*check_env' "$f"; then
        pass "$name"
    fi
done

# ─── 5. NO EXIT IN SOURCED SCRIPTS ───────────────────────────────────────────
header "No 'exit' in sourced scripts (should use 'return')"
STANDALONE=("backports.sh" "install_kernel_backports.sh" "wireless.sh" "mouse-battery-notify.sh")
for f in "$SCRIPTS_DIR"/*.sh; do
    name=$(basename "$f")
    is_standalone=0
    for s in "${STANDALONE[@]}"; do [[ "$s" == "$name" ]] && is_standalone=1; done
    [[ $is_standalone -eq 1 ]] && continue

    # Find exit outside comments, ignoring subshells ( ... ) and functions only used standalone
    if grep -v '^\s*#' "$f" | grep -qE '^\s*exit\s'; then
        fail "$name — contains 'exit' (use 'return' in sourced scripts)"
    else
        pass "$name"
    fi
done

# ─── 6. NO SET -E ────────────────────────────────────────────────────────────
header "No 'set -e' in sourced scripts"
for f in "$SCRIPTS_DIR"/*.sh; do
    name=$(basename "$f")
    if grep -v '^\s*#' "$f" | grep -q '^set -e'; then
        fail "$name — has 'set -e' (dangerous when sourced)"
    else
        pass "$name"
    fi
done

# ─── 7. APT-GET WITH -Y ──────────────────────────────────────────────────────
header "apt-get install always has -y flag"
for f in "$SCRIPTS_DIR"/*.sh "$INSTALL_SH"; do
    name=$(basename "$f")
    bad=$(grep -n 'apt-get install' "$f" | grep -v '\-y' | grep -v '^\s*#')
    if [[ -n "$bad" ]]; then
        fail "$name — apt-get install without -y:"
        echo "$bad" | while read line; do echo "      $line"; done
    else
        pass "$name"
    fi
done

# ─── 8. NO SUDO_CMD VARIABLE ─────────────────────────────────────────────────
header "No \${SUDO_CMD} remaining (should use sudo directly)"
for f in "$SCRIPTS_DIR"/*.sh "$INSTALL_SH"; do
    name=$(basename "$f")
    [[ "$name" == "check_env.sh" ]] && continue  # defines SUDO_CMD historically
    if grep -v '^\s*#' "$f" | grep -q 'SUDO_CMD'; then
        fail "$name — still uses \${SUDO_CMD}"
    else
        pass "$name"
    fi
done

# ─── 9. NO HARDCODED USERNAME ────────────────────────────────────────────────
header "No hardcoded username 'piedade'"
for f in "$SCRIPTS_DIR"/*.sh "$INSTALL_SH"; do
    name=$(basename "$f")
    if grep -v '^\s*#' "$f" | grep -qw 'piedade'; then
        fail "$name — contains hardcoded username 'piedade'"
    else
        pass "$name"
    fi
done

# ─── 10. NO SLEEP ────────────────────────────────────────────────────────────
header "No unnecessary 'sleep' commands"
for f in "$SCRIPTS_DIR"/*.sh; do
    name=$(basename "$f")
    if grep -v '^\s*#' "$f" | grep -qE '^\s*sleep\s'; then
        fail "$name — contains sleep"
    else
        pass "$name"
    fi
done

# ─── 11. SCRIPTS REFERENCED IN INSTALL.SH ────────────────────────────────────
header "All scripts referenced in install.sh (or intentionally excluded)"
for f in "$SCRIPTS_DIR"/*.sh; do
    name=$(basename "$f")
    is_excluded "$name" && warn "$name — excluded from install.sh (intentional)" && continue
    if grep -q "$name" "$INSTALL_SH"; then
        pass "$name — found in install.sh"
    else
        fail "$name — NOT in install.sh and not in exclusion list"
    fi
done

# ─── 12. COMMAND_EXISTS CHECK ────────────────────────────────────────────────
header "Install scripts have 'already installed' check"
SKIP_CHECK=("check_env.sh" "utils.sh" "link_config.sh" "mouse-battery-notify.sh" "dnsmasq.sh" "apache.sh" "firewall.sh" "audio.sh" "sway.sh" "fonts.sh" "lxpolkit.sh")
for f in "$SCRIPTS_DIR"/*.sh; do
    name=$(basename "$f")
    skip=0
    for s in "${SKIP_CHECK[@]}"; do [[ "$s" == "$name" ]] && skip=1; done
    [[ $skip -eq 1 ]] && continue

    if grep -qE 'command_exists|command -v|\[ -d|\[ -f' "$f"; then
        pass "$name"
    else
        warn "$name — no 'already installed' check found"
    fi
done

# ─── 13. CD WITHOUT PUSHD/POPD ───────────────────────────────────────────────
header "No 'cd' without pushd/popd"
for f in "$SCRIPTS_DIR"/*.sh; do
    name=$(basename "$f")
    # Find bare `cd` that is not in a $() subshell and not a pushd/popd
    bare_cd=$(grep -v '^\s*#' "$f" | grep -v '\$(' | grep -v 'pushd\|popd' | grep -E '^\s*cd\s')
    if [[ -n "$bare_cd" ]]; then
        fail "$name — bare 'cd' without pushd/popd:"
        echo "$bare_cd" | while read line; do echo "      $line"; done
    else
        pass "$name"
    fi
done

# ─── 14. $USER WITHOUT QUOTES ────────────────────────────────────────────────
header "\$USER always quoted"
for f in "$SCRIPTS_DIR"/*.sh "$INSTALL_SH"; do
    name=$(basename "$f")
    # Match $USER not surrounded by quotes — skip $USER_HOME and ${SUDO_USER:-$USER}
    bad=$(grep -v '^\s*#' "$f" | grep -oP '[^"${\w]\$USER(?!_HOME|[A-Z_])' | head -1)
    if [[ -n "$bad" ]]; then
        warn "$name — \$USER may not be quoted (check manually)"
    else
        pass "$name"
    fi
done

# ─── 15. NO REDUNDANT SOURCE UTILS.SH ────────────────────────────────────────
header "No redundant 'source utils.sh' (check_env.sh already sources it)"
for f in "$SCRIPTS_DIR"/*.sh; do
    name=$(basename "$f")
    [[ "$name" == "check_env.sh" ]] && continue
    if grep -v '^\s*#' "$f" | grep -q 'source.*utils\.sh'; then
        fail "$name — sources utils.sh directly (check_env.sh already does this)"
    else
        pass "$name"
    fi
done

# ─── 16. WGET WITH ERROR HANDLING ────────────────────────────────────────────
header "wget downloads have error handling"
for f in "$SCRIPTS_DIR"/*.sh; do
    name=$(basename "$f")
    # Find wget lines that don't pipe to bash and don't have || error handling
    bad=$(grep -v '^\s*#' "$f" | grep 'wget' | grep -v '|\s*bash\||\s*sh\|-qO-\||| {' )
    if [[ -n "$bad" ]]; then
        warn "$name — wget without explicit error handling:"
        echo "$bad" | while read line; do echo "      $line"; done
    else
        pass "$name"
    fi
done

# ─── 17. APT-GET UPDATE BEFORE INSTALL (EXTERNAL REPOS) ─────────────────────
header "apt-get update present when external repo is added"
for f in "$SCRIPTS_DIR"/*.sh; do
    name=$(basename "$f")
    # If script adds a repo (sources.list or keyrings), check for apt-get update
    if grep -v '^\s*#' "$f" | grep -qE 'sources\.list|keyrings/.*gpg'; then
        if grep -v '^\s*#' "$f" | grep -q 'apt-get update\|apt update'; then
            pass "$name — adds repo and has apt-get update"
        else
            fail "$name — adds external repo but missing apt-get update"
        fi
    else
        pass "$name"
    fi
done

# ─── 18. NO DUPLICATE SOURCES IN INSTALL.SH ──────────────────────────────────
header "No duplicate source lines in install.sh"
dupes=$(grep '^source ' "$INSTALL_SH" | sort | uniq -d)
if [[ -n "$dupes" ]]; then
    fail "install.sh — duplicate source lines found:"
    echo "$dupes" | while read line; do echo "      $line"; done
else
    pass "install.sh — no duplicate sources"
fi

# ─── 19. LATEST VERSION CHECKS (requires internet) ──────────────────────────
header "Latest version checks (network — skipped if offline)"

# Check internet connectivity first
if ! curl -sf --max-time 5 https://api.github.com > /dev/null 2>&1; then
    warn "No internet connection — skipping version checks"
else
    # Helper: check GitHub latest release vs hardcoded version in a script
    check_github_version() {
        local script_file="$1"
        local repo="$2"
        local current="$3"
        local name
        name=$(basename "$script_file")

        latest=$(curl -sf --max-time 10 \
            "https://api.github.com/repos/$repo/releases/latest" \
            | grep -oP '"tag_name"\s*:\s*"\K[^"]*' | head -1)

        if [[ -z "$latest" ]]; then
            warn "$name — could not fetch latest from $repo (rate limited?)"
            return
        fi

        current_norm="${current#v}"; latest_norm="${latest#v}"
        if [[ "$current_norm" == "$latest_norm" ]]; then
            pass "$name — $current is latest"
        else
            fail "$name — OUTDATED: current=$current, latest=$latest"
        fi
    }

    # Read versions directly from scripts
    swappy_ver=$(grep -oP '(?<=tag=")[^"]+' "$SCRIPTS_DIR/swappy.sh" | head -1)
    rofi_ver=$(grep -oP '(?<=tag=")[^"]+' "$SCRIPTS_DIR/rofi.sh" | head -1)
    mysql_ver=$(grep -oP 'mysql-apt-config_[\d.]+-\d+(?=_all)' "$SCRIPTS_DIR/mysql.sh" | head -1)
    android_ver=$(grep -oP '(?<=ide-zips/)[\d.]+(?=/)' "$SCRIPTS_DIR/android.sh" | head -1)

    # obsidian.sh uses GitHub API dynamically — no version to check
    pass "obsidian.sh — always installs latest (dynamic via GitHub API)"
    check_github_version "$SCRIPTS_DIR/swappy.sh"   "jtheoof/swappy"              "$swappy_ver"
    check_github_version "$SCRIPTS_DIR/rofi.sh"     "davatorium/rofi"              "$rofi_ver"

    # MySQL apt-config — check dev.mysql.com downloads page
    latest_mysql=$(curl -sf --max-time 10 "https://dev.mysql.com/downloads/repo/apt/" \
        | grep -oP 'mysql-apt-config_[\d.]+-\d+_all\.deb' | head -1 \
        | grep -oP 'mysql-apt-config_[\d.]+-\d+')
    if [[ -z "$latest_mysql" ]]; then
        warn "mysql.sh — could not fetch latest mysql-apt-config"
    elif [[ "$latest_mysql" == "$mysql_ver" ]]; then
        pass "mysql.sh — $mysql_ver is latest"
    else
        fail "mysql.sh — OUTDATED: current=$mysql_ver, latest=$latest_mysql"
    fi

    # Android Studio — verify current URL resolves (HTTP 200 after redirect)
    # then probe for newer patch versions
    android_base_url="https://redirector.gvt1.com/edgedl/android/studio/ide-zips"
    android_http=$(curl -sf --max-time 10 -o /dev/null -w "%{http_code}" -L \
        "${android_base_url}/${android_ver}/android-studio-${android_ver}-linux.tar.gz")

    if [[ "$android_http" != "200" ]]; then
        fail "android.sh — URL for $android_ver returned HTTP $android_http (version outdated or removed)"
    else
        # Probe for a newer patch version (increment last digit)
        IFS='.' read -ra parts <<< "$android_ver"
        next_patch="${parts[0]}.${parts[1]}.${parts[2]}.$((parts[3]+1))"
        next_http=$(curl -sf --max-time 8 -o /dev/null -w "%{http_code}" -L \
            "${android_base_url}/${next_patch}/android-studio-${next_patch}-linux.tar.gz")
        if [[ "$next_http" == "200" ]]; then
            fail "android.sh — OUTDATED: current=$android_ver, newer patch exists ($next_patch+)"
        else
            pass "android.sh — $android_ver is latest stable"
        fi
    fi
fi

# ─── SUMMARY ─────────────────────────────────────────────────────────────────
echo -e "\n${BLUE}══ SUMMARY ══${RESET}"
echo -e "  ${GREEN}PASS: $PASS${RESET}"
echo -e "  ${YELLOW}WARN: $WARN${RESET}"
echo -e "  ${RED}FAIL: $FAIL${RESET}"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}All checks passed!${RESET}"
    exit 0
else
    echo -e "${RED}$FAIL check(s) failed. Fix before running install.sh${RESET}"
    exit 1
fi
