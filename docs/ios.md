# The iOS app

## Two packages and a shell

- `Packages/KnotworkKit` declares macOS and iOS and holds everything that is
  not iOS-specific: the knot (`Core`), and the model, commands and knot view
  (`UI`). Its tests run on the Mac (`make test`), and `make check` compiles
  it for iOS too.
- `Packages/KnotworkIOSKit` declares iOS only: the root view, and the app
  delegate that owns the model and starts the command inbox. Anything that
  imports UIKit goes here.
- `apps/ios/App/KnotworkApp.swift` is the whole app target: an `App` that
  forwards to `KnotworkIOS`. No logic lives there.

The package manifests are the platform boundary, so nothing needs
`#if os(iOS)` (`rules/platform-conditionals.md`). A Mac app would be a
macOS-only package beside the iOS one, on the same shared package.

## The Xcode project is generated, and git-ignored

`apps/ios/project.yml` is the source of truth. `make ios-project` runs
XcodeGen, which writes `apps/ios/Knotwork.xcodeproj` and
`apps/ios/App/Info.plist`; both are git-ignored. Edit the yaml, never them.
This keeps project-file merge conflicts out of the repo, and keeps settings
from accumulating in a file nobody reviews.

`project.yml` spells out what the packages spell out: Swift 6, strict
concurrency, and `SWIFT_DEFAULT_ACTOR_ISOLATION: nonisolated` (new Xcode
templates default to MainActor, which would silently differ from the
packages). It also sets `LM_SKIP_METADATA_EXTRACTION` (there are no App
Intents; `docs/app-tooling/build-warnings/`), and the build phase that stamps
the commit into the app (`docs/app-tooling/git-commit-stamp/`).

iPhone and iPad (`TARGETED_DEVICE_FAMILY: 1,2`), every orientation, one
window: there is one knot, owned by the app delegate.

## Make targets

| Target | Does |
|---|---|
| `ios-project` | `xcodegen generate` |
| `ios-build` | build for the simulator, unsigned, into `build/ios` |
| `ios-run` | install and launch on `IOS_SIM`, booting it without Simulator.app |
| `ios-run-commands` | the same, launched with `--accept-commands` (`docs/commands.md`) |
| `ios-screenshot` | `xcrun simctl io … screenshot build/simulator.png` |
| `ios-device-build`, `ios-device-run` | sign for real (`-allowProvisioningUpdates`) and install with `xcrun devicectl` on `IOS_DEVICE` |
| `ios-device-which` | which commit the app on the device was built from |
| `ios-clean` | delete the generated project |

## Checking touches

Commands cover what a gesture *does*; whether the gesture reaches it needs a
touch. Xcode's MCP device-interaction tools can tap and drag on a simulator
and return a screenshot and the accessibility hierarchy. The knot is one
accessibility element, "Knot", whose frame gives the grid's origin: grid
point `(x, y)` is `20·x, 20·y` points from it at full size. See
`docs/gotchas.md` for the traps.
