# Traps

Things that failed in ways that looked like something else. Read before
"simplifying" anything odd, and add to it.

## The first size a view reports can be zero

`onGeometryChange` calls its action with the view's first size, and that can
be zero before layout settles. The knot is made from the space available, so
making it then gave a knot of one cell. `KnotView` waits for a size of at
least one cell each way.

## `Bundle.module` finds resources in the build folder

SwiftPM's generated `Bundle.module` looks in the app bundle, then falls back
to the absolute path of the build folder it was compiled in, so on the
machine that built it a resource bundle missing from the app still loads.
The tile images are in `KnotworkKit_UI.bundle` inside `Knotwork.app`; check
it is there (`ls …/Knotwork.app`) before trusting a simulator run.

## The tile images are read with ImageIO, not an asset catalog

`swift build` cannot compile an asset catalog, so the GIFs are copied into
the resource bundle as they are (`resources: [.copy("Resources/Tiles")]`)
and decoded with ImageIO, which is the same on every platform. `UIImage(named:)`
would need UIKit and an `#if`.

## Simulators are chosen by name, and names repeat

Every runtime has its own "iPhone 17", other projects rename theirs, and
`xcodebuild -destination name=…` (which means the newest runtime) and
`xcrun simctl … '<name>'` each choose by their own rules: a destination that
built yesterday can fail today with "Unable to find a device matching the
provided destination specifier". So the Makefile resolves `IOS_SIM` once,
with `scripts/simulator-udid.py`, to the simulator of that name on the
newest runtime, and uses the UDID everywhere. If it says there is no such
simulator, it lists the names there are: set `IOS_SIM` to one.

Xcode's device-interaction tools list only some simulators, and given a
model name may choose one that belongs to another project. Pass a UDID, and
check `xcrun simctl list devices | grep Booted` before believing a
screenshot is of this app.

## Xcode's device-interaction drag is `drag`

`drag x1 y1 x2 y2` works; `s …` is rejected as an invalid command, and a
`swipe` attempt was followed by the session disappearing. Taps are
`t x y`.

## `log` is shadowed in zsh

`log show …` prints nothing and exits 0 in zsh, where `log` is a builtin.
Always `/usr/bin/log`. The app logs under subsystem `org.logophile.Knotwork`.

## `swift format` breaks a `#if` between view modifiers, and mangles scripts

It moves a `#if` onto the end of the previous line, which does not compile,
so `make check` after `make fmt`. And it folds a `#!/usr/bin/env swift`
shebang together with the comments beneath it, so `scripts/` is not
formatted.

## `xcodebuild` prints "Supported platforms for the buildables in the current scheme is empty"

On every build of a package scheme or the generated project. It is
xcodebuild's own log line, not a build warning, and the build is fine:
check the products rather than the line.
