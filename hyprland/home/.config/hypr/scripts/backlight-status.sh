#!/bin/bash
# Brightness for the waybar module custom/backlight: one line with the percent per change
# waybar's own backlight module hides itself while the panel is off (lid closed),
# this one keeps showing the set value, so the right island keeps its look
set -u

dev=$(ls /sys/class/backlight | head -n 1)
[ -n "$dev" ] || exit 0
dir=/sys/class/backlight/$dev
max=$(<"$dir/max_brightness")

show() { echo $(( ($(<"$dir/brightness") * 100 + max / 2) / max )); }

show
# Every write to the brightness (keys, menu, slider) sends a udev change event
udevadm monitor --udev --subsystem-match=backlight | while read -r line; do
    case $line in UDEV*change*) show ;; esac
done
