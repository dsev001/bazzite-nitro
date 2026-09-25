#!/usr/bin/bash
# Tests for nitro-setup.sh. Fake flatpak, brew and curl commands record every call.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO/system_files/usr/libexec/bazzite-nitro/nitro-setup.sh"
DATA="$REPO/system_files/usr/share/bazzite-nitro"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
failures=0

# setup [--no-brew]: new sandbox with fake commands and empty state
setup() {
	T="$(mktemp -d -p "$ROOT")"
	export FAKE_STATE="$T/state" HOME="$T/home"
	mkdir -p "$FAKE_STATE/overrides" "$T/bin" "$T/data" "$HOME"
	touch "$FAKE_STATE"/{system-apps,user-apps,user-remotes,fail-install,calls.log}
	echo "org.freedesktop.Platform/x86_64/25.08" >"$FAKE_STATE/runtimes"
	cp "$DATA/nitro.Brewfile" "$DATA/flatpak-remotes" "$DATA/flatpaks" "$T/data/"
	printf '%s\n' "app/org.mozilla.firefox/x86_64/stable" \
		"runtime/org.freedesktop.Platform.VulkanLayer.MangoHud/x86_64/25.08" >"$T/data/bazzite-defaults"

	cat >"$T/bin/flatpak" <<'EOF'
#!/usr/bin/bash
S="$FAKE_STATE"
echo "flatpak $*" >>"$S/calls.log"
cmd="$1"
shift
scope="" show_runtime="" pos=()
for a in "$@"; do
	case "$a" in
	--user) scope=user ;;
	--system) scope=system ;;
	--show-runtime) show_runtime=1 ;;
	-*) ;;
	*) pos+=("$a") ;;
	esac
done
has_app() { awk -v id="$1" '$1 == id { found = 1 } END { exit !found }'; }
case "$cmd" in
remote-add) grep -qx "${pos[0]}" "$S/user-remotes" || echo "${pos[0]}" >>"$S/user-remotes" ;;
remotes) cat "$S/user-remotes" ;;
list)
	if [[ "$scope" == system ]]; then
		awk '{ print $1 "\t" $2 }' "$S/system-apps"
	else
		awk '{ print $1 }' "$S/user-apps"
	fi
	;;
override)
	cat "$S/overrides/${pos[0]}" 2>/dev/null
	exit 0
	;;
install)
	grep -qx "${pos[1]}" "$S/fail-install" && exit 1
	if [[ "${pos[1]}" == */* ]]; then
		echo "${pos[1]}" >>"$S/runtimes"
	else
		echo "${pos[1]} ${pos[0]} org.freedesktop.Platform/x86_64/25.08" >>"$S/user-apps"
	fi
	;;
uninstall) sed -i "/^${pos[0]} /d" "$S/system-apps" ;;
info)
	if [[ -n "$show_runtime" ]]; then
		awk -v id="${pos[0]}" '$1 == id { print $3; found = 1 } END { exit !found }' "$S/user-apps"
	elif [[ "${pos[0]}" == */* ]]; then
		grep -qx "${pos[0]}" "$S/runtimes"
	elif [[ "$scope" == user ]]; then
		has_app "${pos[0]}" <"$S/user-apps"
	else
		cat "$S/system-apps" "$S/user-apps" | has_app "${pos[0]}"
	fi
	;;
esac
EOF

	cat >"$T/bin/curl" <<'EOF'
#!/usr/bin/bash
echo "curl $*" >>"$FAKE_STATE/calls.log"
echo 'mkdir -p "$HOME/.local/bin" && touch "$HOME/.local/bin/claude"'
EOF

	if [[ "${1:-}" != --no-brew ]]; then
		cat >"$T/bin/brew" <<'EOF'
#!/usr/bin/bash
echo "brew $*" >>"$FAKE_STATE/calls.log"
EOF
	fi
	chmod +x "$T"/bin/*
}

run_script() {
	PATH="$T/bin:/usr/bin:/bin" NITRO_DATA_DIR="$T/data" NITRO_BREW="$T/linuxbrew/bin/brew" bash "$SCRIPT" >"$T/out" 2>&1
	RC=$?
}

check() {
	if "${@:2}"; then
		echo "ok   - $1"
	else
		echo "FAIL - $1"
		failures=$((failures + 1))
	fi
}
called() { grep -qF -- "$1" "$FAKE_STATE/calls.log"; }
not_called() { ! called "$1"; }
output_has() { grep -qF -- "$1" "$T/out"; }

test_fresh_install() {
	echo "# fresh install"
	setup
	run_script
	check "exit code 0" test "$RC" -eq 0
	check "adds flathub remote" called "flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"
	check "adds flatpaks remote" called "flatpak remote-add --user --if-not-exists flatpaks https://francoism90.github.io/flatpaks/index.flatpakrepo"
	check "installs Legcord" called "flatpak install --user -y --noninteractive flathub app.legcord.Legcord"
	check "installs Spotify" called "flatpak install --user -y --noninteractive flathub com.spotify.Client"
	check "installs KeePassXC" called "flatpak install --user -y --noninteractive flathub org.keepassxc.KeePassXC"
	check "installs Claude Desktop" called "flatpak install --user -y --noninteractive flatpaks ai.claude.desktop"
	check "uninstalls nothing" not_called "flatpak uninstall"
	check "runs brew bundle without upgrade" called "brew bundle --no-upgrade --file $T/data/nitro.Brewfile"
	check "installs Claude CLI" test -e "$HOME/.local/bin/claude"
}

test_migration() {
	echo "# migration"
	setup
	printf '%s\n' "app.legcord.Legcord flathub" "org.mozilla.firefox flathub" \
		"com.example.Overridden flathub" "org.example.FromFedora fedora" >"$FAKE_STATE/system-apps"
	printf '[Context]\nshared=network;\n' >"$FAKE_STATE/overrides/com.example.Overridden"
	run_script
	check "exit code 1 (unknown remote)" test "$RC" -eq 1
	check "installs Legcord in user scope" called "flatpak install --user -y --noninteractive flathub app.legcord.Legcord"
	check "installs Legcord only once" test "$(grep -c "install --user -y --noninteractive flathub app.legcord.Legcord" "$FAKE_STATE/calls.log")" -eq 1
	check "removes system Legcord" called "flatpak uninstall --system -y --noninteractive app.legcord.Legcord"
	check "does not install Firefox" not_called "noninteractive flathub org.mozilla.firefox"
	check "does not remove Firefox" not_called "noninteractive org.mozilla.firefox"
	check "does not migrate app with overrides" not_called "noninteractive flathub com.example.Overridden"
	check "does not remove app with overrides" not_called "noninteractive com.example.Overridden"
	check "reports app with overrides" output_has "Keeping com.example.Overridden in system scope"
	check "does not install app from unknown remote" not_called "noninteractive fedora org.example.FromFedora"
	check "reports unknown remote" output_has "remote fedora missing in user scope"
}

test_migration_install_fails() {
	echo "# migration: user install fails"
	setup
	echo "app.legcord.Legcord flathub" >"$FAKE_STATE/system-apps"
	echo "app.legcord.Legcord" >"$FAKE_STATE/fail-install"
	run_script
	check "exit code 1" test "$RC" -eq 1
	check "keeps system copy" not_called "flatpak uninstall"
	check "reports failed migration" output_has "migrate app.legcord.Legcord"
}

test_runtime_repair() {
	echo "# runtime repair"
	setup
	echo "org.keepassxc.KeePassXC flathub org.kde.Platform/x86_64/5.15-25.08" >"$FAKE_STATE/user-apps"
	run_script
	check "exit code 0" test "$RC" -eq 0
	check "installs missing KDE runtime" called "flatpak install --user -y --noninteractive flathub org.kde.Platform/x86_64/5.15-25.08"
	check "skips present runtime" not_called "noninteractive flathub org.freedesktop.Platform/x86_64/25.08"
}

test_brew_missing() {
	echo "# brew missing"
	setup --no-brew
	run_script
	check "exit code 1" test "$RC" -eq 1
	check "reports missing brew" output_has "brew not found"
	check "still installs Claude CLI" test -e "$HOME/.local/bin/claude"
}

test_brew_not_on_path() {
	echo "# brew installed but not on PATH"
	setup --no-brew
	mkdir -p "$T/linuxbrew/bin"
	cat >"$T/linuxbrew/bin/brew" <<'EOF'
#!/usr/bin/bash
if [[ "$1" == shellenv ]]; then
	echo "export PATH=\"$(dirname "$0"):\$PATH\""
	exit 0
fi
echo "brew $*" >>"$FAKE_STATE/calls.log"
EOF
	chmod +x "$T/linuxbrew/bin/brew"
	run_script
	check "exit code 0" test "$RC" -eq 0
	check "finds brew outside PATH" called "brew bundle --no-upgrade --file $T/data/nitro.Brewfile"
}

test_rerun_changes_nothing() {
	echo "# second run changes nothing"
	setup
	echo "app.legcord.Legcord flathub" >"$FAKE_STATE/system-apps"
	run_script
	: >"$FAKE_STATE/calls.log"
	run_script
	check "exit code 0" test "$RC" -eq 0
	check "installs nothing" not_called "flatpak install"
	check "uninstalls nothing" not_called "flatpak uninstall"
	check "does not download Claude CLI" not_called "curl"
}

test_fresh_install
test_migration
test_migration_install_fails
test_runtime_repair
test_brew_missing
test_brew_not_on_path
test_rerun_changes_nothing

echo
if ((failures)); then
	echo "$failures check(s) failed"
	exit 1
fi
echo "all checks passed"
