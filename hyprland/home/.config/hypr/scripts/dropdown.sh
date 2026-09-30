# Shared fuzzel dropdown for the menus of the right waybar island (wifi, power, bt, audio, display, battery)
# Sourced, not run: set dropdown_ns (dropdown-<name>) first; dropdown_center=1 opens it centered instead
# DROPDOWN_OUTPUT=<monitor> opens it on that monitor instead of the one under the mouse (tests)
# hyprland.lua (click outside closes) and user.lua (blur) match the namespace prefix dropdown-

# Below the right waybar island: fuzzel starts below the bar's exclusive zone,
# so y is only the gap; x is the bar margin-right
dropdown_y=8
dropdown_x=20

# Close any open dropdown; a click on the icon of the open one only closes it
dropdown_toggle() {
    local own
    # shellcheck disable=SC2154  # dropdown_ns is set by the caller
    own=$(pgrep -f -- "^fuzzel .*--namespace=$dropdown_ns( |$)")
    pkill -f -- '^fuzzel .*--namespace=dropdown-[a-z]+( |$)'
    [ -z "$own" ] || exit 0
}

# Monitor under the mouse pointer, so the dropdown opens where the click was
dropdown_output() {
    local pos
    pos=$(hyprctl -j cursorpos) || return 0
    # shellcheck disable=SC2016  # $p is a jq variable
    hyprctl -j monitors | jq -r --argjson p "$pos" '
        .[] | select($p.x >= .x and $p.x < .x + .width / .scale
                 and $p.y >= .y and $p.y < .y + .height / .scale) | .name' | head -n1
}

# dropdown [fuzzel flags]: menu lines on stdin
# on-demand focus: clicks outside reach waybar and windows
dropdown() {
    local -a place=()
    if [ -z "${dropdown_center:-}" ]; then
        local out
        out=${DROPDOWN_OUTPUT:-$(dropdown_output)}
        place=(--anchor=top-right --x-margin="$dropdown_x" --y-margin="$dropdown_y" ${out:+--output="$out"})
    fi
    fuzzel --dmenu --namespace="$dropdown_ns" --keyboard-focus=on-demand "${place[@]}" \
        --width=32 --lines=12 --minimal-lines --no-sort "$@"
}
