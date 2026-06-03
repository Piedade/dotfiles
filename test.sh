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
SKIP_CHECK=("check_env.sh" "utils.sh" "link_config.sh" "mouse-battery-notify.sh" "dnsmasq.sh" "apache.sh" "firewall.sh" "audio.sh" "sway.sh" "fonts.sh" "lxpolkit.sh" "vim.sh" "wireless.sh")
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
    # Match bare $USER not in quotes and not inside ${...:-$USER} expansions
    bad=$(grep -v '^\s*#' "$f" \
        | grep -v 'SUDO_USER' \
        | grep -oP '(?<!["{$\w])\$USER(?!_HOME|[A-Z_:}])' | head -1)
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
    # Join continuation lines (\) so multi-line wget+|| is treated as one
    bad=$(grep -v '^\s*#' "$f" \
        | tr '\n' '\r' \
        | sed 's/\\\r/ /g' \
        | tr '\r' '\n' \
        | grep 'wget' \
        | grep -vE '\|\s*bash|\|\s*sh|-qO-|\|\| \{|wget -q' \
        | grep -v "='" \
        | grep -vE 'wget.*&&|&&.*wget')
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

# ─── 19. WAYLAND COMPATIBILITY ───────────────────────────────────────────────
# Each check answers: "should this workaround be active, and is it configured correctly?"
# PASS = correct state | FAIL = wrong state | WARN = not installed yet
header "Wayland compatibility"

wayland_env="$HOME/.config/environment.d/wayland.conf"
android_ver=$(grep -oP '(?<=ide-zips/)[\d.]+(?=/)' "$SCRIPTS_DIR/android.sh" | head -1)
android_major=$(echo "${android_ver:-0}" | cut -d. -f1)

# ── Mozilla (Firefox/Thunderbird) — always needed ────────────────────────────
if [ ! -f "$wayland_env" ]; then
    warn "MOZ_ENABLE_WAYLAND — wayland.conf missing (run wayland-compat.sh)"
elif grep -q "MOZ_ENABLE_WAYLAND" "$wayland_env"; then
    pass "MOZ_ENABLE_WAYLAND — set (needed for Firefox/Thunderbird)"
else
    fail "MOZ_ENABLE_WAYLAND — missing from wayland.conf"
fi

# ── Android Studio — needed only for < 2026.1 ────────────────────────────────
if [[ "$android_major" -ge 2026 ]]; then
    # Wayland native — only show if workaround is incorrectly still present
    if grep -q "_JAVA_AWT_WM_NONREPARENTING" "$wayland_env" 2>/dev/null; then
        warn "_JAVA_AWT_WM_NONREPARENTING — android.sh $android_ver is Wayland native, remove from wayland.conf"
    fi
else
    # < 2026.1 needs XWayland workaround
    if [ ! -f "$wayland_env" ]; then
        warn "_JAVA_AWT_WM_NONREPARENTING — wayland.conf missing (run wayland-compat.sh)"
    elif grep -q "_JAVA_AWT_WM_NONREPARENTING" "$wayland_env"; then
        pass "_JAVA_AWT_WM_NONREPARENTING — set (android.sh $android_ver < 2026.1 needs XWayland)"
    else
        fail "_JAVA_AWT_WM_NONREPARENTING — missing from wayland.conf (android.sh $android_ver < 2026.1)"
    fi
fi

# ── Chrome — 140+ auto-detects, only show if flags.conf exists (redundant) ───
if [ -f "$HOME/.config/google-chrome-flags.conf" ]; then
    warn "Chrome — flags.conf exists but is redundant (Chrome 140+ auto-detects Wayland)"
fi

# ── VS Code — Electron 38+ auto-detects, only show if config exists (redundant)
if [ -f "$HOME/.vscode/argv.json" ] && grep -q "ozone-platform-hint" "$HOME/.vscode/argv.json"; then
    warn "VS Code — ozone-platform-hint in argv.json is redundant (Electron 38+ auto-detects Wayland)"
fi

# ── Beekeeper Studio — v5.6.2 still requires explicit opt-in ─────────────────
BKS="$HOME/.config/bks-flags.conf"
if [ ! -f "$BKS" ]; then
    warn "Beekeeper Studio — bks-flags.conf missing (run wayland-compat.sh)"
elif grep -q "ozone-platform-hint" "$BKS" && grep -q "WaylandWpColorManagerV1" "$BKS"; then
    pass "Beekeeper Studio — Wayland flags set (still required in v5.6.2)"
else
    fail "Beekeeper Studio — bks-flags.conf incomplete (missing ozone-platform-hint or WaylandWpColorManagerV1)"
fi

# ── wayland-compat.sh in install.sh ──────────────────────────────────────────
if grep -q "wayland-compat.sh" "$INSTALL_SH"; then
    pass "wayland-compat.sh referenced in install.sh"
else
    fail "wayland-compat.sh NOT in install.sh"
fi

# ─── 20. LATEST VERSION CHECKS (requires internet) ──────────────────────────
header "Latest version checks (network — skipped if offline)"

# Check internet connectivity (use a reliable non-rate-limited endpoint)
if ! curl -sf --max-time 5 https://www.google.com > /dev/null 2>&1 && \
   ! curl -sf --max-time 5 https://debian.org > /dev/null 2>&1; then
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

    # Only check scripts that ARE in install.sh and have hardcoded versions
    mysql_ver=$(grep -oP 'mysql-apt-config_[\d.]+-\d+(?=_all)' "$SCRIPTS_DIR/mysql.sh" | head -1)
    android_ver=$(grep -oP '(?<=ide-zips/)[\d.]+(?=/)' "$SCRIPTS_DIR/android.sh" | head -1)
    satty_ver=$(grep -oP '(?<=SATTY_TAG=")[^"]+' "$SCRIPTS_DIR/satty.sh" | head -1)

    # obsidian.sh uses GitHub API dynamically — always installs latest
    pass "obsidian.sh — always installs latest (dynamic via GitHub API)"
    check_github_version "$SCRIPTS_DIR/satty.sh" "gabm/Satty" "$satty_ver"

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

    # Android Studio — fetch latest stable from official releases page
    latest_android=$(curl -sf --max-time 15 "https://developer.android.com/studio/releases" \
        | grep -oP 'ide-zips/\K[\d.]+(?=/)' | head -1)

    if [[ -z "$latest_android" ]]; then
        warn "android.sh — could not fetch latest version from developer.android.com/studio/releases"
    elif [[ "$latest_android" == "$android_ver" ]]; then
        pass "android.sh — $android_ver is latest stable"
    else
        fail "android.sh — OUTDATED: current=$android_ver, latest=$latest_android"
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
