#!/bin/bash
# Bluetooth menu for waybar: a fuzzel dropdown below the right island, bluetoothctl does the work
# A right click on the waybar bluetooth icon opens it, a second one closes it
# --print: print the menu (label TAB action) without fuzzel
# BT_MENU_CTL=<command>: use it instead of bluetoothctl (tests)
set -u

dropdown_ns=dropdown-bt
# shellcheck source=dropdown.sh
. "${BASH_SOURCE[0]%/*}/dropdown.sh"
[ "${1:-}" = --print ] || dropdown_toggle

bt=${BT_MENU_CTL:-bluetoothctl}
ctl() { "$bt" "$@"; }
notify() { notify-send -a Bluetooth -i bluetooth "$@"; }

if ! ctl show 2>/dev/null | grep -q 'Powered:'; then
    notify "Kein Bluetooth-Adapter"
    exit 1
fi

# field <info text> <key>: value of "Key: value" in bluetoothctl info
field() { sed -n "s/^[[:space:]]*$2: //p" <<<"$1" | head -n1; }
# paren <value>: the number in parentheses, "0x55 (85)" -> 85
paren() { sed -n 's/.*(\(-\{0,1\}[0-9]*\)).*/\1/p' <<<"$1"; }

type_icon() {
    case $1 in
        audio-*) echo 󰋋 ;;
        input-mouse) echo 󰍽 ;;
        input-keyboard) echo 󰌌 ;;
        input-gaming) echo 󰊴 ;;
        phone) echo 󰏲 ;;
        computer) echo 󰟀 ;;
        *) echo 󰂯 ;;
    esac
}

# Menu entries: label shown in fuzzel, action kind, action argument (MAC TAB name)
labels=() kinds=() args=()
add() { labels+=("$1"); kinds+=("$2"); args+=("${3:-}"); }

# add_sorted <kind> <sort key flag> <entries…>: entries are "key TAB label TAB mac TAB name"
add_sorted() {
    local kind=$1 flag=$2 label mac name
    shift 2
    [ $# -gt 0 ] || return 0
    while IFS=$'\t' read -r _ label mac name; do
        add "$label" "$kind" "$mac"$'\t'"$name"
    done < <(printf '%s\n' "$@" | LC_ALL=C sort -t $'\t' "$flag")
}

build_menu() {
    labels=() kinds=() args=()
    if ! ctl show | grep -q 'Powered: yes'; then
        add "󰂲  Bluetooth aus" power-on
        add "󰒓  Mehr…" more
        return
    fi
    add "󰂯  Bluetooth an" power-off
    local mac info name row bat rssi
    local -a conn=() paired=() new=()
    while read -r _ mac _; do
        info=$(ctl info "$mac")
        name=$(field "$info" Alias)
        name=${name//$'\t'/ }
        row="$(type_icon "$(field "$info" Icon)")  $name"
        bat=$(paren "$(field "$info" 'Battery Percentage')")
        [ -z "$bat" ] || row+="  󰁹 $bat %"
        if [ "$(field "$info" Paired)" = yes ]; then
            if [ "$(field "$info" Connected)" = yes ]; then
                conn+=("$name"$'\t'"$row  ✓"$'\t'"$mac"$'\t'"$name")
            else
                paired+=("$name"$'\t'"$row"$'\t'"$mac"$'\t'"$name")
            fi
        elif [ -n "$(field "$info" Name)" ]; then
            # Strongest signal first: sort by the negated RSSI, unknown last
            rssi=$(paren "$(field "$info" RSSI)")
            new+=("$(( 0 - ${rssi:--999} ))"$'\t'"$row  (neu)"$'\t'"$mac"$'\t'"$name")
        fi
    done < <(ctl devices)
    add_sorted disconnect -k1,1 "${conn[@]}"
    add_sorted connect -k1,1 "${paired[@]}"
    add_sorted pair -k1,1n "${new[@]}"
    add "󰂰  Neues Gerät suchen…" scan
    [ ${#new[@]} -eq 0 ] || add "󰌌  Im Terminal koppeln…" terminal
    add "󰒓  Mehr…" more
}

# Discovery runs in the background while the dropdown is open and ends with the script
scan_pid=""
stop_scan() { [ -z "$scan_pid" ] || kill "$scan_pid" 2>/dev/null; scan_pid=""; }
start_scan() {
    [ -n "$scan_pid" ] && kill -0 "$scan_pid" 2>/dev/null && return
    "$bt" --timeout 120 scan on >/dev/null 2>&1 &
    scan_pid=$!
}
trap stop_scan EXIT

# connect <mac> <name>: 15 s at most, the result comes from bluetoothctl info
connect() {
    local id
    id=$(notify -p "Verbinde mit $2 …")
    timeout 15 "$bt" connect "$1" >/dev/null 2>&1
    if [ "$(field "$(ctl info "$1")" Connected)" = yes ]; then
        notify -r "$id" "Verbunden mit $2"
    else
        notify -r "$id" -u critical "Verbindung fehlgeschlagen: $2"
        return 1
    fi
}

# pair <mac> <name>: pair without an agent (Just Works), trust, connect
pair() {
    local id
    stop_scan
    id=$(notify -p "Kopple mit $2 …")
    timeout 30 "$bt" pair "$1" >/dev/null 2>&1
    if [ "$(field "$(ctl info "$1")" Paired)" != yes ]; then
        notify -r "$id" -u critical "Koppeln fehlgeschlagen: $2" 'Geräte mit PIN: „Im Terminal koppeln…“'
        return 1
    fi
    ctl trust "$1" >/dev/null
    notify -r "$id" "Gekoppelt mit $2"
    connect "$1" "$2"
}

# pair_in_terminal: pick a new device, put "pair <mac>" on the clipboard, open interactive bluetoothctl
# The discovery keeps running (at most 120 s), so the device stays known in the terminal
pair_in_terminal() {
    local j k
    j=$(for k in "${!kinds[@]}"; do
            [ "${kinds[$k]}" != pair ] || printf '%s\t%s\n' "${labels[$k]}" "$k"
        done | dropdown --prompt="Im Terminal koppeln: " --with-nth=1 --accept-nth=2 --only-match) || return 0
    [[ $j =~ ^[0-9]+$ ]] || return 0
    printf 'pair %s' "${args[$j]%%$'\t'*}" | wl-copy
    notify "Im Terminal: Strg+Shift+V, dann Enter" 'Der Befehl „pair …“ liegt in der Zwischenablage'
    trap - EXIT
    exec konsole -e bluetoothctl
}

show_menu() {
    local i
    for i in "${!labels[@]}"; do
        printf '%s\t%s\n' "${labels[$i]}" "$i"
    done
}

if [ "${1:-}" = --print ]; then
    build_menu
    for i in "${!labels[@]}"; do
        printf '%s\t%s\n' "${labels[$i]}" "${kinds[$i]}"
    done
    exit 0
fi

while :; do
    build_menu
    i=$(show_menu | dropdown --prompt="Bluetooth: " --with-nth=1 --accept-nth=2 --only-match) || exit 0
    [[ $i =~ ^[0-9]+$ ]] || exit 0
    [ "${kinds[$i]}" = scan ] || break
    notify -t 3000 "Suche Geräte …"
    start_scan
    sleep 10
done

arg=${args[$i]}
mac=${arg%%$'\t'*}
name=${arg#*$'\t'}
case ${kinds[$i]} in
    power-off) ctl power off >/dev/null ;;
    power-on)
        rfkill unblock bluetooth
        ctl power on >/dev/null
        ctl show | grep -q 'Powered: yes' || notify -u critical "Bluetooth gesperrt" ;;
    disconnect) ctl disconnect "$mac" >/dev/null && notify "Getrennt: $name" ;;
    connect) connect "$mac" "$name" ;;
    pair) pair "$mac" "$name" ;;
    terminal) pair_in_terminal ;;
    more) stop_scan; exec blueman-manager ;;
esac
