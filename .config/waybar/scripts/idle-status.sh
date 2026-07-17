#!/bin/bash
pid=$(pgrep -x swayidle)
if [ -n "$pid" ] && [[ "$(ps -o stat= -p "$pid")" == T* ]]; then
    echo '{"text":"IDLE","class":"paused","tooltip":"Bloqueio/suspensão automático PAUSADO — clica para retomar"}'
else
    echo '{"text":"IDLE","class":"active","tooltip":"Bloqueio/suspensão automático ativo — clica para pausar"}'
fi
