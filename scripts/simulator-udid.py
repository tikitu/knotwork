#!/usr/bin/env python3
"""Print the UDID of the available simulator named argv[1] on the newest iOS
runtime that has one. Names repeat across runtimes (one "iPhone 17" per
runtime), and `xcrun simctl … '<name>'` and xcodebuild's `name=` each choose
among them by their own rules, so the Makefile resolves the name once, here,
and uses the UDID everywhere. Exits non-zero, listing the names there are,
if there is no such simulator."""

import json
import re
import subprocess
import sys

name = sys.argv[1]
devices = json.loads(
    subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available", "-j"],
        check=True, capture_output=True, text=True,
    ).stdout
)["devices"]


def version(runtime):
    match = re.search(r"iOS-(\d+)-(\d+)(?:-(\d+))?$", runtime)
    return tuple(int(part or 0) for part in match.groups()) if match else None


ios = sorted(
    ((version(runtime), found) for runtime, found in devices.items() if version(runtime)),
    reverse=True,
)
for _, found in ios:
    for device in found:
        if device["name"] == name:
            print(device["udid"])
            sys.exit(0)

names = sorted({device["name"] for _, found in ios for device in found})
print(f"no available iOS simulator named '{name}'; there are: {', '.join(names)}", file=sys.stderr)
sys.exit(1)
