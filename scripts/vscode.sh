#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/utils.sh
source $SCRIPT_DIR/check_env.sh

echo_info "Installing VS Code..."

wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
"${SUDO_CMD}" install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | "${SUDO_CMD}" tee /etc/apt/sources.list.d/vscode.list > /dev/null
rm -f packages.microsoft.gpg
"${SUDO_CMD}" apt-get update
"${SUDO_CMD}" apt-get install -y apt-transport-https code


# Fix weak password store
VSCODE_ARGV="${HOME}/.vscode/argv.json"
mkdir -p "${HOME}/.vscode"

# If file doesn't exist → create minimal JSON
if [ ! -f "$VSCODE_ARGV" ]; then
    cat > "$VSCODE_ARGV" <<'EOF'
{
  "password-store": "gnome-libsecret"
}
EOF
    echo "[INFO] Created argv.json with password-store"
else
    # Check if password-store already exists
    if grep -q '"password-store"' "$VSCODE_ARGV"; then
        echo "[INFO] password-store already set in argv.json"
    else
        # Insert before the last closing brace
        # Detect if any existing properties exist (ignoring comments)
        PROPS_EXIST=$(grep -E -v '^\s*//|^\s*$' "$VSCODE_ARGV" | grep -c ':')
        if [ "$PROPS_EXIST" -gt 0 ]; then
            # Add with a leading comma
            sed -i '/^[[:space:]]*}/ i\  , "password-store": "gnome-libsecret"' "$VSCODE_ARGV"
        else
            # No other properties → insert without comma
            sed -i '/^[[:space:]]*}/ i\  "password-store": "gnome-libsecret"' "$VSCODE_ARGV"
        fi
        echo "[INFO] Added password-store to argv.json"
    fi
fi

echo_success "VS Code installed!"
