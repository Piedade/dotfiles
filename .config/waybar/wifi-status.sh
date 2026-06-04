#!/bin/bash
STATE=$(nmcli radio wifi)
SSID=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2)

if [ "$STATE" = "disabled" ]; then
    echo '{"text": "󰤭", "tooltip": "WiFi desligado", "class": "disabled"}'
elif [ -z "$SSID" ]; then
    echo '{"text": "󰤨", "tooltip": "Sem ligação", "class": "disconnected"}'
else
    echo "{\"text\": \"󰤨\", \"tooltip\": \"$SSID\", \"class\": \"connected\"}"
fi
