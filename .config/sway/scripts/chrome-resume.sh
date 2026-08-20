#!/bin/bash
# Called from swayidle's resume hook after systemd-suspend completes.
# Waits for sway to report active outputs (DP link training done),
# then sends SIGCONT to unfreeze Chrome.
#
# Runs as user piedade — swaymsg works directly without runuser/su.

i=0
while [ "$i" -lt 60 ]; do
    swaymsg -t get_outputs 2>/dev/null | grep -q '"active": true' && break
    sleep 1
    i=$((i + 1))
done

sleep 1
pkill -CONT -f /opt/google/chrome/chrome 2>/dev/null || true
