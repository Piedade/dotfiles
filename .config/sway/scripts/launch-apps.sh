#!/bin/bash

win_count() {
    swaymsg -t get_tree | jq "
        (first(.. | objects | select(.type == \"workspace\" and .name == \"$1\")) // {})
        | [.. | objects | select(.type == \"con\" and ((.nodes // []) | length) == 0)]
        | length
    " 2>/dev/null || echo 0
}

launch() {
    local ws=$1
    shift
    local layout=""
    if [[ "$1" == "tabbed" || "$1" == "splith" || "$1" == "splitv" || "$1" == "stacking" ]]; then
        layout=$1
        shift
    fi
    if ! command -v "$1" &>/dev/null; then
        echo "launch: '$1' not found, skipping"
        return 0
    fi
    swaymsg workspace "$ws"
    [[ -n "$layout" ]] && swaymsg layout "$layout"

    local before
    before=$(win_count "$ws")
    "$@" > /dev/null 2>&1 &

    local i=0
    while [ $i -lt 50 ]; do
        [ "$(win_count "$ws")" -gt "$before" ] && return 0
        sleep 0.1
        ((i++))
    done
}

launch 1 code

launch 2 google-chrome --profile-directory=Default

launch 3 alacritty
launch 3 alacritty

#launch 4 tabbed google-chrome --profile-directory=Default --app-id=kjbdgfilnfhdoflbpgamdcdgpehopbep
#launch 4 tabbed google-chrome --profile-directory=Default --app-id=hnpfjngllnobngcgfapefoaidbinmjnm

launch 5 google-chrome --profile-directory="Profile 1"

# lets go back to work
swaymsg workspace 1
