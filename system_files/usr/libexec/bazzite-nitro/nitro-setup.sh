#!/usr/bin/bash
# Restores personal Flatpaks, Homebrew packages and the Claude CLI.
# Called by `ujust nitro-setup`. Safe to run repeatedly.
set -uo pipefail

DATA_DIR="${NITRO_DATA_DIR:-/usr/share/bazzite-nitro}"

migrated=()
installed=()
skipped=()
failed=()

fail() {
	echo "ERROR: $*" >&2
	failed+=("$*")
}

# stdin from /dev/null: the callers read their lists from stdin
install_user() {
	flatpak install --user -y --noninteractive "$1" "$2" </dev/null
}

add_remotes() {
	local name url
	while read -r name url || [[ -n "$name" ]]; do
		[[ -z "$name" ]] && continue
		flatpak remote-add --user --if-not-exists "$name" "$url" </dev/null || fail "add remote $name"
	done <"$DATA_DIR/flatpak-remotes"
}

install_listed_apps() {
	local remote app
	while read -r remote app || [[ -n "$remote" ]]; do
		[[ -z "$remote" ]] && continue
		if flatpak info --user "$app" >/dev/null 2>&1; then
			skipped+=("$app")
		elif install_user "$remote" "$app"; then
			installed+=("$app")
		else
			fail "install $app"
		fi
	done <"$DATA_DIR/flatpaks"
}

summary() {
	echo
	echo "Migrated:  ${migrated[*]:-none}"
	echo "Installed: ${installed[*]:-none}"
	echo "Skipped:   ${skipped[*]:-none}"
	echo "Failed:    ${failed[*]:-none}"
	[[ ${#failed[@]} -eq 0 ]]
}

add_remotes
install_listed_apps
summary
