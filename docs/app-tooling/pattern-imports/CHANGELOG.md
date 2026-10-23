# pattern-imports changelog

## v0.2.0 (2026-10-20)

**Every project with Swift packages, starter or not: Xcode 27.** On
Xcode 27 (Swift 6.4) the Point-Free packages depend on
`swift-issue-reporting`, the new name of `xctest-dynamic-overlay`, and a
`Package.resolved` that still pins the old name fails to build with "an
out-of-date resolved file … dependencies were added:
'swift-issue-reporting'". Check each `Package.resolved` for
`xctest-dynamic-overlay`, then:

- If no `Package.swift` names `xctest-dynamic-overlay` (the package comes
  only through other dependencies), run `swift package resolve` in each
  package directory that has a `Package.resolved`. It adds the missing pin
  (at the newest version the other packages allow), drops the stale one,
  and leaves every other pin where it was. Do not use
  `swift package update`, which moves them all. Check with
  `git diff -- '*Package.resolved'` that the only changes are that swap and
  the `originHash` line, and build.
- If a `Package.swift` names it, change the dependency's URL to
  `https://github.com/pointfreeco/swift-issue-reporting`, `from: "2.1.0"`,
  and `package: "swift-issue-reporting"` on any `IssueReporting` product,
  then resolve as above.

An Xcode project's own `Package.resolved` (inside the `.xcodeproj` or
`.xcworkspace`) is resolved by opening it in Xcode 27, or with
`xcodebuild -resolvePackageDependencies`; that route has not been tried
yet, so check the diff the same way.

`make app-tooling-update` (and `app-tooling-check`) accept a tree whose
only change is to `reup:` in `peru.yaml`, so moving to a new release is:
set `reup:`, run the update, commit everything together. Before, the
update refused the edited `peru.yaml`, and the `reup:` change had to be
committed on its own first. Any other change to `peru.yaml` is still
refused, and so is any edited import. Nothing to do beyond taking the
update; the README's "Updating" section has the new steps.

## v0.1.0 (2026-10-05)

Agent instructions live in `AGENTS.md` only. A project that has a
`CLAUDE.md` moves its content into `AGENTS.md` and deletes it (`apply.md`,
step 5), since Claude Code reads `AGENTS.md` only when there is no
`CLAUDE.md`.

First version: `peru.yaml` pins app-tooling at one commit and imports each
pattern's files and docs; `mk/app-tooling.mk` provides `app-tooling-update`
and `app-tooling-check`. The update refuses while an imported file has been
changed in the project; the README says what to do instead (build on the
file without changing it; else change app-tooling; taking the file over is
the last resort), and there is deliberately no merge. Tried on a scratch clone of an existing iOS app,
including a tag moved upstream, a local edit to an imported file, a fresh
clone, and reading unpushed commits from a local checkout.
