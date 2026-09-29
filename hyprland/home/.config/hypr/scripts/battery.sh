#!/bin/sh
# Battery label for hyprlock: icon (Symbols Nerd Font) and capacity of the first battery
bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1)
[ -n "$bat" ] || exit 0
cap=$(cat "$bat/capacity")

if [ "$(cat "$bat/status")" = "Charging" ]; then
    icon=""
elif [ "$cap" -ge 90 ]; then
    icon=""
elif [ "$cap" -ge 65 ]; then
    icon=""
elif [ "$cap" -ge 40 ]; then
    icon=""
elif [ "$cap" -ge 15 ]; then
    icon=""
else
    icon=""
fi

echo "$icon  $cap%"
