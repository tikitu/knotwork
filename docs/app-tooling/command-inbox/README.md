# command-inbox

A script or an agent drives the running app, with no clicks and nothing
coming to the front: it writes the app's commands to a file, posts a
notification, and reads back what each one did. This is how a change is
*checked* after launch, not only compiled: open a screen, act on it, read
back its state, take a picture.

## The problem

An agent checking a change has to use the app. Clicking and typing need the
screen, the pointer and focus, which belong to whoever is using the machine,
and a screenshot says what is drawn, not what the model holds. Each app that
solved this copied the same inbox from the next and adapted it by hand, so
none of them got the others' fixes.

## What it does

The app's commands are one Swift enum, which every button, key and menu
item performs through one `perform` on the model. The inbox is a second way
in to the same `perform`:

1. `scripts/send-commands.sh '<json>'` (the project's, calling the imported
   `scripts/command-inbox-send.sh`) writes `inbox.json` into the inbox
   directory and posts a Darwin notification.
2. The app removes the file, runs its commands in order, stopping at the
   first failure, and writes `result.json`: what each command said it did,
   with structured detail where a command has it (a `state` command's
   report), and the error that stopped it.
3. The script prints the result and fails if a command did.

The pattern supplies, with app-utils:

- **The `CommandInbox` library**, a product of app-utils
  (<https://github.com/tikitu/app-utils/blob/main/docs/CommandInbox.md>),
  which the app's package depends on like any other:
  - `CommandInbox<Command>`, the runner. The app gives it a `perform`, and
    optionally an `isReady` check, which app commands wait for (with a
    timeout) so a script can send commands straight after launch, and a
    `snapshot` that draws the windows.
  - Strict decoding: `StrictCommand`, so a command is an object with
    exactly one key, its name, holding only its own fields. An unknown
    command, an unknown field or a second key is an error: a typo in a
    script cannot quietly do nothing.
  - Two commands every app gets, which no control performs: `pause
    {seconds}` and `snapshot {}`.
  - `CommandDocumentation.requests(in:)`, for a test that decodes every
    example in the project's `docs/commands.md`, so the document and the
    decoder cannot drift apart.
- **`scripts/command-inbox-send.sh`**, the sender, with the notification
  name, the directory and the process to expect as options. It refuses at
  once when no app is listening, rather than timing out. `--simulator <bundle
  id>` sends to an iOS app in the booted simulator instead.
- **[`guide.md`](guide.md)**, the transport, file format, result and the
  inbox's own commands, which the project's `docs/commands.md` refers to
  rather than repeats.

The app keeps its command enum, its decoding (a few lines per command, on
`StrictCommand`), its `perform`, where it starts the inbox, and its
`docs/commands.md`.

## Where the inbox lives

**Never in an app container on the Mac.** A process without Full Disk
Access that reads or writes another app's container (`~/Library/Containers/
<id>/…`) raises "would like to access data from other apps" on the screen of
whoever is using the machine, and an agent's shell usually has no Full Disk
Access. So the app takes the directory as a launch argument, `--commands
<dir>`, which the project's `run-scratch` passes:

- **An unsandboxed app:** anywhere; conventionally beside the scratch data
  (`build/scratch/Commands`, in the checkout). Nothing else is needed.
- **A sandboxed app:** `~/Library/Caches/<App>-scratch/Commands`, which one
  sandbox temporary exception opens to the app, read-write
  (`com.apple.security.temporary-exception.files.home-relative-path.read-write`).
  It is harmless in a shipped app (the app touches it only when launched
  with `--commands` on scratch data), and fine for Developer ID; App Store
  review objects to temporary exceptions, so an App Store app gives its
  development builds an entitlements file of their own (`apply.md`).
- **An iOS simulator:** `Commands` in the app's Application Support, which
  the sender finds with `simctl`. The simulator's data is disposable, so the
  app can start the inbox there unconditionally.

## Never on real data

The app starts the inbox only where its data does not matter: a scratch run
on the Mac (`scratch-data`'s `--scratch-database`, or the project's own
scratch database), the iOS simulator. A command can then never act on what
someone is working with. The pattern cannot check this; `apply.md` says
where the condition goes.

## What it asks of a project

- A Swift package the app is built from, to depend on app-utils'
  `CommandInbox` product (app-utils 0.4.0 or later).
- Its commands as an enum performed through the model, or the will to make
  them so. Without that invariant the inbox drives a different path from the
  one people use, and checks the wrong thing.
- A scratch run (the [`scratch-data`](https://github.com/tikitu/app-tooling/tree/main/patterns/scratch-data)
  pattern, or the project's own).

## What it does not do

- **Keep controls honest.** That every control goes through `perform` is the
  app's invariant. An app can enforce it with `private(set)` on the model's
  state, so a view that changed it itself would not compile, or with a lint
  rule against writes outside the model.
- **Run on several inboxes at once.** The notification is the same for every
  copy of the app. Unsandboxed, each checkout's inbox is its own directory,
  so copies from two checkouts do not take each other's commands. Sandboxed,
  the directory is fixed by the entitlement, and, as with a sandboxed app's
  scratch data, there is one scratch run per machine at a time.
- **Draw the windows.** `snapshot` calls what the app gives it; drawing an
  app's windows to PNGs without Screen Recording permission is the app's.
