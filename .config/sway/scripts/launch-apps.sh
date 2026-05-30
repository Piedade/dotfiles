#!/bin/bash

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
    swaymsg workspace $ws
    [[ -n "$layout" ]] && swaymsg layout $layout
    # Subscribe before launching so no window event is missed, then wait until sway registers the new window
    swaymsg -t subscribe '["window"]' 2>/dev/null | grep -m1 '"change": "new"' > /dev/null &
    local wait_pid=$!
    "$@" > /dev/null 2>&1 &
    wait $wait_pid
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
