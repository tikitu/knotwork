# Driving the app from a script

The app can be driven with no touches. This is how a change gets *verified*
rather than merely compiled, and it is why `AppModel` exists at all.

```sh
make ios-run-commands               # simulator, accepting commands; prints its UDID
IOS_SIM=<udid> scripts/send-commands.sh '{"commands":[{"newGrid":{"rows":4,"cols":6}}]}'
make ios-screenshot                 # build/simulator.png
```

## The invariant

**Every gesture performs an `AppCommand` through `AppModel.perform(_:)`, and
so does the command inbox.** A script therefore exercises the same code a
touch does. A control that does its work itself is a bug, because it is a
path no script can reach — and a path no script can reach is a path nobody
checks.

Controls call `attempt(_:)`, which logs a failure instead of throwing it into
SwiftUI. The one exception is a drag *in progress*: the red line that
follows the finger is view state. What the drag does, when it ends, is a
command (`toggle` or `cut`).

## Where it is enabled, and where it is not

The app accepts commands only when launched with `--accept-commands`, which
`make ios-run-commands` passes. Launched any other way, from the home screen
or by `make ios-run`, it does not listen. There is no stored data yet, so
there is no scratch mode: the knot lives in memory and is gone when the app
quits.

## The transport

A Darwin notification carries no arguments, so the commands go in a file:

1. The sender writes `inbox.json` into `Library/Application Support/Commands/`
   in the app's data container (`xcrun simctl get_app_container booted
   org.logophile.Knotwork data`), writing it aside and moving it into place
   so the app never reads half a file.
2. The sender posts the Darwin notification `org.logophile.Knotwork.commands`
   inside the simulator (`xcrun simctl spawn booted notifyutil -p …`).
3. The app deletes the inbox, runs the commands **in order, stopping at the
   first failure**, and writes `result.json` beside it.
4. The sender reads `result.json` and exits non-zero if it holds an `error`.

An inbox already waiting when the app launches runs at startup.

## The file format

```json
{
  "id": "optional, echoed back into the result",
  "commands": [
    { "newGrid": { "rows": 4, "cols": 6 } },
    { "cut": { "from": [2, 0], "to": [2, 8] } },
    { "toggle": { "at": [3, 3] } }
  ]
}
```

A command is an object with **exactly one key**, its name. Decoding is
strict: an unknown command, an unknown field, or more than one key is an
error rather than something ignored, so a typo cannot quietly do nothing.

`CommandFileTests` decodes every JSON example in this file verbatim, so if the
format changes and this document does not, the test fails.

### Grid points

A point is `[x, y]`, in tiles from the top left: a knot of `rows` × `cols`
cells runs from `[0, 0]` to `[2 * cols, 2 * rows]`. Where `x + y` is odd, the
point is on a segment between cells' corners, which can carry a break line;
where both are odd, it is the centre of a cell.

### The commands

| Command | Fields | Does |
|---|---|---|
| `newGrid` | `rows`, `cols` | Replaces the knot with a fresh one, bordered all round. 1 to 200 cells each way. At launch the view does this itself, with as many cells as fit. |
| `toggle` | `at` | A tap. On a segment, cycles its break line: horizontal, vertical, none. On a cell's centre, empties the cell or refills it. |
| `cut` | `from`, `to` | A drag. Toggles break lines all along a straight line along a row or column. A diagonal, a point off the grid, or a cut that goes nowhere is an error. |

```json
{
  "commands": [
    { "newGrid": { "rows": 2, "cols": 3 } },
    { "cut": { "from": [0, 2], "to": [6, 2] } },
    { "toggle": { "at": [1, 1] } }
  ]
}
```

## The result file

```json
{
  "requestID" : "the id from the request, if it had one",
  "completed" : [
    { "command" : "newGrid", "message" : "new 4 × 6 knot" }
  ]
}
```

On failure the run stops there and `error` is present:

```json
{
  "completed" : [],
  "error" : "cut failed: a cut runs straight along a row or column; (0, 0) to (2, 2) does not"
}
```

## Seeing what happened

Commands change state; they do not describe the screen. `make
ios-screenshot` saves the booted simulator's screen with `xcrun simctl io`,
which needs neither focus nor the Simulator app.
