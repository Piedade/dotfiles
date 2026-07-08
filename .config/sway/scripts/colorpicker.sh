#!/bin/bash
color=$(grim -g "$(slurp -p)" -t ppm - | convert - -format '#%[hex:u]\n' info:-)
echo "$color" | wl-copy
notify-send "Color Picker" "$color"
