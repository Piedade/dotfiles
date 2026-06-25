#!/bin/bash
if ip link show type wireguard 2>/dev/null | grep -q .; then
    systemctl stop wg-quick@red
else
    systemctl start wg-quick@red
fi
pkill -SIGRTMIN+3 waybar
