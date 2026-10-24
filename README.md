# knotwork
Playing with Celtic-inspired knotwork designs.

This starts with [@tinyknotwork](https://twitter.com/tinyknotwork), a [Tracery](http://tracery.io/) bot on [Cheap Bots Done Quick](http://cheapbotsdonequick.com/), and ends who-knows-where.

## The app

An iOS app (iPhone and iPad, iOS 26 and up) for drawing knots with your
finger, after Chaz Boston Baden's
[Knotware](http://www.boston-baden.com/hazel/Knotware3/) (his tile images,
used with permission). The screen fills with a bordered knot. Tap a point to
change it: on a segment, the break line there cycles through horizontal,
vertical and none; in the middle of a cell, the cell empties or fills. Drag
straight along a row or column to cut the knot along that line. A diagonal
drag does nothing.

The palette button shows the controls below the knot. What a drag does: cut,
as above, or clear a rectangle, which snaps to cell corners and empties the
cells inside it (the strands round it stay joined). Clear All empties every
cell; Fill All starts again with a fresh bordered knot. Then how it looks:
the tiles drawn as the original images or as one of the tilesets drawn in
code (smooth, sketch), and whether the knot's corners come to a point.
Changes show at once.

What it deliberately does not do yet: save, share or undo. The knot lives in
memory.

`Knotwork.playground` is where this began and is not part of the app.

## Build and run

Needs Xcode 26 or later with the iOS platform, and XcodeGen
(`brew install xcodegen`). There is no Interface Builder and no committed
Xcode project: SwiftPM packages hold the code, and the project is generated.

```sh
make check              # compile the shared package for macOS and iOS (fast gate)
make test               # its tests, on the Mac
make ios-run            # build, install and launch on a simulator (IOS_SIM=...)
make ios-run-commands   # the same, accepting scripted commands
make ios-screenshot     # build/simulator.png
make ios-device-run     # install on a phone (IOS_DEVICE=...)
make fmt lint           # format; then format check + ast-grep rules
make help               # everything else
```

To work in Xcode: `make ios-project`, then open `apps/ios/Knotwork.xcodeproj`.

## Shape of the repo

```
Packages/KnotworkKit/      shared: macOS and iOS, tested on the Mac
  Core            the knot: break lines, the tiles they make, and the
                  strand each tile shows
  Tilesets        the tiles drawn in code (CoreGraphics), in more than one
                  style
  TileSheets      `make tile-sheets`: every tileset beside the original
                  images, as PNGs in build/tilesets/
  UI              AppModel, AppCommand and its decoding, the knot view
Packages/KnotworkIOSKit/   iOS only: the root view and the app delegate
apps/ios/                  project.yml (XcodeGen) and the app target, a
                           forwarding shell over KnotworkIOSKit
peru.yaml  app-tooling.toml  conventions imported from app-tooling, the
mk/  docs/app-tooling/       commit they are at, and this app's choices
rules/ rule-tests/         ast-grep rules, each with its document and test
scripts/                   send-commands, and app-tooling's imported scripts
docs/                      how the app works, in depth
```

**Platforms are split by package, not by `#if`**
(`rules/platform-conditionals.md`). `KnotworkKit` declares macOS as well as
iOS, so its tests run on the Mac and a Mac app could be added beside the iOS
one.

**Dependencies are pinned.** Each package's `Package.resolved` is committed,
and every build uses exactly those versions or fails (the `Makefile` says
how). There is one: app-utils, for the command inbox.

## Documentation

- **`docs/commands.md`**: driving the app from a script, every command, and
  the inbox transport.
- **`docs/ios.md`**: the iOS app's packaging, the generated project, and
  verifying on a simulator.
- **`docs/gotchas.md`**: traps. Read before "simplifying" anything odd.
- **`rules/README.md`**: the lint rules, and what to do when one fires.
- **`AGENTS.md`**: instructions for coding agents.
