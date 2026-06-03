#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Configuring Wayland compatibility..."

# ─── systemd user environment ─────────────────────────────────────────────────
ENVD_DIR="$HOME/.config/environment.d"
mkdir -p "$ENVD_DIR"

cat > "$ENVD_DIR/wayland.conf" << 'EOF'
# Mozilla apps (Firefox, Thunderbird) — Wayland backend
MOZ_ENABLE_WAYLAND=1
EOF

echo_success "systemd environment.d/wayland.conf created"

# ─── Beekeeper Studio ─────────────────────────────────────────────────────────
# v5.6.2 (2026) still requires explicit Wayland opt-in.
# --disable-features=WaylandWpColorManagerV1 fixes color distortion (yellows/greys).
BKS_FLAGS="$HOME/.config/bks-flags.conf"
if [ ! -f "$BKS_FLAGS" ]; then
    cat > "$BKS_FLAGS" << 'EOF'
--ozone-platform-hint=auto
--enable-features=UseOzonePlatform
--disable-features=WaylandWpColorManagerV1
EOF
    echo_success "Beekeeper Studio Wayland flags configured"
else
    echo_info "Beekeeper Studio flags already exist — skipping"
fi


# ─── Reload systemd user environment ──────────────────────────────────────────
if command_exists systemctl; then
    systemctl --user import-environment 2>/dev/null || true
    echo_info "Systemd user environment reloaded (full effect on next login)"
fi

echo_success "Wayland compatibility configured!"
