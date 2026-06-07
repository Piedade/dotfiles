#!/bin/bash

# Autostart applications (exec_always — restarts on sway reload)

## systemd / D-Bus environment for portals
export XDG_CURRENT_DESKTOP=sway
systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP
dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP
systemctl --user start xdg-desktop-portal-wlr

## Wait for outputs to be ready
until swaymsg -t get_outputs 2>/dev/null | grep -q '"active": true'; do sleep 0.5; done

## Wallpapers
WALLDIR="$HOME/.dotfiles/backgrounds"
outputs=$(swaymsg -t get_outputs | grep -oP '"name":\s*"\K[^"]+')
pkill -x swaybg; pidwait -x swaybg 2>/dev/null
for output in $outputs; do
    WALL=$(find "$WALLDIR" -type f | shuf -n 1)
    swaybg -o "$output" -i "$WALL" -m fill &
done

## Status bar
pkill -x waybar; pidwait -x waybar 2>/dev/null
waybar &

## Notification daemon
pkill -x swaync; pidwait -x swaync 2>/dev/null
swaync -c ~/.config/swaync/config.json -s ~/.config/swaync/style.css &

## Tiling
pkill -x autotiling; pidwait -x autotiling 2>/dev/null
autotiling &

## System tray / polkit
pkill -x lxpolkit; pidwait -x lxpolkit 2>/dev/null
lxpolkit &

## Keyring (SSH agent + secrets)
systemctl --user disable --now ssh-agent.socket 2>/dev/null
eval $(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
export SSH_AUTH_SOCK
systemctl --user import-environment SSH_AUTH_SOCK
ssh-add -l 2>/dev/null | grep -q "id_ed25519" || ssh-add ~/.ssh/id_ed25519

## Clipboard history watcher
pkill -x "wl-paste"; pidwait -x "wl-paste" 2>/dev/null
wl-paste --watch cliphist store &
