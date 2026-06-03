#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/check_env.sh"

echo_info "Installing fuzzel..."

if command_exists fuzzel; then
    echo_success "Fuzzel already installed!"
    return
fi

sudo apt-get install fuzzel -y

# # Add Sway keybind if not present
# SWAY_CONFIG="$HOME/.config/sway/config"
#
# if [ -f "$SWAY_CONFIG" ]; then
#     if ! grep -q "fuzzel" "$SWAY_CONFIG"; then
#         echo "Adding keybind to Sway config..."
#         echo "" >> "$SWAY_CONFIG"
#         echo "# Fuzzel launcher" >> "$SWAY_CONFIG"
#         echo "bindsym \$mod+p exec fuzzel" >> "$SWAY_CONFIG"
#     fi
# fi
