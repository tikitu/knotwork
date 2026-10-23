#!/usr/bin/env bash
#
# device-which-commit.sh — say which commit the app installed on a device was
# built from.
#
# Imported by peru from the app-tooling pattern `git-commit-stamp`
# (https://github.com/tikitu/app-tooling). Never edit it here: `peru sync`
# refuses to overwrite a changed copy, and the change belongs in app-tooling.
# docs/app-tooling/git-commit-stamp/ says what it is for.
#
# Usage:
#   scripts/device-which-commit.sh <device> <bundle-id>
#
# <device> is anything `xcrun devicectl` accepts: a name, UDID or hostname.
#
# A phone reports the installed app's CFBundleVersion and nothing else of its
# Info.plist, so this reads that — `<count>.<dirty>`, as stamp-git-commit.sh
# --bundle-version wrote it — and finds the commit with that count on the
# first-parent history of HEAD. That is the right commit when the build came
# from this branch (or from a branch it has since merged). The exact SHA is
# only in the app's AppGitCommit key, which the app shows itself.
set -euo pipefail

DEVICE="${1:?usage: device-which-commit.sh <device> <bundle-id>}"
BUNDLE_ID="${2:?usage: device-which-commit.sh <device> <bundle-id>}"

JSON="$(mktemp -t device-which-commit)"
trap 'rm -f "$JSON"' EXIT

# devicectl can exit 0 having written nothing useful; check the file, not
# just the status.
xcrun devicectl device info apps --device "$DEVICE" --bundle-id "$BUNDLE_ID" \
	--json-output "$JSON" >/dev/null
[ -s "$JSON" ] || { echo "✗ devicectl wrote no output for $DEVICE" >&2; exit 1; }

INSTALLED="$(python3 - "$JSON" <<'EOF'
import json, sys
apps = json.load(open(sys.argv[1]))["result"]["apps"]
print(apps[0]["bundleVersion"] if apps else "")
EOF
)"
[ -n "$INSTALLED" ] || { echo "✗ $BUNDLE_ID is not installed on $DEVICE" >&2; exit 1; }
[[ "$INSTALLED" =~ ^([0-9]+)\.([01])$ ]] || {
	echo "✗ installed CFBundleVersion is '$INSTALLED', not <count>.<dirty>: built before the stamp, or without it" >&2
	exit 1
}
INSTALLED="${BASH_REMATCH[1]}"
STATE=clean
[ "${BASH_REMATCH[2]}" = 1 ] && STATE="dirty: uncommitted changes on top of it"

HEAD_COUNT="$(git rev-list --count HEAD)"
echo "installed: commit $INSTALLED ($STATE); HEAD is commit $HEAD_COUNT ($(git rev-parse --short=12 HEAD))"
if [ "$INSTALLED" -gt "$HEAD_COUNT" ]; then
	echo "  built from a commit that is not in HEAD's history: newer, or on another branch"
	exit 0
fi
# Walk back along first parents until the count matches. The count only
# falls along this path, so the walk ends at the match or just past it.
for commit in $(git rev-list --first-parent HEAD); do
	count="$(git rev-list --count "$commit")"
	if [ "$count" -eq "$INSTALLED" ]; then
		echo "  on this branch that is $(git log -1 --format='%h %s' "$commit")"
		if [ "$commit" = "$(git rev-parse HEAD)" ]; then echo "  = HEAD"; fi
		exit 0
	fi
	[ "$count" -lt "$INSTALLED" ] && break
done
echo "  no commit on HEAD's first-parent history has that count: it came from another branch"
