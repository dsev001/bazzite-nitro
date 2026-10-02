#!/bin/bash
# Power menu for Hyprland: fuzzel dropdown below the right waybar island
# --center: open in the middle of the screen (keyboard shortcut); --print: print the menu without fuzzel
# No suspend entry while the NVIDIA/DisplayLink resume issues are open
set -u

dropdown_ns=dropdown-power
# shellcheck source=dropdown.sh
. "${BASH_SOURCE[0]%/*}/dropdown.sh"

menu() {
    printf '%s\t%s\n' \
        '󰌾  Sperren' lock \
        '󰍃  Abmelden' logout \
        '󰜉  Neustart' reboot \
        '󰐥  Ausschalten' poweroff
}

case ${1:-} in
    --print) menu; exit 0 ;;
    --center) dropdown_center=1 ;;
esac
dropdown_toggle

choice=$(menu | dropdown --prompt='Power: ' --with-nth=1 --accept-nth=2 --only-match) || exit 0

case $choice in
    lock)     loginctl lock-session ;;
    logout)   hyprshutdown ;;
    reboot)   hyprshutdown --post-cmd 'systemctl reboot' ;;
    poweroff) hyprshutdown --post-cmd 'systemctl poweroff' ;;
esac
