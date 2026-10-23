# Applying pattern-imports

Read [`README.md`](README.md) first: this pattern is the machinery the
others are applied with.

## Detect

- **Already adopted:** `peru.yaml` has a `git module app-tooling`, and
  `mk/app-tooling.mk` exists. Nothing to do.
- **A `CLAUDE.md`** (with or without an `AGENTS.md` pointing at it): the
  project's instructions belong in `AGENTS.md` alone. Claude Code reads
  `AGENTS.md` only when there is no `CLAUDE.md`, and every other agent tool
  reads `AGENTS.md`. Step 5 moves them.
- **Other uses of peru:** a `peru.yaml` without an app-tooling module. Add
  to it rather than beside it.
- **Files copied from app-tooling by hand:** scripts, rules or docs whose
  header names an app-tooling pattern. Each is a pattern to bring in
  through peru once this one is done, and `peru sync` will refuse to
  overwrite them until then; `diff` them against the pattern's `files/`
  first, since a difference is either a local change that belongs in
  app-tooling or an old copy.

## Parameters

| Parameter | Where to find it |
|---|---|
| The release or branch to follow | the latest release, unless the user says otherwise |

## Steps

**1. `peru.yaml`** at the repository root:

```yaml
# Conventions taken from app-tooling; see
# docs/app-tooling/pattern-imports/README.md.
imports:
    app-tooling|pattern-imports: ./
    app-tooling|pattern-imports-docs: docs/app-tooling/pattern-imports/

git module app-tooling:
    url: https://github.com/tikitu/app-tooling
    reup: vX.Y.Z

rule pattern-imports:
    export: patterns/pattern-imports/files
rule pattern-imports-docs:
    pick: [patterns/pattern-imports/README.md, patterns/pattern-imports/apply.md, patterns/pattern-imports/CHANGELOG.md]
    export: patterns/pattern-imports
```

Then `uvx peru@1.3.5 reup`, which writes `rev:` and imports
`mk/app-tooling.mk` and the docs.

**2. `.gitignore`**:

```
# peru's cache and state. peru.yaml, and the files it imports, are committed.
.peru/
```

**3. The Makefile**: `include mk/app-tooling.mk`, near the top, after the
variables; add `app-tooling-update` and `app-tooling-check` to `help` in the
project's style.

**4. `app-tooling.toml`** at the repository root, with the header comment
from `README.md` and nothing else yet; each pattern adds its entry.

**5. `AGENTS.md`**. If the project has a `CLAUDE.md`, first move its
content into `AGENTS.md` (replacing any pointer there), delete `CLAUDE.md`,
and change references to it in the project's docs; history, such as a
progress log, stays as it was. Then add a section:

```markdown
## Conventions from app-tooling

Some of this project's tooling is imported from app-tooling by peru:
`peru.yaml` says what, and at which commit. **Never edit an imported file
in place**; the change belongs in app-tooling. How to apply a new pattern,
update, or work against a local checkout is in
`docs/app-tooling/pattern-imports/README.md`. `app-tooling.toml` records
this project's parameters, deliberate deviations and declined patterns;
read it before changing anything a pattern covers.
```

## Verify

- `git status --short` shows `peru.yaml`, `mk/app-tooling.mk` and
  `docs/app-tooling/pattern-imports/` as new, and `.peru/` absent (ignored).
- `grep rev: peru.yaml` shows a 40-character hash.
- After committing: `make app-tooling-check` prints
  `✓ app-tooling imports match peru.yaml`.
- `make help` lists the two targets.
