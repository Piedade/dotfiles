#!/bin/bash

current_id=$(wpctl status 2>/dev/null | awk '
    /Sinks:/{in_sinks=1; next}
    in_sinks && /Sources:/{in_sinks=0}
    in_sinks && /\*/{match($0, /[0-9]+/); print substr($0, RSTART, RLENGTH); exit}
')

all_ids=$(wpctl status 2>/dev/null | awk '
    /Sinks:/{in_sinks=1; next}
    in_sinks && /Sources:/{in_sinks=0}
    in_sinks && /[0-9]+\./{match($0, /[0-9]+/); print substr($0, RSTART, RLENGTH)}
')

for id in $all_ids; do
    if [ "$id" != "$current_id" ]; then
        wpctl set-default "$id"
        break
    fi
done
