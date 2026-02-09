#!/usr/bin/env bash

# Folder with wallpapers
WALLDIR="$HOME/.dotfiles/backgrounds"

# Get connected monitors
# You can list them manually or query via hyprctl
outputs=$(hyprctl monitors | grep "Monitor" | awk '{print $2}')

# Loop through each monitor and set a random wallpaper
for output in $outputs; do
    # Pick a random image
    WALL=$(find "$WALLDIR" -type f | shuf -n 1)
    # Set wallpaper with fill mode
    swaybg -o "$output" -i "$WALL" -m fill &
done
