#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing satty..."

sudo apt-get install -y \
    git \
    make \
    pkg-config \
    build-essential \
    grim \
    slurp \
    wl-clipboard \
    libxkbcommon-dev \
    libwayland-dev \
    libgtk-4-dev \
    libadwaita-1-dev

echo "Installing Rust toolchain (if missing)..."

[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

if ! command -v cargo >/dev/null 2>&1; then
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
fi

SATTY_TAG="v0.20.1"

echo "Cloning Satty $SATTY_TAG..."

rm -rf "$SCRIPT_DIR/satty"
git clone --branch "$SATTY_TAG" --depth 1 https://github.com/gabm/Satty.git "$SCRIPT_DIR/satty" \
    || { echo_error "Failed to clone Satty $SATTY_TAG"; return 1; }

pushd "$SCRIPT_DIR/satty" > /dev/null

echo "Building release binary..."

make build-release || { echo_error "Satty build failed!"; popd > /dev/null; rm -rf "$SCRIPT_DIR/satty"; return 1; }

echo_info "Installing..."
sudo PREFIX=/usr/local make install || { echo_error "Satty install failed!"; popd > /dev/null; rm -rf "$SCRIPT_DIR/satty"; return 1; }

popd > /dev/null
rm -rf "$SCRIPT_DIR/satty"
