#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

# Support both direct execution (exit) and sourcing (return)
exit() { [[ "${BASH_SOURCE[0]}" == "${0}" ]] && builtin exit "$@" || return "${1:-0}"; }

echo_info "Installing Real-ESRGAN (ncnn-vulkan)..."

INSTALL_DIR="/usr/local/bin"
MODELS_DIR="$USER_HOME/.local/share/realesrgan/models"

if command_exists realesrgan-ncnn-vulkan && [[ -n "$(find "$MODELS_DIR" -name '*.param' 2>/dev/null)" ]]; then
    echo_success "Real-ESRGAN already installed!"
    exit 0
fi

# Vulkan runtime (AMD/Intel/Nvidia) + unzip
install_package libvulkan1
install_package mesa-vulkan-drivers
install_package unzip

# Use the self-contained bundle from xinntao/Real-ESRGAN — binary and models
# are guaranteed to be compatible since they ship together.
echo_info "Fetching bundled release (binary + models)..."
BUNDLE_URL=$(curl -sfL --max-time 10 \
    "https://api.github.com/repos/xinntao/Real-ESRGAN/releases" | python3 -c "
import sys, json
releases = json.load(sys.stdin)
for r in releases:
    for a in r.get('assets', []):
        u = a.get('browser_download_url', '')
        size = a.get('size', 0)
        if u.endswith('.zip') and 'ubuntu' in u and 'ncnn-vulkan' in u and size > 30_000_000:
            print(u)
            exit()
" 2>/dev/null)

if [[ -z "$BUNDLE_URL" ]]; then
    echo_error "Could not find bundled release in xinntao/Real-ESRGAN"
    exit 1
fi

BUNDLE_VER=$(basename "$BUNDLE_URL" | grep -oP '\d{8}')
echo_info "Downloading bundle $BUNDLE_VER (~47MB)..."

TMP_DIR=$(mktemp -d)
wget -q --show-progress -O "$TMP_DIR/bundle.zip" "$BUNDLE_URL" \
    || { echo_error "Failed to download bundle"; rm -rf "$TMP_DIR"; exit 1; }

unzip -q "$TMP_DIR/bundle.zip" -d "$TMP_DIR/esrgan" \
    || { echo_error "Failed to extract bundle"; rm -rf "$TMP_DIR"; exit 1; }

# Install binary
BINARY=$(find "$TMP_DIR/esrgan" -name "realesrgan-ncnn-vulkan" -type f | head -1)
if [[ -z "$BINARY" ]]; then
    echo_error "Binary not found in bundle"
    rm -rf "$TMP_DIR"; exit 1
fi

sudo install -m 755 "$BINARY" "$INSTALL_DIR/" \
    || { echo_error "Failed to install binary"; rm -rf "$TMP_DIR"; exit 1; }

# Install models
MODELS_SRC=$(find "$TMP_DIR/esrgan" -name "models" -type d | head -1)
if [[ -z "$MODELS_SRC" ]]; then
    echo_error "models/ not found in bundle"
    rm -rf "$TMP_DIR"; exit 1
fi

ensure_dir "$MODELS_DIR"
cp -r "$MODELS_SRC/"* "$MODELS_DIR/" \
    || { echo_error "Failed to copy models"; rm -rf "$TMP_DIR"; exit 1; }

rm -rf "$TMP_DIR"

echo_success "Real-ESRGAN $BUNDLE_VER installed!"
echo_info "Binary: $INSTALL_DIR/realesrgan-ncnn-vulkan"
echo_info "Models: $MODELS_DIR"
echo_info ""
echo_info "Usage examples:"
echo_info "  realesrgan-ncnn-vulkan -i input.jpg -o output.jpg -m $MODELS_DIR"
echo_info "  realesrgan-ncnn-vulkan -i input.jpg -o output.jpg -m $MODELS_DIR -n realesrgan-x4plus"
echo_info "  realesrgan-ncnn-vulkan -i input.jpg -o output.jpg -m $MODELS_DIR -n realesrgan-x4plus-anime"
echo_info ""
echo_info "Available models:"
find "$MODELS_DIR" -name "*.param" 2>/dev/null | sed 's|.*/||; s|\.param||' | sort | while read -r m; do
    echo_info "  - $m"
done
