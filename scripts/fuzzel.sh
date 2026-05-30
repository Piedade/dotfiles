#!/bin/bash

echo_info "Installing fuzzel..."

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
