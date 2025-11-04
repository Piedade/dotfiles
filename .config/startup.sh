#!/bin/bash

runApp() {
    tag=$1
    monitor=$2
    shift 2 # Remove first two arguments, leaving only the command
    runApp=("$@")

    if [[ -z "$tag" || ! "$tag" =~ ^[0-9]+$ || "$tag" -le 0 ]]; then
        echo "Error: argument tag is missing or it should be a positive number!"
        return 1
    fi

    if [[ -z "$monitor" || ! "$monitor" =~ ^[0-9]+$ || "$monitor" -le 0 ]]; then
        echo "Error: monitor argument is missing or it should be a positive number!"
        return 1
    fi

    # Change monitor
    xdotool key Super+Control_L+Shift_L+$monitor

    # Go to dwm tag
    xdotool key Super+$tag

    # Run the command with all its arguments in the background
    "${runApp[@]}" > /dev/null &  # Run command properly as an array
    sleep 1
}

PRIMARY_MONITOR=1
SECOND_MONITOR=2

# VSCODE
app=("code")
runApp 1 $PRIMARY_MONITOR "${app[@]}"

# CHROME
app=("google-chrome" "--profile-directory=Default")
runApp 2 $PRIMARY_MONITOR "${app[@]}"

# TERMINAL
app=("alacritty" "--working-directory" "$HOME")
runApp 3 $PRIMARY_MONITOR "${app[@]}"

app=("alacritty" "--working-directory" "$HOME")
runApp 3 $PRIMARY_MONITOR "${app[@]}"

# Google Calendar PWA
app=("google-chrome" "--profile-directory=Default" "--app-id=kjbdgfilnfhdoflbpgamdcdgpehopbep")
runApp 4 $PRIMARY_MONITOR "${app[@]}"

# WhatsApp Web PWA
app=("google-chrome" "--profile-directory=Default" "--app-id=hnpfjngllnobngcgfapefoaidbinmjnm")
runApp 4 $PRIMARY_MONITOR "${app[@]}"

# CHROME
app=("google-chrome" "--profile-directory=Profile 1")
# runApp 1 $SECOND_MONITOR "${app[@]}"
runApp 5 $PRIMARY_MONITOR "${app[@]}"

# # Go to principal monitor
# xdotool key Super+Control_L+Shift_L+$PRIMARY_MONITOR
