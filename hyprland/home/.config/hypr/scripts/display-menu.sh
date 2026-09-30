#!/bin/bash
# Display menu for waybar: a fuzzel dropdown below the right island
# A right click on the waybar brightness opens it with the brightness slider, a second one closes both
# Entries: brightness steps (brightnessctl), night light (hyprsunset)
# No refresh rate: a runtime mode switch of the laptop panel froze its picture (2026-10-01)
# --print: print the menu (label TAB action) without fuzzel
# DISPLAY_MENU_HYPRCTL, DISPLAY_MENU_BRIGHTNESSCTL=<command>: use it instead of hyprctl, brightnessctl (tests)
set -u

dropdown_ns=dropdown-display
# shellcheck source=dropdown.sh
. "${BASH_SOURCE[0]%/*}/dropdown.sh"
[ "${1:-}" = --print ] || dropdown_toggle

hyprctl_cmd=${DISPLAY_MENU_HYPRCTL:-hyprctl}
bright_cmd=${DISPLAY_MENU_BRIGHTNESSCTL:-brightnessctl}
notify() { notify-send -a Display -i video-display "$@"; }

# hyprsunset cannot tell whether its schedule or a manual value applies, so the menu keeps
# the choice (auto, on, off); no file means auto, also after a restart
night_file=${XDG_RUNTIME_DIR:-/tmp}/display-menu-night
# Same value as the evening profile in ~/.config/hypr/hyprsunset.conf
night_temp=4500

# Menu entries: label, action kind, action argument
labels=() kinds=() args=()
add() { labels+=("$1"); kinds+=("$2"); args+=("${3:-}"); }

build() {
    local cur n icon mark night=auto key
    cur=$("$bright_cmd" -m -c backlight 2>/dev/null | awk -F, 'NR == 1 { sub("%", "", $4); print $4 }')
    if [ -n "$cur" ]; then
        for n in 10 25 50 75 100; do
            case $n in 10) icon=󰃞 ;; 25|50) icon=󰃟 ;; *) icon=󰃠 ;; esac
            mark=""; [ "$n" != "$cur" ] || mark="  ✓"
            add "$icon  $n %$mark" bright "$n"
        done
    fi
    [ ! -f "$night_file" ] || read -r night < "$night_file"
    for n in auto:auto on:an off:aus; do
        key=${n%%:*}
        icon=󰖔; [ "$key" != off ] || icon=󰖨
        mark=""; [ "$key" != "$night" ] || mark="  ✓"
        add "$icon  ${n#*:}$mark" night "$key"
    done
}

show_menu() {
    local i
    for i in "${!labels[@]}"; do
        printf '%s\t%s\n' "${labels[$i]}" "$i"
    done
}

# pick: show the entries, set kind and arg of the choice; fails on Esc
pick() {
    local i
    # 14 characters: from below the brightness icon to the end of the island (measured);
    # the night light entries carry only the moon icon to fit
    i=$(show_menu | dropdown --prompt="Display: " --with-nth=1 --accept-nth=2 --only-match --width=14) || return 1
    [[ $i =~ ^[0-9]+$ ]] || return 1
    kind=${kinds[$i]} arg=${args[$i]}
}

set_night() {
    if ! [[ $("$hyprctl_cmd" hyprsunset temperature 2>/dev/null) =~ ^[0-9]+$ ]]; then
        notify "Nachtlicht läuft nicht"
        return 1
    fi
    case $1 in
        auto) "$hyprctl_cmd" hyprsunset reset ;;
        on) "$hyprctl_cmd" hyprsunset temperature "$night_temp" ;;
        off) "$hyprctl_cmd" hyprsunset identity ;;
    esac >/dev/null
    echo "$1" > "$night_file"
}

if [ "${1:-}" = --print ]; then
    build
    for i in "${!labels[@]}"; do
        printf '%s\t%s\n' "${labels[$i]}" "${kinds[$i]}"
    done
    exit 0
fi

# The brightness slider in the island is hidden by default (waybar style.css). While the menu
# is open, backlight-slider-open.css goes to backlight-slider.css; waybar reloads imported CSS on change
slider_dir=${XDG_CONFIG_HOME:-$HOME/.config}/waybar
slider() {
    [ -f "$slider_dir/backlight-slider-open.css" ] || return 0
    if [ "$1" = open ]; then
        # Only the bar under the mouse: waybar gives each bar window its output name as class
        local out=${DROPDOWN_OUTPUT:-$(dropdown_output)}
        sed "s/window#waybar /window#waybar${out:+.$out} /g" "$slider_dir/backlight-slider-open.css" > "$slider_dir/backlight-slider.css"
    else
        printf '/* Written by ~/.config/hypr/scripts/display-menu.sh: slider closed; do not edit */\n' \
            > "$slider_dir/backlight-slider.css"
    fi
}
slider open
trap 'slider closed' EXIT

build
pick || exit 0
case $kind in
    bright) "$bright_cmd" -q -c backlight set "$arg%" ;;
    night) set_night "$arg" ;;
esac
exit 0
