#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/../utils.sh

name="hyprwire"
tag="v0.2.1"

# Force the compatibility shim used on Debian 13 (trixie) toolchains.
FORCE_SHIM=1

echo_info "Installing $name $tag..."

# Clone and build
if git clone --recursive -b "$tag" https://github.com/hyprwm/hyprwire.git; then
  cd $name || exit 1
  BUILD_DIR="./build/hyprwire"
  mkdir -p "$BUILD_DIR"

  # Decide whether we need the append_range compatibility shim.
  # On Debian 13 (trixie), libstdc++ typically lacks std::vector::append_range, so we patch.
  # On newer toolchains (testing/sid), prefer building upstream unmodified.
  NEED_SHIM=0
  if [ "$NO_SHIM" -eq 1 ]; then
    NEED_SHIM=0
  elif [ "$FORCE_SHIM" -eq 1 ]; then
    NEED_SHIM=1
  else
    CXX_TEST="${CXX:-c++}"
    TMPD="$(mktemp -d)"
    cat >"$TMPD/append_range_test.cpp" <<'EOF'
#include <vector>
int main() {
  std::vector<unsigned char> v;
  v.append_range(std::vector<unsigned char>{1,2,3});
  return 0;
}
EOF
    if "$CXX_TEST" -std=c++23 -c "$TMPD/append_range_test.cpp" -o /dev/null >/dev/null 2>&1; then
      NEED_SHIM=0
    else
      NEED_SHIM=1
    fi
    rm -rf "$TMPD"
  fi

  if [ "$NEED_SHIM" -eq 1 ]; then
    echo "${NOTE} Applying append_range compatibility shim (use --no-shim to disable; --build-trixie to force)."

    # Temporary compatibility shim for toolchains where libstdc++ lacks std::vector::append_range (C++23 library feature).
    # Note: append_range in upstream accepts temporaries (e.g. encodeVarInt(...) returns a temporary vector). To support that,
    # we bind the expression to a named auto&& first.
    cat > append_range_compat.hpp <<'EOF'
#pragma once
#include <iterator>

// Append any begin/end range to a container, supporting temporaries by binding to auto&&.
#define APPEND_RANGE(vec, ...) do { \
  auto&& _r = (__VA_ARGS__); \
  (vec).insert((vec).end(), std::begin(_r), std::end(_r)); \
} while(0)
EOF

    # Replace X.(.|->)append_range(Y) -> APPEND_RANGE(X, Y) only where it appears
    PATCH_FILES=$(grep -RIl --exclude-dir=.git -F 'append_range(' . || true)
    if [ -n "$PATCH_FILES" ]; then
      # LHS: identifiers and common member/ptr chains (this->obj, ns::obj.member)
      echo "$PATCH_FILES" | xargs -r sed -ri 's/([A-Za-z_][A-Za-z0-9_:>.\-]+)\s*(\.|->)\s*append_range\s*\(/APPEND_RANGE(\1, /g'
      # Show any remaining occurrences
      REMAIN=$(grep -RIn --exclude-dir=.git -E '(\.|->)[[:space:]]*append_range[[:space:]]*\(' $PATCH_FILES || true)
      if [ -n "$REMAIN" ]; then
        echo "[WARN] Some append_range() calls remain unpatched:" >&2
        echo "$REMAIN" >&2
      fi
    fi

    # Absolute path for forced include
    APPEND_HDR="$(pwd)/append_range_compat.hpp"

    cmake -S . -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_CXX_STANDARD=23 -DCMAKE_CXX_FLAGS="-include ${APPEND_HDR}"
  else
    echo "${NOTE} Toolchain supports std::vector::append_range; building hyprwire without shim."
    cmake -S . -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_CXX_STANDARD=23
  fi
  cmake --build "$BUILD_DIR" -j "$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)"

    if sudo cmake --install "$BUILD_DIR"; then
      echo_success "$name installed successfully."
    else
      echo_error "Installation failed for $name"
    fi

  cd ..
else
    echo_error "Download failed for $name!"
fi

rm -rf ./$name
