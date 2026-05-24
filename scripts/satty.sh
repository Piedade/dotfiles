#!/bin/bash

set -e

echo "Installing dependencies..."

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

if ! command -v cargo >/dev/null 2>&1; then
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
fi

echo "Cloning Satty..."

rm -rf "$HOME/satty"
git clone https://github.com/gabm/Satty.git "$HOME/satty"

cd "$HOME/satty"

echo "Building release binary..."

make build-release

echo "Installing (optional)..."
sudo PREFIX=/usr/local make install

cd ..
rm -rf ./satty
