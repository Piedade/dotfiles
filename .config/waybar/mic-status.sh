#!/bin/bash

info=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)
vol=$(echo "$info" | awk '{printf "%d", $2*100}')

if echo "$info" | grep -q MUTED; then
    echo "{\"text\":\"<span color='#D29922'>MIC</span> <span color='#4e5b55'>󰍭 0%</span>\",\"class\":\"muted\"}"
else
    echo "{\"text\":\"<span color='#D29922'>MIC</span> ${vol}%\",\"class\":\"active\"}"
fi
