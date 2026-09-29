#!/bin/sh
# Set a wallpaper and regenerate the Material You colors (matugen, dark scheme)
# Usage: wallpaper.sh <image>
set -eu

if [ $# -ne 1 ] || [ ! -f "$1" ]; then
    echo "Usage: wallpaper.sh <image>" >&2
    exit 1
fi
img=$(realpath "$1")

# hyprpaper and hyprlock read $wallpaper from user.conf
sed -i "s|^\$wallpaper = .*|\$wallpaper = $img|" ~/.config/hypr/user.conf

matugen image "$img" -m dark

# Outside Hyprland only the files change; the session picks them up at login
[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || exit 0

# fuzzel and hyprlock read their colors on every start
# hyprpaper 0.8.4 ignores an empty monitor over IPC, so name each one
for mon in $(hyprctl monitors -j | jq -r '.[].name'); do
    hyprctl hyprpaper wallpaper "$mon, $img, cover" >/dev/null
done
pkill -USR2 -x waybar || true
makoctl reload || true
hyprctl reload >/dev/null
