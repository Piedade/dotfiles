#!/bin/bash

current=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep 'node.name' | awk -F'"' '{print $2}')
info=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
# vol=$(echo "$info" | awk '{printf "%-4s", sprintf("%d%%", int($2*100))}')
vol=$(echo "$info" | awk '{printf "%4s", sprintf("%d%%", int($2*100))}')

if [[ "$current" == *"analog"* ]]; then
    icon="󰋋"
else
    icon="󰕾"
    # if [ "$vol" -gt 40 ]; then
    #     icon="󰕾 "
    # elif [ "$vol" -gt 15 ]; then
    #     icon="󰖀 "
    # else
    #     icon="󰕿 "
    # fi
fi

# label="<span color='#D29922'>VOL</span> "
label=""

if echo "$info" | grep -q MUTED; then
    text="<span color='#4e5b55'>󰝟 Off </span>"
    class="muted"
else
    text="${icon} ${vol}"
    class="active"
fi

echo "{\"text\":\"${label}${text}\",\"class\":\"${class}\"}"
