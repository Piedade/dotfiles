#!/bin/bash

# Script simples para Rofi + nmcli Wi-Fi

# Obter lista de SSID disponíveis (remove duplicados)
SSIDS=$(nmcli -t -f SSID dev wifi | grep -v '^$' | sort -u)

# Escolher SSID via Rofi
SSID=$(echo "$SSIDS" | rofi -dmenu -i -p "Wi-Fi:")

# Se o utilizador cancelou
[ -z "$SSID" ] && exit

# Pedir password
PASS=$(rofi -dmenu -password -p "Password for $SSID:")

# Conectar
if [ -z "$PASS" ]; then
    nmcli device wifi connect "$SSID"
else
    nmcli device wifi connect "$SSID" password "$PASS"
fi
