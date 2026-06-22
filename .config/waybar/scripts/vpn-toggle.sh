#!/bin/bash
if ip link show type wireguard 2>/dev/null | grep -q .; then
    wg-quick down red
else
    wg-quick up red
fi
pkill -SIGRTMIN+3 waybar
