#!/bin/bash

# Autostart applications (exec_always — restarts on sway reload)

## Tiling
pkill -x autotiling; pidwait -x autotiling 2>/dev/null
autotiling &

## Notification daemon
pkill -x swaync; pidwait -x swaync 2>/dev/null
swaync -c ~/.config/swaync/config.json -s ~/.config/swaync/style.css &

## Status bar
pkill -x waybar; pidwait -x waybar 2>/dev/null
waybar &

## Wallpapers
WALLDIR="$HOME/.dotfiles/backgrounds"
outputs=$(swaymsg -t get_outputs | grep -oP '"name":\s*"\K[^"]+')
pkill -x swaybg; pidwait -x swaybg 2>/dev/null
for output in $outputs; do
    WALL=$(find "$WALLDIR" -type f | shuf -n 1)
    swaybg -o "$output" -i "$WALL" -m fill &
done
