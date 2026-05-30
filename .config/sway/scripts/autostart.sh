#!/bin/bash

# Autostart applications
## Notification daemon
pkill -x swaync
swaync -c ~/.config/swaync/config.json -s ~/.config/swaync/style.css &

## Status bar
pkill -x waybar
#waybar -c ~/.config/waybar/config-glyphs -s ~/.config/waybar/style-glyphs.css &
waybar &

## System tray / polkit
lxpolkit &

## Keyring (SSH agent + secrets)
eval $(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
export SSH_AUTH_SOCK
systemctl --user import-environment SSH_AUTH_SOCK

## Clipboard history watcher
wl-paste --watch cliphist store &

## systemd / D-Bus environment for portals
systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP
dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP
systemctl --user start xdg-desktop-portal-wlr

# Folder with wallpapers
WALLDIR="$HOME/.dotfiles/backgrounds"

# Get connected monitors
# outputs=$(swaymsg -t get_outputs | jq -r '.[].name')
outputs=$(swaymsg -t get_outputs | grep -oP '"name":\s*"\K[^"]+')

# Loop through each monitor and set a random wallpaper
for output in $outputs; do
    # Pick a random image
    WALL=$(find "$WALLDIR" -type f | shuf -n 1)
    # Set wallpaper with fill mode
    swaybg -o "$output" -i "$WALL" -m fill &
done

