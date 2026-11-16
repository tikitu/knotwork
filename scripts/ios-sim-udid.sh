#!/usr/bin/env bash
#
# ios-sim-udid.sh — the UDID of this project's own iOS simulator, made if it
# is missing, so `make ios-run` and the command sender address the same
# device even when other projects' simulators are booted.
#
# Imported by peru from the app-tooling pattern `command-inbox`
# (https://github.com/tikitu/app-tooling). Never edit it here: the change
# belongs in app-tooling. docs/app-tooling/command-inbox/ says how to use it.
#
# Usage: scripts/ios-sim-udid.sh <name> [<device type>]
#
#   <name>         the project's simulator, named after the project
#                  ("MyApp iPhone"). A device type's own name ("iPhone 17")
#                  is refused: other projects' simulators have it too.
#   <device type>  what to make when there is no simulator of that name: a
#                  device type's name or identifier (`xcrun simctl list
#                  devicetypes`), on the newest iOS runtime. Without it, a
#                  missing simulator is an error.
#
# $IOS_SIM_UDID, when set, wins (a one-off run on another simulator).
# Otherwise: the available simulator called exactly <name>, a booted one
# first; else a new one. Prints the UDID; exits 1, saying why, when there is
# none. Never boots or launches anything.
set -euo pipefail

if [ -n "${IOS_SIM_UDID:-}" ]; then
	echo "$IOS_SIM_UDID"
	exit 0
fi
[ $# -ge 1 ] && [ $# -le 2 ] && [ -n "$1" ] || { sed -n '11,24p' "$0" >&2; exit 2; }
name="$1"
device_type="${2:-}"

# One python3 over simctl's JSON: an exact name match (a text grep for
# "iPad Pro 13-inch (" would also match "iPad Pro 13-inch (M5)"), and the
# newest runtime by version, not by string.
pick() {
	python3 -I -c '
import json, subprocess, sys
mode, name = sys.argv[1], sys.argv[2]
def simctl(*args):
    return json.loads(subprocess.run(["xcrun", "simctl", "list", *args, "-j"],
        check=True, capture_output=True, text=True).stdout)
if mode == "device-type-name":
    print("yes" if any(t["name"] == name for t in simctl("devicetypes")["devicetypes"]) else "")
elif mode == "udid":
    found = [d for ds in simctl("devices", "available")["devices"].values() for d in ds if d["name"] == name]
    found.sort(key=lambda d: d["state"] != "Booted")
    print(found[0]["udid"] if found else "")
elif mode == "runtime":
    runtimes = [r for r in simctl("runtimes", "available")["runtimes"] if r.get("platform") == "iOS"]
    runtimes.sort(key=lambda r: tuple(int(p) for p in r["version"].split(".") if p.isdigit()))
    print(runtimes[-1]["identifier"] if runtimes else "")
' "$@"
}

if [ -n "$(pick device-type-name "$name")" ]; then
	echo "✗ '$name' is a device type's name, which other projects' simulators share: name the simulator after the project ('MyApp iPhone')" >&2
	exit 1
fi

udid="$(pick udid "$name")"
if [ -z "$udid" ]; then
	[ -n "$device_type" ] ||
		{ echo "✗ no available simulator called '$name', and no device type to make one with" >&2; exit 1; }
	runtime="$(pick runtime "")"
	[ -n "$runtime" ] ||
		{ echo "✗ no iOS simulator runtime (xcodebuild -downloadPlatform iOS)" >&2; exit 1; }
	udid="$(xcrun simctl create "$name" "$device_type" "$runtime")" ||
		{ echo "✗ could not make simulator '$name' ($device_type, $runtime)" >&2; exit 1; }
	echo "  made simulator '$name' ($device_type, $runtime): $udid" >&2
fi
echo "$udid"
