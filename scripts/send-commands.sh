#!/usr/bin/env bash
#
# send-commands.sh — run commands in the app on the booted simulator, and
# print the result. See docs/commands.md.
#
# Usage:  scripts/send-commands.sh '<json>'      (or the JSON on stdin)
#
# The app must have been launched with --accept-commands
# (`make ios-run-commands`); otherwise nothing answers, and this says so after
# a timeout. Exits non-zero if the result holds an error.
#
# Environment:
#   IOS_SIM   the simulator's UDID, as `make ios-run-commands` prints it
#             (default: booted, which is ambiguous when several are)
set -euo pipefail

BUNDLE_ID="org.logophile.Knotwork"
NOTIFICATION="org.logophile.Knotwork.commands"
DEVICE="${IOS_SIM:-booted}"
TIMEOUT_SECONDS=10

json="${1:-$(cat)}"

container="$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" data)" || {
	echo "✗ $BUNDLE_ID is not installed on $DEVICE (make ios-run-commands)" >&2
	exit 1
}
[ -d "$container" ] || { echo "✗ no data container at $container" >&2; exit 1; }
dir="$container/Library/Application Support/Commands"
mkdir -p "$dir"
rm -f "$dir/result.json"

# Written aside, then moved into place, so the app never reads half a file.
printf '%s\n' "$json" > "$dir/inbox.json.tmp"
mv "$dir/inbox.json.tmp" "$dir/inbox.json"
xcrun simctl spawn "$DEVICE" notifyutil -p "$NOTIFICATION"

for _ in $(seq $((TIMEOUT_SECONDS * 10))); do
	[ -s "$dir/result.json" ] && break
	sleep 0.1
done
if [ ! -s "$dir/result.json" ]; then
	rm -f "$dir/inbox.json"
	echo "✗ no result after ${TIMEOUT_SECONDS}s: is the app running with --accept-commands? (make ios-run-commands)" >&2
	exit 1
fi

cat "$dir/result.json"
if plutil -extract error raw "$dir/result.json" >/dev/null 2>&1; then
	exit 1
fi
