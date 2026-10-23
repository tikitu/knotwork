# build-warnings changelog

## v0.5.1 (2026-10-22)

**The App Intents skip can be set per target.** A project with App Intents
in some targets can skip Xcode's metadata step on the others (an
extension, a test bundle) through
`$(LM_SKIP_METADATA_EXTRACTION_$(TARGET_NAME:c99extidentifier))` and one
`LM_SKIP_METADATA_EXTRACTION_<Target> = YES` per target (README, "Per
target"). The check then fails `make` when a named target compiles App
Intents code, its local packages' sources included, using the new
`scripts/check-app-intents-skip-targets.py` (needs `python3`). A project
that sets the skip in any other form keeps the whole-project check. Nothing
to do beyond taking the update; a project with App Intents that still
prints `Metadata extraction skipped` may now follow `apply.md` step 4.

**The check no longer counts this pattern's own files as the skip.** It
left out `mk/build-warnings.mk` and `scripts/check-app-intents-skip.sh`
only at those exact paths, so a project holding a second project that
imports the pattern (a subdirectory with its own Makefile), or whose
`scripts/` directory is spelled `Scripts/`, read the pattern's own files
as `LM_SKIP_METADATA_EXTRACTION` being set: once such a project had any
App Intents code, `make` would stop for a skip that was not there. The
check now leaves the pattern's files out wherever they are, in any case.
Nothing to do beyond taking the update.

## v0.5.0 (2026-10-21)

First version. `mk/build-warnings.mk` exports `OMIT_DYNAMIC_TEST_SUPPORT=1`,
which removes swift-issue-reporting's `IssueReportingTestSupport` `ld`
warnings, and on every `make` run calls `scripts/check-app-intents-skip.sh`,
which stops the run while `LM_SKIP_METADATA_EXTRACTION` (the setting that
skips Xcode's App Intents metadata step) and App Intents code are both in
the project. To adopt: follow `apply.md`. It may need a pin bump to
xctest-dynamic-overlay ≥ 1.11.0, and adds the setting only in projects with
no App Intents. Tried on throwaway clones of four existing apps: two
with an xcodegen iOS app, package-scheme tests and swift-issue-reporting
2.x (both parts, and the probe intent that stops `make`), one on
xctest-dynamic-overlay 1.8.0 (the bump to 1.11.0 and the `severity`
parameter), and one whose App Intents live in a package (the check refuses
the skip there).
