#!/bin/bash

## CHECK mouse.sh
# Mouse Battery Low Notification
# Checks Logitech mouse battery via Solaar and sends a notification if below threshold.
#
# SETUP (run once after installing solaar):
#   1. Run `solaar show` to see your device name and battery output format.
#      Example output:
#        MX Anywhere 3  [/dev/hidraw0]
#          Battery: 45%, charging
#
#   2. Adjust DEVICE_NAME below to match your device name from `solaar show`.
#      Use a partial name (e.g. "MX" or "Anywhere") to be less strict.
#
#   3. Adjust THRESHOLD to the battery % at which you want to be notified.
#
#   4. Enable the systemd timer:
#        systemctl --user enable --now mouse-battery-notify.timer

DEVICE_NAME="MX"       # partial match — adjust to your mouse name
THRESHOLD=20           # notify when battery <= this percentage

# Get battery percentage from solaar
BATTERY=$(solaar show 2>/dev/null \
    | grep -A5 -i "$DEVICE_NAME" \
    | grep -i "battery" \
    | grep -oP '\d+(?=%)' \
    | head -1)

if [ -z "$BATTERY" ]; then
    # Device not found or solaar not running — silently exit
    exit 0
fi

if [ "$BATTERY" -le "$THRESHOLD" ]; then
    notify-send \
        --urgency=critical \
        --icon=battery-caution \
        "Mouse Battery Low" \
        "Battery at ${BATTERY}% — please charge your mouse."
fi
