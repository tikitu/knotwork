#!/usr/bin/env bash
#
# command-inbox-send.sh — hand commands to a running app's command inbox and
# print what it did, without clicks and without taking focus.
#
# Imported by peru from the app-tooling pattern `command-inbox`
# (https://github.com/tikitu/app-tooling). Never edit it here: the change
# belongs in app-tooling. docs/app-tooling/command-inbox/ says how to use it.
# A project calls it from a small script of its own (scripts/send-commands.sh)
# that fills in the options.
#
# Usage:
#   command-inbox-send.sh --notification <name> --dir <dir> --process <pattern> [--timeout <s>] '<json>'|@file.json
#   command-inbox-send.sh --notification <name> --simulator <bundle id> [--udid <id>] [--timeout <s>] '<json>'|@file.json
#
#   --notification  the Darwin notification the app listens for
#   --dir           the inbox directory the app was given (--commands <dir>)
#   --process       a `pgrep -f` pattern matching only the app running with its
#                   inbox (an absolute path to this checkout's build, and
#                   --commands): with no match, it refuses rather than time out
#   --simulator     an iOS app in a simulator, instead of --dir and
#                   --process: the inbox is `Commands` in its Application
#                   Support, and the app is launched first if it is not running
#   --udid          with --simulator, the simulator's UDID (default `booted`,
#                   which with several booted picks one, maybe without the app)
#   --timeout       seconds to wait for the result (default 60)
#
# Prints the app's result.json; exits 1 if a command failed or no result came.
set -euo pipefail

usage() { sed -n '12,27p' "$0" >&2; exit 2; }

notification="" dir="" process="" simulator="" udid="" timeout=60
while [ $# -gt 1 ]; do
	case "$1" in
	--notification) notification="$2" ;;
	--dir) dir="$2" ;;
	--process) process="$2" ;;
	--simulator) simulator="$2" ;;
	--udid) udid="$2" ;;
	--timeout) timeout="$2" ;;
	*) usage ;;
	esac
	shift 2
done
[ $# -eq 1 ] && [ -n "$notification" ] || usage
request="$1"

if [ -n "$simulator" ]; then
	[ -z "$dir$process" ] || usage
	device="${udid:-booted}"
	data="$(xcrun simctl get_app_container "$device" "$simulator" data)" || {
		if [ -n "$udid" ]; then
			echo "✗ $simulator is not installed in simulator $udid, or it is not booted" >&2
		else
			echo "✗ $simulator is not installed in a booted simulator (with several booted, pass --udid)" >&2
		fi
		exit 1
	}
	dir="$data/Library/Application Support/Commands"
	# Launching a running app only brings it forward inside the simulator; a
	# cold launch runs the waiting inbox itself.
	post() {
		xcrun simctl launch "$device" "$simulator" >/dev/null
		xcrun simctl spawn "$device" notifyutil -p "$notification"
	}
else
	[ -n "$dir" ] && [ -n "$process" ] && [ -z "$udid" ] || usage
	# The app listens only where its data is disposable, so refuse rather than
	# time out when it is not running that way.
	pgrep -f "$process" >/dev/null || {
		echo "✗ no process matches '$process': start the app with its command inbox (make run-scratch)" >&2
		exit 1
	}
	post() { notifyutil -p "$notification"; }
fi

mkdir -p "$dir"
rm -f "$dir/result.json"
# Written aside and moved, so the app never reads half a file.
case "$request" in
@*) cat "${request#@}" >"$dir/inbox.json.partial" ;;
*) printf '%s' "$request" >"$dir/inbox.json.partial" ;;
esac
mv "$dir/inbox.json.partial" "$dir/inbox.json"
post

for _ in $(seq $((timeout * 5))); do
	if [ -f "$dir/result.json" ]; then
		cat "$dir/result.json"
		echo
		# The top-level `error` only: a command's own detail may hold the word.
		if plutil -extract error raw -o - "$dir/result.json" >/dev/null 2>&1; then exit 1; fi
		exit 0
	fi
	sleep 0.2
done
echo "✗ no result after ${timeout}s from $dir: is the app running and accepting commands?" >&2
exit 1
