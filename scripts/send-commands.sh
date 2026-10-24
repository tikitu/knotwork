#!/bin/sh
# Drive the app started by `make ios-run-commands`: docs/commands.md. The
# sending is app-tooling's (command-inbox), in scripts/command-inbox-send.sh.
#
# Usage:  scripts/send-commands.sh '<json>'      (or @file.json)
#
# It targets the *booted* simulator, which is ambiguous when several are
# booted (docs/commands.md).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/scripts/command-inbox-send.sh" \
	--notification org.logophile.Knotwork.commands \
	--simulator org.logophile.Knotwork \
	"$@"
