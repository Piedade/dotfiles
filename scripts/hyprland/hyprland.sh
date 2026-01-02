#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/../utils.sh

deps=(
  clang
  llvm
  libxcb-errors-dev
  libre2-dev
  libglaze-dev
  libudis86-dev
  libinotify-ocaml-dev
)

echo_info "Installing dependencies..."
for dep in "${deps[@]}"; do
    install_package "$dep"
    if [ $? -ne 0 ]; then
        echo_error "$dep installation failed!"
        exit 1
    fi
done

name="Hyprland"
tag="v0.52.2"

# Glaze, is neeeded ??
echo_info "Installing Hyprland additional dependencies (glaze)..."
if [ ! -d /usr/include/glaze ]; then
    echo_info "Glaze is not installed. Installing glaze from assets..."
    sudo dpkg -i $SCRIPT_DIR/assets/libglaze-dev_4.4.3-1_all.deb
    sudo apt-get install -f -y
    echo_success "libglaze-dev from assets installed."
fi

echo_info "Installing $name $tag..."
if git clone --recursive -b $tag "https://github.com/hyprwm/Hyprland"; then
    cd $name || exit 1

    # Apply patch only if it applies cleanly; otherwise skip
    if [ -f $SCRIPT_DIR/assets/0001-fix-hyprland-compile-issue.patch ]; then
      if patch -p1 --dry-run < $SCRIPT_DIR/assets/0001-fix-hyprland-compile-issue.patch >/dev/null 2>&1; then
        patch -p1 < $SCRIPT_DIR/assets/0001-fix-hyprland-compile-issue.patch
      else
        echo_info "Hyprland compile patch does not apply on $tag; skipping."
      fi
    fi

    # By default, build Hyprland with bundled hyprutils/hyprlang to avoid version mismatches
    # You can force system libs by exporting USE_SYSTEM_HYPRLIBS=1 before running this script.
    USE_SYSTEM=${USE_SYSTEM_HYPRLIBS:-1}
    if [ "$USE_SYSTEM" = "1" ]; then
      export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:${PKG_CONFIG_PATH:-}"
      export CMAKE_PREFIX_PATH="/usr/local:${CMAKE_PREFIX_PATH:-}"
      SYSTEM_FLAGS=("-DUSE_SYSTEM_HYPRUTILS=ON" "-DUSE_SYSTEM_HYPRLANG=ON")
    else
      # Ensure we do not accidentally pick up mismatched system headers
      unset PKG_CONFIG_PATH || true
      SYSTEM_FLAGS=("-DUSE_SYSTEM_HYPRUTILS=OFF" "-DUSE_SYSTEM_HYPRLANG=OFF")
    fi

    # Make sure submodules are present when building bundled deps
    git submodule update --init --recursive || true

    # Force Clang toolchain to support required language features and flags
    export CC="${CC:-clang}"
    export CXX="${CXX:-clang++}"
    CONFIG_FLAGS=(
      -DCMAKE_BUILD_TYPE=Release
      -DCMAKE_C_COMPILER="${CC}"
      -DCMAKE_CXX_COMPILER="${CXX}"
      -DCMAKE_CXX_STANDARD=26
      -DCMAKE_CXX_STANDARD_REQUIRED=ON
      -DCMAKE_CXX_EXTENSIONS=ON
      "${SYSTEM_FLAGS[@]}"
    )

    cmake -S . -B build "${CONFIG_FLAGS[@]}"
    cmake --build build -j "$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)"

    if sudo cmake --install ./build; then
        echo_success "$name installed successfully."
    else
        echo_error "Installation failed for $name"
        exit 1
    fi

    cd ..
else
    echo_error "Download failed for $name!"
fi

rm -rf ./$name