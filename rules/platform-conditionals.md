# Platforms are split by package, not by `#if`

**Rule:** `platform-conditionals`, in `rules/platform-conditionals.yml`, tested by
`rule-tests/platform-conditionals-test.yml`

## The rule

No `#if os(…)`, `#if canImport(…)` or `#if targetEnvironment(…)` in the
packages. Code for one platform lives in that platform's package:

- `Packages/KnotworkKit` declares macOS and iOS, and holds everything that is
  not specific to one of them. `make check` compiles it for both, so an
  iOS-only API there is a build error.
- `Packages/KnotworkIOSKit` declares iOS only, and holds the iOS app's
  iOS-only code. A Mac app would get its own macOS-only package beside it.

`#if DEBUG` and other conditions that are not about the platform are not
affected.

## Why it fails silently

A platform `#if` compiles on the platform you are building, and says nothing
about the other branch, which nobody is building. Each guard looks harmless;
together they turn the shared code into two programs interleaved, where the
one not currently built rots unseen until someone builds it.

They also fight the tools. `swift format` moves a `#if` that sits between
view modifiers onto the end of the previous line, which does not compile
(`docs/gotchas.md`). And unless `indentConditionalCompilationBlocks` is off
(it is, in `.swift-format`), wrapping a block in a new `#if` reindents every
line inside it, so a one-line change arrives as a diff of hundreds.

The package boundary does the same job at compile time, for free: code in
the iOS package cannot be imported by the shared one, and code in the shared
one has to compile for every platform it declares.

## What to do instead

Move the code to the package for its platform. If shared code needs
something only one platform can provide, give the shared code a protocol or
a dependency (`@Dependency`) and have each platform's package supply the
implementation.

## When a finding is not a bug

A dependency's API that genuinely differs by platform, with no sensible
split — rare. Say why in a comment and suppress with
`// ast-grep-ignore: platform-conditionals`.

## What would break the rule

It matches `#if` and `#elseif` directives (so not comments) whose text
mentions `os(`, `canImport(` or `targetEnvironment(`. A condition built from
a custom compilation flag set per platform slips past; widen the rule if one
appears.

## Known exceptions

None yet.

## Tested by

`#if os(macOS)`, `#elseif canImport(UIKit)` and `#if targetEnvironment(simulator)` are flagged; `#if DEBUG` and a comment mentioning `#if os(macOS)` are not.
