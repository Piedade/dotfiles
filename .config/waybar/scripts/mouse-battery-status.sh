#!/bin/bash
# Só mostra o módulo quando a bateria do rato está fraca; some quando está boa.
# Também dispara uma notificação (uma vez) quando entra em aviso.
WARNING=20
CRITICAL=5
STATE_FILE="$HOME/.cache/mouse-battery-notify.state"

device=$(upower -e 2>/dev/null | grep -m1 hidpp_battery)
level=$(upower -i "$device" 2>/dev/null | grep -oP 'percentage:\s+\K[0-9]+' | head -1)

notified=0
[ -f "$STATE_FILE" ] && notified=$(cat "$STATE_FILE")

if [ -n "$level" ]; then
    if [ "$level" -le "$WARNING" ]; then
        if [ "$notified" -eq 0 ]; then
            notify-send -u critical "🖱️ Rato com pouca bateria" "Bateria a ${level}%. Liga o carregador."
            echo 1 > "$STATE_FILE"
        fi
    else
        echo 0 > "$STATE_FILE"
    fi
fi

if [ -n "$level" ] && [ "$level" -le "$CRITICAL" ]; then
    echo "{\"text\": \"󱊡 ${level}%\", \"class\": \"critical\", \"tooltip\": \"Bateria do rato crítica: ${level}%\"}"
elif [ -n "$level" ] && [ "$level" -le "$WARNING" ]; then
    echo "{\"text\": \"󱊢 ${level}%\", \"class\": \"warning\", \"tooltip\": \"Bateria do rato baixa: ${level}%\"}"
else
    echo '{"text": ""}'
fi
