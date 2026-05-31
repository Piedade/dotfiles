#!/bin/bash

info=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)
[ -z "$info" ] && echo '{"text":"MIC","class":"unknown"}' && exit 0
# vol=$(echo "$info" | awk '{printf "%-4s", sprintf("%d%%", int($2*100))}')
vol=$(echo "$info" | awk '{printf "%4s", sprintf("%d%%", int($2*100))}')

# label="<span color='#D29922'>MIC</span> "
label=""

if echo "$info" | grep -q MUTED; then
    text="<span color='#4e5b55'>󰍭  Off</span>"
    class="muted"
else
    text="󰍬 ${vol}"
    class="active"
fi

echo "{\"text\":\"${label}${text}\",\"class\":\"${class}\"}"
