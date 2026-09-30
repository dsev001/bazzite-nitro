#!/bin/bash
# Battery menu for waybar: a fuzzel dropdown below the right island
# A right click on the waybar battery opens it: charge with remaining time, then the power profiles
# Power profiles come from tuned-ppd over the PPD D-Bus API; tuned-adm would leave them "unknown"
# --print: print the menu (label TAB action) without fuzzel
# BATTERY_MENU_BUSCTL=<command>: use it instead of busctl (tests)
set -u

dropdown_ns=dropdown-battery
# shellcheck source=dropdown.sh
. "${BASH_SOURCE[0]%/*}/dropdown.sh"
[ "${1:-}" = --print ] || dropdown_toggle

busctl_cmd=${BATTERY_MENU_BUSCTL:-busctl}
notify() { notify-send -a Akku -i battery "$@"; }

upower=(org.freedesktop.UPower /org/freedesktop/UPower/devices/DisplayDevice org.freedesktop.UPower.Device)
ppd=(org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles)
# get <service> <path> <interface> <property>: the value as JSON, empty when it fails
get() { "$busctl_cmd" -j --system get-property "$@" 2>/dev/null | jq -c '.data'; }

# Same glyphs as the waybar battery (config.jsonc): empty to full, charging
icons=($'' $'' $'' $'' $'')
icon_charging=$''

# hm <seconds>: hours:minutes
hm() { printf '%d:%02d h' $(( $1 / 3600 )) $(( $1 % 3600 / 60 )); }

de_profile() {
    case $1 in
        power-saver) echo Energiesparen ;;
        balanced) echo Ausgewogen ;;
        performance) echo Leistung ;;
        *) echo "$1" ;;
    esac
}

# Menu entries: label, action kind, action argument
labels=() kinds=() args=()
add() { labels+=("$1"); kinds+=("$2"); args+=("${3:-}"); }

ppd_ok=""
build() {
    local pct state tte ttf i icon text active p
    local -a have=()
    if [ "$(get "${upower[@]}" IsPresent)" = true ]; then
        pct=$(get "${upower[@]}" Percentage | jq 'round')
        state=$(get "${upower[@]}" State)
        tte=$(get "${upower[@]}" TimeToEmpty)
        ttf=$(get "${upower[@]}" TimeToFull)
        i=$(( pct / 20 > 4 ? 4 : pct / 20 ))
        icon=${icons[$i]} text="$pct %"
        case $state in
            1) icon=$icon_charging
               if [ "${ttf:-0}" -gt 0 ]; then text+=" · voll in $(hm "$ttf")"; else text+=" · lädt"; fi ;;
            4) text+=" · voll" ;;
            5) text+=" · am Netz" ;;
            *) [ "${tte:-0}" -le 0 ] || text+=" · noch $(hm "$tte")" ;;
        esac
        add "$icon  $text" status
    fi
    active=$(get "${ppd[@]}" ActiveProfile | jq -r '.')
    mapfile -t have < <(get "${ppd[@]}" Profiles | jq -r '.[].Profile.data')
    [ ${#have[@]} -gt 0 ] || return 0
    ppd_ok=1
    for p in power-saver:󰌪 balanced:󰾅 performance:󰓅; do
        [[ " ${have[*]} " == *" ${p%%:*} "* ]] || continue
        text="${p#*:}  $(de_profile "${p%%:*}")"
        [ "${p%%:*}" != "$active" ] || text+="  ✓"
        add "$text" profile "${p%%:*}"
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
    # 26 characters: from below the battery icon to the end of the island (measured)
    i=$(show_menu | dropdown --prompt="Akku: " --with-nth=1 --accept-nth=2 --only-match --width=26) || return 1
    [[ $i =~ ^[0-9]+$ ]] || return 1
    kind=${kinds[$i]} arg=${args[$i]}
}

# set_profile <name>: switch, then check it applies (an app can hold another profile)
set_profile() {
    local err now
    if ! err=$("$busctl_cmd" --system set-property "${ppd[@]}" ActiveProfile s "$1" 2>&1); then
        notify -u critical "Profil nicht gesetzt: $err"
        return 1
    fi
    now=$(get "${ppd[@]}" ActiveProfile | jq -r '.')
    [ "$now" = "$1" ] || notify "Profil gilt nicht: aktiv ist $(de_profile "$now")"
}

build
if [ "${1:-}" = --print ]; then
    for i in "${!labels[@]}"; do
        printf '%s\t%s\n' "${labels[$i]}" "${kinds[$i]}"
    done
    exit 0
fi

[ -n "$ppd_ok" ] || notify "Energieprofile nicht verfügbar"
[ ${#labels[@]} -gt 0 ] || exit 0
pick || exit 0
case $kind in
    profile) set_profile "$arg" ;;
esac
exit 0
