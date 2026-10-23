# git-commit-stamp

Every build of the app records the commit it was built from, so that "which
version is on the phone?" has an answer that is not a guess.

## The problem

An app on a phone says nothing about where it came from. `xcrun devicectl
device info apps` reports its `CFBundleVersion` and `CFBundleShortVersionString`,
and in an XcodeGen project both are fixed in `project.yml`, so every build
reports the same thing. When a bug turns up on the phone, the only way to
tell which commit it was built from is to guess from build timestamps in
DerivedData, and that guess has been wrong.

The same is true of the Mac app, less painfully, since its bundle can be
read directly.

## What it does

`scripts/stamp-git-commit.sh` writes into the *built* app's `Info.plist`,
before it is signed:

- **`AppGitCommit`**: the short SHA of `HEAD`, with `-dirty` if the working
  tree differs from it in anything git does not ignore; `no-commits` in a
  repository with nothing committed yet. Exact, but only readable from the
  bundle, so from the app itself on a phone.
- **`CFBundleVersion`**, with `--bundle-version`: `<count>.<dirty>`, the
  number of commits in `HEAD`'s history and then `1` for a dirty tree or `0`
  for a clean one (`109.0`). This is the part a phone reports, so it is the
  part `scripts/device-which-commit.sh` (`make ios-device-which`) reads back
  and turns into a commit.

On iOS it runs as a build phase declared in `project.yml`, so an install
from Xcode's Run button is stamped as well as one from `make`. On the Mac,
`build.sh` calls it.

If git cannot tell it what `HEAD` is, **the build fails** rather than
stamping `unknown`, because `unknown` read back later looks like an answer.
`STAMP_ALLOW_NO_GIT=1` allows it, for a deliberate build from an export.

## Why this shape

- **The built plist, not the source.** The source `Info.plist` is generated
  and git-ignored in these projects; stamping it would also make every build
  a change to it. Stamping the product touches nothing in the tree.
- **A build phase, not the Makefile.** Most installs to a phone come from
  Xcode's Run button, which never runs `make`.
- **`<count>.<dirty>`, not a bare count.** A build from before the stamp
  has a hand-set `CFBundleVersion` of `1`, which would read as "built from
  the first commit". The dot makes a stamped version recognisable, and the
  second part says whether uncommitted changes went in. App Store Connect
  accepts it: up to three dot-separated integers, compared part by part, and
  the count only rises along a branch. (A pattern for TestFlight will build
  on this.)
- **The count is resolved against first parents.** Counting is what makes
  the number readable on the phone, but two branches can reach the same
  count. `device-which-commit.sh` looks along `HEAD`'s first-parent history,
  which is right for a build from the current branch or from one it has
  merged, and says so when the count is not there. `AppGitCommit`, shown by
  the app, is the exact answer. A branch that was squash-merged or rebased
  is not "merged" in this sense: its commits, and their counts, are gone
  from history, so a build made from it maps to whatever commit now has
  its count. Builds that matter come from the main line (the `testflight`
  pattern only uploads from there), where this does not arise.

## What it asks of a project

- A git checkout at build time (always true for these apps).
- For iOS: an XcodeGen `project.yml`, as in the starter's
  [`docs/ios.md`](https://github.com/tikitu/app-tooling/blob/main/starter/docs/ios.md).
- For the Mac: a `build.sh` that assembles the bundle, as the starter's
  does.

It does not show the commit in the app. `apply.md` suggests how, but where
it belongs (a settings screen, the About panel, a debug menu) is the app's
choice.

## Files

Imported by peru, never edited in a project:

| File | Imported as |
|---|---|
| `files/scripts/stamp-git-commit.sh` | `scripts/stamp-git-commit.sh` |
| `files/scripts/device-which-commit.sh` | `scripts/device-which-commit.sh` (used only with an iOS app) |

Requires the `pattern-imports` pattern. `apply.md` has the steps;
`CHANGELOG.md` what changed between releases.
