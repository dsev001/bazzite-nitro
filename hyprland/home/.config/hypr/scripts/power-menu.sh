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

# Own scope: hyprshutdown also ends waybar, and inside waybar.service systemd kills it with the unit.
# A scope, not a service: the post-cmd runs after hyprshutdown has exited
leave() { systemd-run --user --scope --quiet hyprshutdown "$@"; }

case $choice in
    lock)     loginctl lock-session ;;
    logout)   leave ;;
    reboot)   leave --post-cmd 'systemctl reboot' ;;
    poweroff) leave --post-cmd 'systemctl poweroff' ;;
esac
