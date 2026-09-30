#!/bin/bash
# Wi-Fi menu for waybar: a fuzzel dropdown below the right island, nmcli does the work
# A click on the waybar network icon opens it, a second click closes it
# --print: print the menu (label TAB action) without fuzzel
# WIFI_MENU_SCAN=<file>: use this file instead of the nmcli scan (tests)
set -u

dropdown_ns=dropdown-wifi
# shellcheck source=dropdown.sh
. "${BASH_SOURCE[0]%/*}/dropdown.sh"
[ "${1:-}" = --print ] || dropdown_toggle

# Stable nmcli output for parsing; the texts shown to the user come from this script
export LC_MESSAGES=C

notify() { notify-send -a WLAN -i network-wireless "$@"; }

dev=$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2 == "wifi" { print $1; exit }')
if [ -z "$dev" ]; then
    notify "Kein WLAN-Gerät"
    exit 1
fi

scan() {
    if [ -n "${WIFI_MENU_SCAN:-}" ]; then
        cat "$WIFI_MENU_SCAN"
    else
        nmcli -t -e no -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list ifname "$dev" --rescan "$1"
    fi
}

signal_icon() {
    if   [ "$1" -ge 81 ]; then echo 󰤨
    elif [ "$1" -ge 61 ]; then echo 󰤥
    elif [ "$1" -ge 41 ]; then echo 󰤢
    elif [ "$1" -ge 21 ]; then echo 󰤟
    else echo 󰤯
    fi
}

# Saved Wi-Fi profiles: SSID -> UUID
declare -A saved=()
while IFS=: read -r uuid type; do
    [ "$type" = 802-11-wireless ] || continue
    s=$(nmcli -e no -g 802-11-wireless.ssid con show uuid "$uuid")
    [ -n "$s" ] && saved["$s"]=$uuid
done < <(nmcli -t -f UUID,TYPE con show)

# Menu entries: label shown in fuzzel, action kind, action argument
labels=() kinds=() args=()
add() { labels+=("$1"); kinds+=("$2"); args+=("${3:-}"); }

# build_menu <rescan yes|no>
build_menu() {
    labels=() kinds=() args=()
    if [ "$(nmcli radio wifi)" != enabled ]; then
        add "󰤨  WLAN an" radio-on
        add "󰒓  Mehr…" more
        return
    fi
    local connected="" inuse signal security ssid name lock
    local -A seen=()
    # Connected network first, then by signal; the first line per SSID is the strongest
    while IFS=: read -r inuse signal security ssid; do
        [ -n "$ssid" ] || continue
        [ -z "${seen["$ssid"]:-}" ] || continue
        seen["$ssid"]=1
        name=${ssid//$'\t'/ }
        lock=""
        case $security in ""|--) ;; *) lock=" 󰌾" ;; esac
        if [ "$inuse" = "*" ]; then
            connected=1
            add "$(signal_icon "$signal")  $name$lock  ✓" none
        elif [ -n "${saved["$ssid"]:-}" ]; then
            add "$(signal_icon "$signal")  $name$lock" saved "${saved["$ssid"]}"$'\t'"$ssid"
        else
            add "$(signal_icon "$signal")  $name$lock" new "$ssid"$'\t'"$security"
        fi
    done < <(scan "$1" | LC_ALL=C sort -t: -k1,1r -k2,2nr)
    [ -n "$connected" ] && add "󰖪  Trennen" disconnect
    add "󰑐  Neu suchen" rescan
    add "󰤮  WLAN aus" radio-off
    add "󰒓  Mehr…" more
}

# connect <name> <nmcli con up arguments…>: progress and result via mako
connect() {
    local name=$1 id
    shift
    id=$(notify -p "Verbinde mit $name …")
    if nmcli --wait 30 con up "$@" >/dev/null 2>&1; then
        notify -r "$id" "Verbunden mit $name"
    else
        notify -r "$id" -u critical "Verbindung fehlgeschlagen: $name"
        return 1
    fi
}

# connect_new <ssid> <security>: new profile, password via fuzzel, removed again on failure
connect_new() {
    local ssid=$1 security=$2 km="" out uuid pw pwfile rc
    local -a sec=()
    case $security in
        ""|--) ;;
        *802.1X*|*WEP*|*OWE*)
            notify "Nicht unterstützt: $ssid" 'Bitte über „Mehr…“ einrichten'
            return 1 ;;
        *WPA1*|*WPA2*) km=wpa-psk ;;
        *WPA3*) km=sae ;;
        *)
            notify "Nicht unterstützt: $ssid" 'Bitte über „Mehr…“ einrichten'
            return 1 ;;
    esac
    [ -n "$km" ] && sec=(wifi-sec.key-mgmt "$km")
    if ! out=$(nmcli con add type wifi con-name "$ssid" ssid "$ssid" "${sec[@]}" 2>&1); then
        notify -u critical "Profil nicht angelegt: $ssid"
        return 1
    fi
    uuid=$(grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' <<<"$out")
    if [ -n "$km" ]; then
        if ! pw=$(dropdown --prompt-only="Passwort für $ssid: " --password </dev/null) || [ -z "$pw" ]; then
            nmcli con delete uuid "$uuid" >/dev/null
            return 0
        fi
        # mktemp creates the file with mode 0600 on the tmpfs of the user
        pwfile=$(mktemp -p "$XDG_RUNTIME_DIR" wifi-menu.XXXXXX)
        printf '802-11-wireless-security.psk:%s\n' "$pw" > "$pwfile"
        connect "$ssid" uuid "$uuid" passwd-file "$pwfile"
        rc=$?
        rm -f "$pwfile"
    else
        connect "$ssid" uuid "$uuid"
        rc=$?
    fi
    [ "$rc" -eq 0 ] || nmcli con delete uuid "$uuid" >/dev/null
}

show_menu() {
    local i
    for i in "${!labels[@]}"; do
        printf '%s\t%s\n' "${labels[$i]}" "$i"
    done
}

if [ "${1:-}" = --print ]; then
    build_menu no
    for i in "${!labels[@]}"; do
        printf '%s\t%s\n' "${labels[$i]}" "${kinds[$i]}"
    done
    exit 0
fi

rescan=no
while :; do
    build_menu "$rescan"
    i=$(show_menu | dropdown --prompt="WLAN: " --with-nth=1 --accept-nth=2 --only-match) || exit 0
    [[ $i =~ ^[0-9]+$ ]] || exit 0
    [ "${kinds[$i]}" = rescan ] || break
    notify -t 2000 "Suche WLANs …"
    rescan=yes
done

arg=${args[$i]}
case ${kinds[$i]} in
    none) ;;
    saved) connect "${arg#*$'\t'}" uuid "${arg%%$'\t'*}" ;;
    new) connect_new "${arg%%$'\t'*}" "${arg#*$'\t'}" ;;
    disconnect) nmcli dev disconnect "$dev" >/dev/null && notify "WLAN getrennt" ;;
    radio-off) nmcli radio wifi off ;;
    radio-on) nmcli radio wifi on ;;
    more) exec nm-connection-editor ;;
esac
