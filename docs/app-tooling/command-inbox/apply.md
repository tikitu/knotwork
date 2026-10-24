# Applying command-inbox

Read [`README.md`](README.md) first for what this does and why, and
[`guide.md`](guide.md) for the format scripts use.

## Detect

- **Already adopted:** `peru.yaml` imports `app-tooling|command-inbox`.
- **Copied by hand**, from the app-tooling starter or from another app
  (sometimes recorded in `app-tooling.toml` under a table of its own, such
  as `[from-starter.command-inbox]`): a `CommandInbox.swift` with a
  `CFNotificationCenterAddObserver` or `notify_register_dispatch`, a
  `CommandFile.swift` with `struct AnyKey: CodingKey`, a
  `scripts/send-commands.sh` that writes `inbox.json` and runs `notifyutil
  -p`, a `docs/commands.md` (or `plans/commands.md`), and a test that reads
  that document's JSON examples. Diff each against this pattern. The app's
  own parts stay (its command enum, its decoding, `perform`, its
  `docs/commands.md`); the rest is replaced by the steps below. A difference
  in the shared parts is either an old copy or an improvement that belongs
  in app-tooling: say which, and bring the improvement here rather than
  keeping it in the project.
- **Something else doing this job.** Look for a URL scheme the app handles
  for scripting, AppleScript or App Intents used by scripts, XCUITest or
  accessibility-driven UI scripts, `DistributedNotificationCenter`
  observers. Describe what the project has and what this would replace to
  the user, and ask before changing anything.
- **Not adopted:** none of the above. If the app's controls do not perform
  commands through one place, say so to the user before starting: making
  them do so is the larger part of the work, and the point of it.

## Parameters

| Parameter | Where to find it |
|---|---|
| The package | the Swift package the app's code is in (`Package.swift`'s directory, or `Packages/<Name>Kit`) |
| The command enum and `perform` | the model's: `AppCommand` and `AppModel.perform(_:)` in apps made from the starter. If there is none, it is made in step 3 |
| The notification name | `<bundle id>.commands` |
| The inbox directory | Unsandboxed Mac app: beside the scratch data, in the checkout (`$(CURDIR)/build/scratch/Commands`). Sandboxed (`com.apple.security.app-sandbox` in the entitlements): `$(HOME)/Library/Caches/<App>-scratch/Commands`. iOS: none to choose |
| The process pattern | the absolute path of the executable in this checkout's built bundle, then `.*--commands`: `"$ROOT/build/MyApp.app/Contents/MacOS/MyApp.*--commands"` |
| Ready | what the app's commands need before they can run: data loaded, a window's model present. Nothing, if they need nothing |
| Snapshot | how the app draws its windows to files, if it does; otherwise no `snapshot` |

## Steps

The project must already have `pattern-imports`.

**1. Import the pattern.** In `peru.yaml`, under `imports:`:

```yaml
    app-tooling|command-inbox: ./
    app-tooling|command-inbox-docs: docs/app-tooling/command-inbox/
```

and beside the other rules:

```yaml
rule command-inbox:
    export: patterns/command-inbox/files
rule command-inbox-docs:
    pick: [patterns/command-inbox/README.md, patterns/command-inbox/apply.md, patterns/command-inbox/CHANGELOG.md, patterns/command-inbox/guide.md]
    export: patterns/command-inbox
```

Then `uvx peru@1.3.5 sync`. It refuses to overwrite files the project
already has: a hand-made copy at `scripts/command-inbox-send.sh` is a
Detect finding.

**2. Depend on the library.** In the package's `Package.swift`:

```swift
.package(url: "https://github.com/tikitu/app-utils", exact: "0.4.0"),
// …in the dependencies of the target that holds the commands, of the app
// target that starts the inbox, and of the commands' test target:
.product(name: "CommandInbox", package: "app-utils"),
```

`0.4.0` is the first app-utils release with `CommandInbox`; keep the
version the package already pins if it is newer. Then `swift package
resolve` and commit `Package.resolved`. If the app target is in another
package (an Xcode project's), add the product to it there.

**3. The commands.** The command enum conforms to `InboxCommand`, with a
public `name`, and decodes itself on `StrictCommand`:

```swift
import CommandInbox

extension AppCommand: InboxCommand {
    private enum Name: String, CommandName {
        case add, delete

        var fields: Set<String> {
            switch self {
            case .add: ["title"]
            case .delete: ["items"]
            }
        }
    }

    private enum Field: String, CodingKey { case title, items }

    public init(from decoder: any Decoder) throws {
        let command = try StrictCommand<Name>(from: decoder)
        let fields = try command.fields(keyedBy: Field.self)
        switch command.name {
        case .add: self = .add(title: try fields.decode(String.self, forKey: .title))
        case .delete: self = .delete(try fields.decode([String].self, forKey: .items))
        }
    }
}
```

`command.error("…")` makes the error for a check the field names cannot
make ("takes exactly one of index and taxon"). A hand-made copy's decoder
moves over almost as it is: its `Name` enum becomes a `CommandName`, and the
key and field checks at its top become the `StrictCommand` line. Its
`AnyKey`, `CommandFile`, `CommandResult` and inbox class are deleted; a
`pause` or `snapshot` command of its own becomes the inbox's.

**4. Start the inbox, only on scratch data.** Where the app starts, before
its scenes (for the Mac, the `Entry.main()` that prepares dependencies),
keep the inbox for the app's lifetime and start it:

```swift
/// Commands from scripts: only on scratch data (docs/commands.md).
@MainActor
static let inbox: CommandInbox<AppCommand>? = {
    guard isScratch, let directory = InboxDirectory.argument(in: CommandLine.arguments)
    else { return nil }
    return CommandInbox(directory: directory, notificationName: "org.example.myapp.commands") {
        CommandReply(try await model.perform($0))
    }
}()
```

and `inbox?.start()` in `main()`, from `MainActor.assumeIsolated` if
`main()` is not isolated. The condition is the app's: `--scratch-database`
(`scratch-data`), or a database other than the real one. If `perform`
returns a `CommandReply` already, pass it as it is.

Give `isReady:` if commands need something first, for example
`isReady: { !model.items.isEmpty }`; throw an `InboxError` from it for a
state waiting will not fix. Give `snapshot:` if the app can draw its windows
to files. A `state` command returns `CommandReply("state", state: …)` with
an `Encodable` value, which the result carries as it is.

For an iOS app, start it in the simulator only, with the default
directory:

```swift
#if targetEnvironment(simulator)
inbox = CommandInbox(directory: InboxDirectory.applicationSupport, …)
inbox?.start()
#endif
```

**5. Pass the directory.** The scratch run launches the app with
`--commands <dir>`, **before** any switch without a value
(`--scratch-database`): AppKit reads launch arguments as `-key value` pairs.

- With `scratch-data`: before its include, `SCRATCH_ARGS := --commands
  "$(COMMANDS_DIR)"`, and `COMMANDS_DIR` set to the directory.
- With a `run-scratch` of the project's own: add `--commands
  "$(COMMANDS_DIR)"` to its `open … --args`, before any lone switch.

For a **sandboxed** app, also `mkdir -p "$(COMMANDS_DIR)"` in the run-scratch
recipe (or a prerequisite of it; the app cannot create it), and add to the
entitlements:

```xml
<!--
  The command inbox of a scratch run (docs/commands.md), outside the
  container: a script that touches the container raises a privacy prompt
  on the screen of whoever is using the machine.
-->
<key>com.apple.security.temporary-exception.files.home-relative-path.read-write</key>
<array>
	<string>/Library/Caches/MyApp-scratch/Commands/</string>
</array>
```

(no `--` inside the XML comment: it ends the comment and breaks the file).
For an app distributed through the App Store, put it in an entitlements file
of its own that only development builds are signed with.

**6. `scripts/send-commands.sh`**, the project's own, replacing any copy:

```sh
#!/bin/sh
# Drive the app started by `make run-scratch`: docs/commands.md. The sending
# is app-tooling's (command-inbox), in scripts/command-inbox-send.sh.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/scripts/command-inbox-send.sh" \
	--notification org.example.myapp.commands \
	--dir "$ROOT/build/scratch/Commands" \
	--process "$ROOT/build/MyApp.app/Contents/MacOS/MyApp.*--commands" \
	"$@"
```

with the directory the Makefile passes (`"$HOME/Library/Caches/MyApp-scratch/Commands"`
when sandboxed). For an iOS app, `--simulator <bundle id>` in place of
`--dir` and `--process`, or a first argument choosing between the two.

**7. `docs/commands.md`**, the project's: how to start a scratch run and
send commands, the invariant (every control performs a command through
`perform`, and how the project keeps it), what each command does, at least
one request example in a ```` ```json ```` block, and what `state` reports if
there is one. Refer to `docs/app-tooling/command-inbox/guide.md` for the
transport, the format and the inbox's own commands rather than repeating
them.

**8. The test**, in the test target of the commands' module, so the
document's examples always decode:

```swift
import CommandInbox
import Foundation
import Testing

@testable import UI

@Suite
struct CommandFileTests {
    static let documentedRequests = CommandDocumentation.requests(
        inFileAt: URL(filePath: #filePath).deletingLastPathComponent().appending(
            path: "../../../../docs/commands.md"))

    @Test
    func `the document has request examples`() { #expect(Self.documentedRequests.count == 2) }

    @Test(arguments: documentedRequests)
    func `every documented request decodes`(json: String) throws {
        _ = try JSONDecoder().decode(CommandFile<AppCommand>.self, from: Data(json.utf8))
    }

    @Test(arguments: [#"{"commands":[{"ad":{"title":"x"}}]}"#, #"{"commands":[{"add":{"name":"x"}}]}"#])
    func `typos are errors, not silently ignored`(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(CommandFile<AppCommand>.self, from: Data(json.utf8))
        }
    }
}
```

with the path from the test file to the document, the number of examples,
and a test that the first example decodes to the commands it says. A
copy's test moves over with `CommandFile` becoming `CommandFile<AppCommand>`
and its commands `.command(…)`.

**9. `AGENTS.md`**, where it says how to run the app:

> `scripts/send-commands.sh '<json>'` drives the app started by `make
> run-scratch`, with no clicks and nothing coming to the front, and prints
> what each command did; `state` reads back what the model holds.
> `docs/commands.md` has the commands. Every control performs a command
> through `perform`: add a command for a new control rather than letting
> the view change state itself.

**10. Record it** in `app-tooling.toml` (and remove any table recording a
hand-made copy):

```toml
[patterns.command-inbox]
params = { package = "Packages/MyAppKit", notification = "org.example.myapp.commands", dir = "build/scratch/Commands" }
```

## Verify

- `git status --short` shows `scripts/command-inbox-send.sh` and
  `docs/app-tooling/command-inbox/` as new, and `Package.resolved` with
  app-utils.
- The project's build and tests pass, the documented-examples test among
  them (`swift test --filter CommandFileTests` lists it, with as many cases
  as the document has examples).
- `scripts/send-commands.sh '{"commands":[]}'` with no app running exits 1
  with `✗ no process matches …`.
- On a scratch run (`make run-scratch`), a round trip: a command the app
  has, `state` if it has one, and a typo.

  ```sh
  scripts/send-commands.sh '{"id":"check","commands":[{"pause":{"seconds":0.1}},{"state":{}}]}'
  scripts/send-commands.sh '{"commands":[{"nosuch":{}}]}'
  ```

  The first prints a result with `"requestID" : "check"` and both commands
  under `completed`, and exits 0; the second prints `"error" : "could not
  read commands: … unknown command 'nosuch'…"` and exits 1. For a sandboxed
  app, no privacy prompt appears (ask whoever is at the machine, or check
  `ls ~/Library/Containers/<bundle id>` was never needed). Run this only
  once step 4's condition is in: never on the real data.
