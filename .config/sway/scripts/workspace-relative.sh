#!/bin/bash
# usage: workspace-relative.sh <goto|move> <slot> [other]
# switches to (or moves the focused container to) the Nth workspace assigned
# to the focused output (or the other output, if "other" is passed), so
# $mod+1 always means "workspace 1 of this monitor", dwm-tag style, instead
# of a globally fixed workspace number.

action=$1
slot=$2
which_output=$3

if [ "$which_output" = "other" ]; then
    target_output=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused | not) | .name' | head -n1)
else
    target_output=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused) | .name')
fi

target=$(grep -oP "^workspace \K\d+(?= output ${target_output}$)" "$HOME/.config/sway/workspaces" \
    | sort -n | sed -n "${slot}p")

[ -z "$target" ] && exit 0

case "$action" in
    goto) swaymsg workspace number "$target" ;;
    move) swaymsg move container to workspace number "$target" ;;
esac
