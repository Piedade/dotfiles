#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/../utils.sh

tag="1.47"
name="wayland-protocols"

echo_info "Installing $name $tag..."
repo_url="https://gitlab.freedesktop.org/wayland/wayland-protocols.git"
if git clone --depth=1 --filter=blob:none "$repo_url" wayland-protocols; then
    cd $name || exit 1

    # Fetch tags and attempt to checkout the requested tag, trying both raw and v-prefixed
    git fetch --tags --depth=1 >/dev/null 2>&1 || true
    checked_out=0
    for candidate in "$tag" "v$tag"; do
        if git rev-parse -q --verify "refs/tags/$candidate" >/dev/null; then
            git checkout -q "refs/tags/$candidate"
            checked_out=1
            break
        fi
    done

    if [ "$checked_out" -ne 1 ]; then
        echo "${ERROR} Tag $tag not found in $repo_url"
        echo "${NOTE} Available tags (truncated):"
        git tag --list | tail -n 20 || true
        exit 1
    fi
    
    # Install to /usr/local so pkg-config can prefer it over distro /usr
    meson setup build --prefix=/usr/local
    meson compile -C build -j"$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)"

    if sudo meson install -C build; then
        echo_success "$name installed successfully."
    else
        echo_error "Installation failed for $name v$tag"
    fi
  
    cd ..
else
    echo_error "Download failed for $name!"
fi

rm -rf ./$name
