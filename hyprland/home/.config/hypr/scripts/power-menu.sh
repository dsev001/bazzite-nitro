#!/bin/sh
# Power menu for Hyprland (fuzzel in dmenu mode)
# No suspend entry while the NVIDIA resume hang is open
choice=$(printf 'Sperren\nAbmelden\nNeustart\nAusschalten\n' | fuzzel --dmenu --prompt 'Power: ') || exit 0

case "$choice" in
    Sperren)     loginctl lock-session ;;
    Abmelden)    hyprshutdown ;;
    Neustart)    hyprshutdown --post-cmd 'systemctl reboot' ;;
    Ausschalten) hyprshutdown --post-cmd 'systemctl poweroff' ;;
esac
