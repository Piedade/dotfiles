#!/bin/bash
goToNextMonitor() {
    xdotool key Super+period
}

goToPreviousMonitor() {
    xdotool key Super+comma
}

runApp() {
    tag=$1
    monitor=$2
    shift 2 # Remove first two arguments, leaving only the command
    runApp=("$@")

    if [ -z "$tag" ]; then
        echo "Error: argument tag is missing!"
        return 1
    fi

    if [ -z "$monitor" ]; then
        echo "Error: argument monitor is missing!"
        return 1
    fi

    if [[ ! "$monitor" =~ ^(0|1|-1)$ ]]; then
        echo "Error: monitor argument must be 0, 1, or -1!"
        return 1
    fi

    # Check if we need to change monitor
    if [ "$monitor" -eq 1 ]; then
        goToNextMonitor
    elif [ "$monitor" -eq -1 ]; then
        goToPreviousMonitor
    fi

    # go to dwm tag
    xdotool key Super+$tag

    # Run the command with all its arguments in the background
    "${runApp[@]}" &  # Run command properly as an array
    sleep 1
}

# VSCODE
# https://code.visualstudio.com/docs/editor/settings-sync#_troubleshooting-keychain-issues
app=("code" "--password-store=gnome-libsecret")
runApp 1 0 "${app[@]}"

# CHROME
app=("google-chrome" "--profile-directory=Default")
runApp 2 0 "${app[@]}"

# CHROME
app=("google-chrome" "--profile-directory=Profile 1")
runApp 1 1 "${app[@]}"
goToPreviousMonitor
