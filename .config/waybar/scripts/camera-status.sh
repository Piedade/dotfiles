#!/bin/bash
devices=(/dev/video*)
[ -e "${devices[0]}" ] || { echo '{"text":"","class":"idle"}'; exit 0; }

pids=$(fuser "${devices[@]}" 2>/dev/null | tr -s ' \t' '\n' | grep -oE '^[0-9]+')
if [ -z "$pids" ]; then
    echo '{"text":"","class":"idle"}'
    exit 0
fi

app=""
tree=$(swaymsg -t get_tree 2>/dev/null)
for pid in $pids; do
    p=$pid
    while [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null; do
        app=$(jq -r --argjson pid "$p" '.. | objects | select(.pid? == $pid) | .app_id // .name // empty' <<<"$tree" 2>/dev/null | head -n1)
        [ -n "$app" ] && break
        p=$(awk '/^PPid:/{print $2}' "/proc/$p/status" 2>/dev/null)
    done
    [ -n "$app" ] && break
done

tooltip="Câmara em uso"
[ -n "$app" ] && tooltip="Câmara em uso por: $app"

echo "{\"text\":\"REC\",\"class\":\"recording\",\"tooltip\":\"$tooltip\"}"
