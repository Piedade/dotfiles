#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/utils.sh

set -e

echo_info "Installing dependencies..."

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

echo "Cloning Satty..."

rm -rf "$SCRIPT_DIR/satty"
git clone https://github.com/gabm/Satty.git "$SCRIPT_DIR/satty"

pushd "$SCRIPT_DIR/satty" > /dev/null

echo "Building release binary..."

make build-release

echo_info "Installing..."
sudo PREFIX=/usr/local make install

popd > /dev/null
rm -rf "$SCRIPT_DIR/satty"
