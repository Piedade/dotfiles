#!/bin/bash
iface=$(ip link show type wireguard 2>/dev/null | awk -F': ' '/^[0-9]/ {print $2}')
if [ -n "$iface" ]; then
    echo "{\"text\": \"VPN\", \"class\": \"connected\", \"tooltip\": \"VPN ligada: $iface\"}"
else
    echo '{"text": "VPN", "class": "disconnected", "tooltip": "VPN desligada"}'
fi
