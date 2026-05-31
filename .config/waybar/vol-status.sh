#!/bin/bash

current=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep 'node.name' | awk -F'"' '{print $2}')
info=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
vol=$(echo "$info" | awk '{printf "%3d", $2*100}')

if [[ "$current" == *"analog"* ]]; then
    icon="󰋋"
else
    icon="󰕾"
fi

if echo "$info" | grep -q MUTED; then
    echo "{\"text\":\"<span color='#D29922'>VOL</span> <span color='#4e5b55'>${icon} muted</span>\",\"class\":\"muted\"}"
else
    echo "{\"text\":\"<span color='#D29922'>VOL</span> ${icon} ${vol}%\",\"class\":\"active\"}"
fi
