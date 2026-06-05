#!/bin/bash

layouts=(
    "󰙀 Horizontal Split      Shift+Control+1"
    "󰕴 Vertical Split        Shift+Control+2"
    "󰝘 Tabbed               Shift+Control+3"
    "󰕬 Stacked              Shift+Control+4"
    "󰕮 Toggle Split          Shift+Control+5"
)

selected=$(printf "%s\n" "${layouts[@]}" | fuzzel --dmenu --prompt "Layout: ")

# Extract just the first two fields (layout name)
layout_name=$(echo "$selected" | awk '{print $1, $2}')

case "$layout_name" in
    "󰙀 Horizontal") swaymsg "layout splith;" ;;
    "󰕴 Vertical") swaymsg "layout splitv;" ;;
    "󰝘 Tabbed") swaymsg "layout tabbed;" ;;
    "󰕬 Stacked") swaymsg "layout stacking;" ;;
    "󰕮 Toggle") swaymsg "layout toggle split;" ;;
    *) exit 0 ;;  # Exit on cancel
esac
