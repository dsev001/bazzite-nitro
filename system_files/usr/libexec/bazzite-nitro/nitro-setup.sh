#!/usr/bin/bash
# Restores personal Flatpaks, Homebrew packages and the Claude CLI.
# Called by `ujust nitro-setup`. Safe to run repeatedly.
set -uo pipefail

DATA_DIR="${NITRO_DATA_DIR:-/usr/share/bazzite-nitro}"
BREW="${NITRO_BREW:-/home/linuxbrew/.linuxbrew/bin/brew}"

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

is_bazzite_default() {
	awk -F/ -v id="$1" '$1 == "app" && $2 == id { found = 1 } END { exit !found }' "$DATA_DIR/bazzite-defaults"
}

migrate_system_apps() {
	local app origin
	while read -r app origin; do
		[[ -z "$app" ]] && continue
		is_bazzite_default "$app" && continue
		if [[ -n "$(flatpak override --system --show "$app" 2>/dev/null)" ]]; then
			echo "Keeping $app in system scope: it has system overrides"
			skipped+=("$app")
			continue
		fi
		if ! flatpak remotes --user --columns=name | grep -qx "$origin"; then
			fail "migrate $app: remote $origin missing in user scope"
			continue
		fi
		flatpak info --user "$app" >/dev/null 2>&1 || install_user "$origin" "$app"
		if ! flatpak info --user "$app" >/dev/null 2>&1; then
			fail "migrate $app: user install failed"
			continue
		fi
		if flatpak uninstall --system -y --noninteractive "$app" </dev/null; then
			migrated+=("$app")
		else
			fail "migrate $app: removing system copy failed"
		fi
	done < <(flatpak list --system --app --columns=application,origin)
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

# Bazzite removes system runtimes that only user apps need, so reinstall them in user scope.
# Runtimes always come from flathub, also for apps from other remotes.
repair_runtimes() {
	local app runtime
	while read -r app; do
		[[ -z "$app" ]] && continue
		if ! runtime="$(flatpak info --user --show-runtime "$app")"; then
			fail "read runtime of $app"
			continue
		fi
		flatpak info "$runtime" >/dev/null 2>&1 && continue
		if install_user flathub "$runtime"; then
			installed+=("$runtime")
		else
			fail "install runtime $runtime"
		fi
	done < <(flatpak list --user --app --columns=application)
}

install_brew_packages() {
	# brew is only on PATH in interactive shells, see /etc/profile.d/brew.sh
	if ! command -v brew >/dev/null && [[ -x "$BREW" ]]; then
		eval "$("$BREW" shellenv)"
	fi
	if ! command -v brew >/dev/null; then
		fail "brew not found, run again after the Homebrew setup has finished"
		return
	fi
	brew bundle --no-upgrade --file "$DATA_DIR/nitro.Brewfile" </dev/null || fail "brew bundle"
}

install_claude_cli() {
	if [[ -e "$HOME/.local/bin/claude" ]]; then
		skipped+=("claude")
		return
	fi
	if curl -fsSL https://claude.ai/install.sh | bash; then
		installed+=("claude")
	else
		fail "install claude"
	fi
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
migrate_system_apps
install_listed_apps
repair_runtimes
install_brew_packages
install_claude_cli
summary
