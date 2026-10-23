# Applying build-warnings

Read [`README.md`](README.md) first for what this does and why.

## Detect

- **Already adopted:** `peru.yaml` imports `app-tooling|build-warnings`,
  and the `Makefile` has `include mk/build-warnings.mk`.
- **Something else doing this job.** Look for:
  - `OMIT_DYNAMIC_TEST_SUPPORT` anywhere (`Makefile`, `mise.toml`, CI
    configuration, an `.envrc`);
  - `LM_SKIP_METADATA_EXTRACTION` or `LM_FILTER_WARNINGS` in `project.yml`,
    `Project.swift`, an `.xcconfig`, the `Makefile` or `mise.toml`;
  - linker flags or log filtering that hide warnings: `-w`,
    `-Xlinker -w`, `-suppress-warnings`, a `grep -v warning` after a build.

  `OMIT_DYNAMIC_TEST_SUPPORT` set elsewhere is replaced by the fragment's.
  An existing `LM_SKIP_METADATA_EXTRACTION` stays, and the check now guards
  it. Hiding warnings is what this pattern replaces: show the user what the
  project does and ask before removing it.
- **Not adopted:** test builds print the `IssueReportingTestSupport` `ld`
  warnings, and xcodebuilds print `Metadata extraction skipped`.

## Parameters

| Parameter | Where to find it |
|---|---|
| Does it use swift-issue-reporting? | `swift-issue-reporting` or `xctest-dynamic-overlay` in any `Package.resolved` |
| Its version | the same pin. Below xctest-dynamic-overlay 1.11.0 needs a bump (step 2) |
| Does it have App Intents? | `git grep -n -w -E 'AppIntents\|AppIntent\|AppShortcutsProvider\|AppEntity\|AppEnum' -- '*.swift'`. Any output: step 4 per target only |
| Where xcodebuild runs | the `Makefile`'s recipes that call `xcodebuild`, and which `-scheme` each builds: an app scheme from `project.yml`, or a package's `<Name>-Package` scheme |

## Steps

The project must already have `pattern-imports`.

**1. Import the pattern.** In `peru.yaml`, under `imports:`:

```yaml
    app-tooling|build-warnings: ./
    app-tooling|build-warnings-docs: docs/app-tooling/build-warnings/
```

and beside the other rules:

```yaml
rule build-warnings:
    export: patterns/build-warnings/files
rule build-warnings-docs:
    pick: [patterns/build-warnings/README.md, patterns/build-warnings/apply.md, patterns/build-warnings/CHANGELOG.md]
    export: patterns/build-warnings
```

Then `uvx peru@1.3.5 sync`, which puts `mk/build-warnings.mk` and
`scripts/check-app-intents-skip.sh` in place. In the `Makefile`, near the
other includes:

```make
# Two dependency and Xcode warnings removed at their cause; refuses to run
# while the App Intents skip and App Intents code are both in the project
# (app-tooling: build-warnings). docs/app-tooling/build-warnings/.
include mk/build-warnings.mk
```

**2. Pins, if needed.** If the project pins xctest-dynamic-overlay below
1.11.0, move it to exactly 1.11.0: a deliberate change, in a commit of its
own. In that package:

```sh
swift package resolve --force-resolved-versions   # first, or the next line cannot find it
swift package resolve xctest-dynamic-overlay --version 1.11.0
```

then whatever copies its lockfile elsewhere. Check that no other pin
moved. Not `swift package update`: that takes it to 1.13.x, a shim over
swift-issue-reporting 2.x, whose `IssueReporter` protocol changed, so a
project with its own reporter stops compiling. Moving to 2.x is a separate
decision. Already on swift-issue-reporting 2.x: nothing to do.

1.11.0 deprecates `IssueReporter`'s `reportIssue` without a severity, so a
reporter of the project's own (`git grep -n ': *IssueReporter\b'`) now
warns "deprecated default implementation is used". Add the parameter
`severity: IssueSeverity` after the message, in the same commit as the
bump.

**3. Nothing more for part 1.** Every recipe now runs with
`OMIT_DYNAMIC_TEST_SUPPORT=1`.

**4. Part 2.** In a project with no App Intents, add the setting
where each xcodebuild that prints the warning gets its settings:

- **An app from `project.yml`:** in the project-wide `settings: base:`, so
  that it reaches every target, test bundles included:

  ```yaml
      # Xcode's App Intents step only warns here: there are none
      # (app-tooling: build-warnings, which fails `make` if one is added).
      LM_SKIP_METADATA_EXTRACTION: YES
  ```

  For a Tuist `Project.swift`, the same key in the project's base
  settings. Regenerate the project.
- **A package scheme** (`-scheme <Name>-Package`, which has no settings of
  its own): append `LM_SKIP_METADATA_EXTRACTION=YES` to that `xcodebuild`
  command line, written out literally, so that the check can find it.

In a project with App Intents, skip only the targets that print the
warning, by name (the README's "Per target"). Find them in a build log: the
`ExtractAppIntentsMetadata (in target '…')` line just above each
`Metadata extraction skipped`. Wherever the targets get their settings
(the spec's project-wide settings, or each package-scheme `xcodebuild`
command line, quoted so the shell leaves `$(…)` alone):

```sh
'LM_SKIP_METADATA_EXTRACTION=$(LM_SKIP_METADATA_EXTRACTION_$(TARGET_NAME:c99extidentifier))' \
LM_SKIP_METADATA_EXTRACTION_ShareExtension=YES \
LM_SKIP_METADATA_EXTRACTION_MyFeatureTests=YES
```

A package test bundle shows as `MyFeatureTests-product`; its name here is
`MyFeatureTests`. Then compare the `ExtractAppIntentsMetadata` lines of a
clean build with and without: only the named targets' lines may be gone.

**5. A project not driven by make** (mise, say) cannot include the
fragment. Set `OMIT_DYNAMIC_TEST_SUPPORT = "1"` in `mise.toml`'s `[env]`,
and run `scripts/check-app-intents-skip.sh` first in the task every
verification goes through (as a dependency of `build`, for instance), so
that it runs as often as the fragment's check would.

**6. Record it** in `app-tooling.toml`:

```toml
[patterns.build-warnings]
```

## Verify

Builds from clean (a fresh clone, or the project's `make clean`), so that
nothing is reused from before:

- `make test` (or the target that runs `swift test`) prints no
  `IssueReportingTestSupport-product: ld: warning`, and the tests pass.
  `grep -c "ld: warning" <log>` is `0`; check the log is the build's, of
  some size, before reading a `0` as an answer.
- Every xcodebuild target the project has (`make ios-build`,
  `make ios-test` and the like) prints neither that warning nor
  `Metadata extraction skipped` (`grep -c "warning:" <log>` is `0`). The
  processor may still appear in the log for a package's library targets,
  which project settings do not reach; it does not warn for those.
- **`reportIssue` still fails a test.** Add, for the length of the check
  only, to a test target that links `IssueReportingTestSupport` (one that
  depends on `DependenciesTestSupport` does):

  ```swift
  import IssueReporting
  import Testing

  @Test func reportIssueReachesSwiftTesting() {
    withKnownIssue { reportIssue("probe") }
  }
  ```

  It must pass "with 1 known issue". (`withKnownIssue` fails when no issue
  is recorded, so this passing proves the issue arrived.) Delete it.
- **The check fails when an intent arrives** (part 2 only). Add, without
  committing:

  ```swift
  import AppIntents

  struct ProbeIntent: AppIntent {
    static let title: LocalizedStringResource = "Probe"
    func perform() async throws -> some IntentResult { .result() }
  }
  ```

  anywhere among the project's Swift files, untracked. `make help` (or any
  target) must now exit non-zero, naming the file with the setting and the
  probe's lines. Delete the probe; `make help` works again. Per target: put
  the probe in each skipped target's sources, and in a package target it
  links, and `make help` must fail each time; in a target that keeps the
  step, it must not.
