# command-inbox changelog

## v0.9.0 (2026-11-14)

- **`command-inbox-send.sh --udid <id>`** names the simulator for
  `--simulator`, in all three `simctl` calls (finding the container,
  launching, notifying). Without it the script uses `booted`, as before,
  and with several simulators booted that picks one that may not have the
  app ("not installed in a booted simulator"), or sends to the wrong one.
  A project with an iOS app: `make app-tooling-update`, then make its
  simulator send path pass the UDID it already uses for `make ios-run`
  (`apply.md`, step 6). A project without one: update only.

## v0.6.0 (2026-10-24)

First version, from the starter's command inbox and three apps' copies of
it: the runner and strict decoding as app-utils' `CommandInbox` library
(app-utils 0.4.0), the sender as `scripts/command-inbox-send.sh` with its
parameters as options, `guide.md`.
Beyond the starter's copy: the inbox directory comes from `--commands
<dir>`, outside any container; app commands wait for the app to be ready
(`isReady:`, with a timeout); `pause` and `snapshot` are the inbox's own
commands; a reply can carry structured detail (`state`); the sender reads
the result's `error` key rather than grepping for the word, and can send to
an iOS simulator (`--simulator`).

A project with a copy (from the starter, or another app): follow `apply.md`.
Delete the copy's `CommandInbox.swift`, `AnyKey` and `CommandFile`, move its
decoder onto `StrictCommand`, make its `scripts/send-commands.sh` the
wrapper in step 6, and pass `--commands` from `run-scratch` (step 5; with
the entitlement if the app is sandboxed). Remove any `app-tooling.toml`
table recording the copy.

A project that followed this pattern's branch before the library moved to
app-utils has the module imported by peru, under a `command-inbox-swift`
rule: delete that rule and its import line from `peru.yaml`, the imported
`Sources/CommandInbox/` and its target, and depend on the library instead
(`apply.md` step 2). The project's code does not change.
