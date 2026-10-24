# The command inbox: transport, format, result

What every app with the `command-inbox` pattern shares. The app's own
`docs/commands.md` lists its commands, with examples, and refers here for
the rest.

## Sending

```sh
make run-scratch
scripts/send-commands.sh '{"commands":[{"state":{}}]}'
scripts/send-commands.sh @check.json
```

`scripts/send-commands.sh` is the project's, a few lines calling the
imported `scripts/command-inbox-send.sh` with the app's notification name,
inbox directory and process. It refuses at once when no app is running with
its inbox, and fails when a command fails or no result comes within its
timeout (60 s by default).

## The transport

A Darwin notification carries no arguments, so the commands go in a file:

1. The sender writes `inbox.json` into the inbox directory, writing it
   aside and moving it into place so the app never reads half a file.
2. The sender posts the app's Darwin notification (conventionally
   `<bundle id>.commands`).
3. The app removes `inbox.json`, runs the commands **in order, stopping at
   the first failure**, and writes `result.json` beside it once the last
   has finished. A command can wait (for data to load, an animation, a
   dialog); the result says what happened, not what was started.
4. The sender prints `result.json`, and exits non-zero if it holds an
   `error`.

An inbox already waiting when the app starts its inbox runs then. A command
of the app's waits until the app is ready (its data loaded, its window
open; the app says what that means) for up to its timeout, 30 s unless the
app sets another, so a script can send commands straight after launch.

The inbox directory is given to the app as `--commands <dir>` on the Mac,
never inside an app container (touching one from a terminal raises a
privacy prompt on screen); in an iOS simulator it is `Commands` in the
app's Application Support.

## The file format

```
{
  "id": "optional, echoed back into the result",
  "commands": [
    { "<command>": { "<field>": <value>, … } },
    { "pause": { "seconds": 0.5 } },
    { "snapshot": {} }
  ]
}
```

A command is an object with **exactly one key**, its name, whose value is
an object of its fields (`{}` for none). Decoding is strict: an unknown
command, an unknown field, a second key or a value that is not an object is
an error, and nothing in the file runs. A typo cannot quietly do nothing.

## The inbox's own commands

Every app has these; no control performs them.

| Command | Fields | Does |
|---|---|---|
| `pause` | `seconds` | Waits: for an animation to finish before a `snapshot`, say. |
| `snapshot` | | Has the app draw its windows to files, and reports the files. An app that gives the inbox no way to draw fails it. |

An app command of the same name is never reached from a file.

## The result file

```
{
  "completed" : [
    { "command" : "add", "message" : "added 'Buy milk'" },
    { "command" : "state", "message" : "state", "state" : { … } }
  ],
  "requestID" : "the id from the request, if it had one"
}
```

Each completed command has its `message`, saying what it did, and a command
with structured detail, conventionally the app's `state`, has it under
`state`: a check can read what the model holds rather than pixels.

On failure the run stops there and `error` is present:

```
{
  "completed" : [],
  "error" : "delete failed: no item 'Buy mlik'"
}
```

`could not read commands: …` is a file that did not decode, and says where
and why.
