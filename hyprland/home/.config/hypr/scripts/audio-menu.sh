#!/bin/bash
# Audio menu for waybar: a fuzzel dropdown below the right island, pactl does the work
# A right click on the waybar volume opens it with the volume slider, a second one closes both
# --print [main|mic|app <index>]: print a menu (label TAB action) without fuzzel
# AUDIO_MENU_PACTL=<command>: use it instead of pactl (tests)
set -u

dropdown_ns=dropdown-audio
# shellcheck source=dropdown.sh
. "${BASH_SOURCE[0]%/*}/dropdown.sh"
[ "${1:-}" = --print ] || dropdown_toggle

pactl_cmd=${AUDIO_MENU_PACTL:-pactl}
# pactl -f json fails on non-ASCII text in a German locale
pa() { LC_ALL=C "$pactl_cmd" "$@"; }
json() { pa -f json list "$1" 2>/dev/null; }
notify() { notify-send -a Audio -i audio-volume-high "$@"; }

if ! pa get-default-sink >/dev/null 2>&1; then
    notify "Kein Audio-Server"
    exit 1
fi

# German names for the short names (node.nick) of built-in devices
de_name() {
    case $1 in
        Speaker) echo Lautsprecher ;;
        Headphones) echo Kopfhörer ;;
        "Digital Microphone") echo "Internes Mikrofon" ;;
        *) echo "$1" ;;
    esac
}

sink_icon() {
    case $1 in
        bluetooth) echo 󰋋 ;;
        usb) echo 󰕓 ;;
        hdmi) echo 󰍹 ;;
        *) echo 󰓃 ;;
    esac
}

# The jq lists are TSV; empty fields become "-", because read would merge them

# Outputs, without those whose active port is "not available" (HDMI without a monitor)
# TSV: name, short name, type (bluetooth, usb, hdmi, other)
list_sinks() {
    json sinks | jq -r '.[] | . as $s
        | select([.ports[]? | select(.name == $s.active_port and .availability == "not available")] | length == 0)
        | [ .name,
            (if .properties["device.bus"] == "bluetooth" then .description
             else (.properties["node.nick"] // .description) end),
            (if .properties["device.bus"] == "bluetooth" then "bluetooth"
             elif .properties["device.bus"] == "usb" then "usb"
             elif ((.active_port // "") | test("hdmi"; "i")) then "hdmi"
             else "other" end) ]
        | map(tostring | gsub("\t"; " ") | if . == "" then "-" else . end) | @tsv'
}

# Inputs, without monitors and S/PDIF inputs. TSV: name, short name, muted (true/false)
list_sources() {
    json sources | jq -r '.[]
        | select(.properties["device.class"] != "monitor")
        | select((.active_port // "") | test("iec958") | not)
        | [ .name, (.properties["node.nick"] // .description), .mute ]
        | map(tostring | gsub("\t"; " ") | if . == "" then "-" else . end) | @tsv'
}

# The default input, also when it is hidden above. TSV: short name, muted
default_source() {
    json sources | jq -r --arg d "$(pa get-default-source)" '.[] | select(.name == $d)
        | [ (.properties["node.nick"] // .description), .mute ]
        | map(tostring | gsub("\t"; " ") | if . == "" then "-" else . end) | @tsv'
}

# Playback streams without system sounds
# TSV: index, paused (0/1), name, volume in %, muted (true/false)
list_streams() {
    json sink-inputs | jq -r '.[] | select(.properties["media.role"] != "event")
        | [ .index, (if .corked then 1 else 0 end),
            (.properties["application.name"] // .properties["application.process.binary"]
             // .properties["media.name"] // "Unbekannt"),
            (.volume | to_entries[0].value.value_percent | rtrimstr("%")),
            .mute ]
        | map(tostring | gsub("\t"; " ") | if . == "" then "-" else . end) | @tsv'
}

# Menu entries: label, action kind, action argument, display name
labels=() kinds=() args=() names=()
add() { labels+=("$1"); kinds+=("$2"); args+=("${3:-}"); names+=("${4:-}"); }
clear_menu() { labels=() kinds=() args=() names=(); }

build_main() {
    clear_menu
    local def name nick type label mute="" idx app vol
    local -a rest=()
    def=$(pa get-default-sink)
    # Current output first, the others by name
    while IFS=$'\t' read -r name nick type; do
        nick=$(de_name "$nick")
        label="$(sink_icon "$type")  $nick"
        if [ "$name" = "$def" ]; then
            add "$label  ✓" sink "$name" "$nick"
        else
            rest+=("$nick"$'\t'"$label"$'\t'"$name")
        fi
    done < <(list_sinks)
    if [ ${#rest[@]} -gt 0 ]; then
        while IFS=$'\t' read -r nick label name; do
            add "$label" sink "$name" "$nick"
        done < <(printf '%s\n' "${rest[@]}" | LC_ALL=C sort -t $'\t' -k1,1)
    fi
    nick=""
    IFS=$'\t' read -r nick mute < <(default_source)
    if [ "$mute" = true ]; then
        add "󰍭  Mikrofon: stumm  ›" mic
    else
        add "󰍬  Mikrofon: $(de_name "${nick:-keins}")  ›" mic
    fi
    # Playing streams first, then paused ones, each by name
    while IFS=$'\t' read -r idx _ app vol mute; do
        if [ "$mute" = true ]; then label="󰎆  $app  stumm  ›"; else label="󰎆  $app  $vol %  ›"; fi
        add "$label" app "$idx" "$app"
    done < <(list_streams | LC_ALL=C sort -t $'\t' -k2,2n -k3,3)
    add "󰕾  pavucontrol…" more
}

build_mic() {
    clear_menu
    local def name nick mute cur_mute=""
    def=$(pa get-default-source)
    add "󰁍  Zurück" back
    while IFS=$'\t' read -r name nick mute; do
        nick=$(de_name "$nick")
        if [ "$name" = "$def" ]; then
            add "󰍬  $nick  ✓" source "$name" "$nick"
        else
            add "󰍬  $nick" source "$name" "$nick"
        fi
    done < <(list_sources)
    IFS=$'\t' read -r _ cur_mute < <(default_source)
    if [ "$cur_mute" = true ]; then add "󰍬  Stumm aus" mic-mute; else add "󰍭  Stumm schalten" mic-mute; fi
}

# build_app <index>: submenu of one stream; fails when the stream is gone
build_app() {
    clear_menu
    local idx app vol mute
    IFS=$'\t' read -r idx _ app vol mute < <(list_streams | awk -F'\t' -v i="$1" '$1 == i') || return 1
    app_name=$app app_vol=$vol
    app_title="$app  $vol %"
    [ "$mute" != true ] || app_title="$app  stumm"
    add "󰁍  Zurück" back
    if [ "$mute" = true ]; then add "󰕾  Ton an" mute; else add "󰝟  Stumm" mute; fi
    add "󰝝  +10 %" up
    add "󰝞  −10 %" down
    add "󰕿  25 %" set 25
    add "󰖀  50 %" set 50
    add "󰕾  75 %" set 75
    add "󰕾  100 %" set 100
}

show_menu() {
    local i
    for i in "${!labels[@]}"; do
        printf '%s\t%s\n' "${labels[$i]}" "$i"
    done
}

# pick <prompt>: show the entries, set kind, arg and name of the choice; fails on Esc
pick() {
    local i
    # 20 characters: from below the volume icon to the end of the island
    i=$(show_menu | dropdown --prompt="$1" --with-nth=1 --accept-nth=2 --only-match --width=20) || return 1
    [[ $i =~ ^[0-9]+$ ]] || return 1
    kind=${kinds[$i]} arg=${args[$i]} name=${names[$i]}
}

if [ "${1:-}" = --print ]; then
    case ${2:-main} in
        main) build_main ;;
        mic) build_mic ;;
        app) build_app "${3:-}" || exit 1 ;;
    esac
    for i in "${!labels[@]}"; do
        printf '%s\t%s\n' "${labels[$i]}" "${kinds[$i]}"
    done
    exit 0
fi

# The volume slider in the island is hidden by default (waybar style.css). While the menu
# is open, audio-slider-open.css goes to audio-slider.css; waybar reloads imported CSS on change
slider_dir=${XDG_CONFIG_HOME:-$HOME/.config}/waybar
slider() {
    [ -f "$slider_dir/audio-slider-open.css" ] || return 0
    if [ "$1" = open ]; then
        # Only the bar under the mouse: waybar gives each bar window its output name as class
        local out=${DROPDOWN_OUTPUT:-$(dropdown_output)}
        sed "s/window#waybar /window#waybar${out:+.$out} /g" "$slider_dir/audio-slider-open.css" > "$slider_dir/audio-slider.css"
    else
        printf '/* Written by ~/.config/hypr/scripts/audio-menu.sh: slider closed; do not edit */\n' \
            > "$slider_dir/audio-slider.css"
    fi
}
slider open
trap 'slider closed' EXIT

menu=main stream="" app_name="" app_vol=0 app_title=""
while :; do
    case $menu in
        main)
            build_main
            pick "Audio: " || exit 0
            case $kind in
                sink)
                    pa set-default-sink "$arg" 2>/dev/null || notify -u critical "Gerät nicht mehr da: $name"
                    exit 0 ;;
                mic) menu=mic ;;
                app) menu=app stream=$arg ;;
                more) slider closed; trap - EXIT; exec pavucontrol ;;
            esac ;;
        mic)
            build_mic
            pick "Mikrofon: " || exit 0
            case $kind in
                back) menu=main ;;
                source)
                    pa set-default-source "$arg" 2>/dev/null || notify -u critical "Gerät nicht mehr da: $name"
                    exit 0 ;;
                mic-mute) pa set-source-mute @DEFAULT_SOURCE@ toggle ;;
            esac ;;
        app)
            if ! build_app "$stream"; then
                notify "Wiedergabe beendet: $app_name"
                menu=main
                continue
            fi
            pick "$app_title: " || exit 0
            case $kind in
                back) menu=main ;;
                mute) pa set-sink-input-mute "$stream" toggle ;;
                up) [ "$app_vol" -ge 100 ] || pa set-sink-input-volume "$stream" "$(( app_vol + 10 > 100 ? 100 : app_vol + 10 ))%" ;;
                down) pa set-sink-input-volume "$stream" "$(( app_vol > 10 ? app_vol - 10 : 0 ))%" ;;
                set) pa set-sink-input-volume "$stream" "$arg%" ;;
            esac ;;
    esac
done
