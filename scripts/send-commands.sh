#!/bin/sh
# Drive the app started by `make ios-run-commands`: docs/commands.md. The
# sending is app-tooling's (command-inbox), in scripts/command-inbox-send.sh.
#
# Usage:  scripts/send-commands.sh '<json>'      (or @file.json)
#
# It sends to one simulator, by UDID, never `booted` (which picks any of
# several booted): $IOS_SIM_UDID if set, else the one `make ios-run` uses
# (`make ios-sim-udid`, which follows IOS_SIM).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
udid="${IOS_SIM_UDID:-$(make -s -C "$ROOT" ios-sim-udid)}" || exit 1
[ -n "$udid" ] || { echo "✗ no simulator UDID: set IOS_SIM or IOS_SIM_UDID" >&2; exit 1; }
exec "$ROOT/scripts/command-inbox-send.sh" \
	--notification org.logophile.Knotwork.commands \
	--simulator org.logophile.Knotwork \
	--udid "$udid" \
	"$@"
