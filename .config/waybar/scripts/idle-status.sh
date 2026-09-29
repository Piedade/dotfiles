#!/bin/bash
state_file="${XDG_RUNTIME_DIR:-/tmp}/swayidle-paused"

if [ -f "$state_file" ]; then
    echo '{"text":"IDLE","class":"paused","tooltip":"Bloqueio automático PAUSADO"}'
elif pgrep -x swayidle >/dev/null; then
    echo '{"text":"IDLE","class":"active","tooltip":"Bloqueio automático ativo"}'
else
    echo '{"text":"IDLE","class":"error","tooltip":"swayidle não está a correr"}'
fi
