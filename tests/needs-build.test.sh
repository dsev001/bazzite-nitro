#!/usr/bin/bash
# Tests for `just needs-build`. A fake skopeo answers from files in $FAKE_STATE.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
REVISION="$(git -C "$REPO" rev-parse HEAD)"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
failures=0

# Fixed configuration. The environment wins over image-template.env.
# Mixed case: GHCR paths are lowercase.
export REPO_ORGANIZATION="Test-Org" IMAGE_NAME="test-image" DEFAULT_TAG="latest"
export BASE_IMAGE="registry.test/base/image:stable"

mkdir -p "$ROOT/bin"
cat >"$ROOT/bin/skopeo" <<'FAKE'
#!/usr/bin/bash
# Fake skopeo inspect. Knows exactly three references, like a registry.
S="$FAKE_STATE"
ref="${!#}"
case "$ref" in
"docker://registry.test/base/image:stable") file="$S/base" ;;
"docker://ghcr.io/test-org/test-image:latest") file="$S/own" ;;
"docker://ghcr.io/test-org/test-image:sha256-2222.sig") file="$S/sig" ;;
*) file="$S/none" ;;
esac
if [[ ! -f "$file" ]]; then
	echo "level=fatal msg=\"reading manifest ${ref}: manifest unknown\"" >&2
	exit 1
fi
cat "$file"
FAKE
chmod +x "$ROOT/bin/skopeo"
export PATH="$ROOT/bin:$PATH"

# setup: empty state. Files: base, own (inspect JSON), sig (exists = signed)
setup() {
	FAKE_STATE="$(mktemp -d -p "$ROOT")"
	export FAKE_STATE
}

# base DIGEST: base image with the given digest
base() {
	printf '{"Digest": "%s", "Labels": {"containers.bootc": "1"}}\n' "$1" >"$FAKE_STATE/base"
}

# own_image BASE REVISION: own image with digest sha256:2222 and the given labels
own_image() {
	printf '{"Digest": "sha256:2222", "Labels": {"containers.bootc": "1", "org.opencontainers.image.base.digest": "%s", "org.opencontainers.image.revision": "%s"}}\n' "$1" "$2" >"$FAKE_STATE/own"
}

# expect NAME WANT: run the recipe, compare its output
expect() {
	local out rc
	out="$(cd "$REPO" && just needs-build 2>/dev/null)"
	rc=$?
	if [[ $rc -eq 0 && "$out" == "$2" ]]; then
		echo "ok   - $1"
	else
		echo "FAIL - $1: rc=$rc out='$out' want='$2'"
		failures=$((failures + 1))
	fi
}

setup
base sha256:1111
own_image sha256:1111 "$REVISION"
touch "$FAKE_STATE/sig"
expect "same base and revision, signed" false

setup
base sha256:3333
own_image sha256:1111 "$REVISION"
touch "$FAKE_STATE/sig"
expect "new base" true

setup
base sha256:1111
own_image sha256:1111 0000000000000000000000000000000000000000
touch "$FAKE_STATE/sig"
expect "commit not built" true

setup
base sha256:1111
expect "own image missing" true

setup
base sha256:1111
echo '{"Digest": "sha256:2222", "Labels": null}' >"$FAKE_STATE/own"
touch "$FAKE_STATE/sig"
expect "labels missing" true

setup
base sha256:1111
own_image sha256:1111 "$REVISION"
expect "signature missing" true

setup
own_image sha256:1111 "$REVISION"
touch "$FAKE_STATE/sig"
if (cd "$REPO" && just needs-build >/dev/null 2>&1); then
	echo "FAIL - base unreadable: recipe succeeded"
	failures=$((failures + 1))
else
	echo "ok   - base unreadable fails"
fi

if ((failures)); then
	echo "$failures check(s) failed"
	exit 1
fi
echo "all checks passed"
