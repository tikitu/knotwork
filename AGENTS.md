# Agent instructions

`README.md` has what the app is, the shape of the repo and the everyday
commands. `docs/` has the depth.

## Verifying

* **Verify by running, not by compiling.** Launch the app on a simulator and
  look at it. Say plainly which parts were not verified.

* **Verify without taking focus.** Someone may be using the machine while
  you work. `make ios-run-commands` boots the simulator without opening
  Simulator.app; `scripts/send-commands.sh` drives the app and
  `make ios-screenshot` captures it. Touches can be checked with Xcode's
  device-interaction tools (`docs/ios.md` has the traps).

* `scripts/send-commands.sh '<json>'` drives the app started by `make
  ios-run-commands`, with no touches and nothing coming to the front, and
  prints what each command did. `docs/commands.md` has the commands, and
  why the sender reaches only the *booted* simulator.

* **Every gesture performs an `AppCommand` through `AppModel.perform(_:)`.** A
  control that does the work itself is a path no script can reach. Adding one
  means adding its command, its row in `docs/commands.md`, and its case in
  the decoder.

* **Which build is this?** `make ios-device-which` says which commit the app
  on the phone was built from; for a simulator build,
  `plutil -extract AppGitCommit raw build/ios/Build/Products/Debug-iphonesimulator/Knotwork.app/Info.plist`.
  `-dirty` means uncommitted changes.

* Read `docs/gotchas.md` before touching layout or anything that looks
  needlessly odd. When you find a new trap, add it.

* **The Xcode project is generated.** Edit `apps/ios/project.yml`, never the
  `.xcodeproj` (git-ignored), and keep the app target a forwarding shell:
  logic goes in the packages.

## Conventions from app-tooling

Some of this project's tooling is imported from app-tooling by peru:
`peru.yaml` says what, and at which commit. **Never edit an imported file
in place**; the change belongs in app-tooling. How to apply a new pattern,
update, or work against a local checkout is in
`docs/app-tooling/pattern-imports/README.md`. `app-tooling.toml` records
this project's parameters, deliberate deviations and declined patterns;
read it before changing anything a pattern covers.

## Swift

* **Platform code goes in its platform's package, never behind `#if os(…)`.**
  `Packages/KnotworkKit` is shared and must compile for macOS as well as iOS
  (`make check` does both); iOS-only code goes in `Packages/KnotworkIOSKit`.
  The reasons are in `rules/platform-conditionals.md`.

* Default actor isolation is **nonisolated in every target**, UI included,
  and in the app target (`project.yml`). Mark `@MainActor` explicitly where
  it is needed.

* One dependency, app-utils (for the command inbox), pinned `exact:` in both
  packages. Pin any other: commit `Package.resolved` and build with the
  pinned versions (the `Makefile` says how).

* **Filenames with spaces are this repo's style**: `Knot view.swift`,
  `Root view.swift`. Preserve them.

* Before and after deciding on SwiftUI code, use the `swiftui-pro` skill, and
  run a SwiftFairy audit on new and changed views. Keep things simple.

## Lint

* Formatting is the formatter's job. Run `make fmt` after writing Swift and do
  not hand-tune line breaks: `.swift-format` has
  `respectsExistingLineBreaks: false`, so there is one canonical form. Run
  `make check` after `make fmt` (see `docs/gotchas.md`).

* Run `make lint` (format check + ast-grep rules) before concluding work is
  finished. **When a rule fires, read its `.md` in `rules/` before doing
  anything else.** Never suppress a rule without recording why in its
  document.

* **When a mistake recurs, or fails silently, make it a rule**: a check, the
  document that explains it (written first), and a test that shows it firing.
  `rules/README.md` has the convention.
