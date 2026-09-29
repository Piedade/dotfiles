#!/bin/bash

# Lançador do swayidle (bloqueio de ecrã, dpms off e suspensão automática).
# Isolado num script próprio para que idle-toggle o possa relançar do zero
# (reiniciando a contagem de inatividade) sem duplicar esta configuração em
# dois sítios.

# 5 min → bloqueia | 10 min → dpms off | 15 min → suspende
exec swayidle -w \
    timeout 300   'pgrep swaylock || swaylock -f' \
    timeout 600   'swaymsg "output * dpms off"' \
    resume       'swaymsg "output * dpms on"' \
    timeout 900   'systemctl suspend' \
    before-sleep 'pgrep swaylock || swaylock -f'
