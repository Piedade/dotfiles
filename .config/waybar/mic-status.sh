#!/bin/bash

info=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)
vol=$(echo "$info" | awk '{printf "%3d", $2*100}')

if echo "$info" | grep -q MUTED; then
    echo "{\"text\":\"<span color='#D29922'>MIC</span> <span color='#4e5b55'>󰍭 ${vol}%</span>\",\"class\":\"muted\"}"
else
    echo "{\"text\":\"<span color='#D29922'>MIC</span> 󰍬 ${vol}%\",\"class\":\"active\"}"
fi
