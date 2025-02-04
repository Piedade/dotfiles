#!/usr/bin/env bash

## Author : Aditya Shakya (adi1090x)
## Github : @adi1090x

# CMDs
theme="full_black"
dir="$HOME/.config/rofi/powermenu"
uptime="`uptime -p | sed -e 's/up //g'`"

# Options
shutdown='󰐥'
reboot='󰜉'
lock=''
suspend=''
logout='󰍃'

# Rofi CMD
rofi_cmd() {
    rofi -dmenu \
        -p "" \
        -mesg "Uptime: $uptime" \
        -theme "$dir/$theme" \
        -selected-row 1
}

# Pass variables to rofi dmenu
run_rofi() {
    # echo -e "$lock\n$suspend\n$logout\n$reboot\n$shutdown" | rofi_cmd
    echo -e "$reboot\n$shutdown\n$logout" | rofi_cmd
}

# Execute Command
run_cmd() {
    # Kill all Chrome processes and wait for them to exit
    killall --wait chrome code

    case $1 in
        --shutdown)
            systemctl poweroff
            ;;
        --reboot)
            systemctl reboot
            ;;
        --lock)
            if [[ -f /usr/bin/i3lock ]]; then
                i3lock
            elif [[ -f /usr/bin/betterlockscreen ]]; then
                betterlockscreen -l
            fi
            ;;
        --suspend)
            mpc -q pause
            amixer set Master mute
            systemctl suspend
            ;;
        --logout)
            case "$DESKTOP_SESSION" in
                openbox)
                    openbox --exit
                    ;;
                bspwm)
                    bspc quit
                    ;;
                dwm)
                    pkill dwm
                    ;;
                i3)
                    i3-msg exit
                    ;;
                plasma)
                    qdbus org.kde.ksmserver /KSMServer logout 0 0 0
                    ;;
            esac
            ;;
    esac
}

# Actions
chosen="$(run_rofi)"
case "${chosen}" in
    "${shutdown}")
        run_cmd --shutdown
        ;;
    "${reboot}")
        run_cmd --reboot
        ;;
    "${lock}")
        run_cmd --lock
        ;;
    "${suspend}")
        run_cmd --suspend
        ;;
    "${logout}")
        run_cmd --logout
        ;;
esac
