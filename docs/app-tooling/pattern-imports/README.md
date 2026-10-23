# pattern-imports

How a project takes conventions ("patterns") from
[app-tooling](https://github.com/tikitu/app-tooling), keeps a record of
which it has, and brings them up to date. Every project that takes patterns
takes this one first. It is imported, like the others, into
`docs/app-tooling/pattern-imports/`, so this file is also the manual for an
agent working in the project.

## How it works

[peru](https://github.com/buildinspace/peru) fetches app-tooling at one
pinned commit and imports the patterns' files into the project. Three files
in the project say what it has:

- **`peru.yaml`**: where app-tooling comes from, which tag or branch the
  project follows, the exact commit it is at, and which patterns it
  imports. Written by hand, except `rev:`, which peru writes.
- **`app-tooling.toml`**: what no tool can record: parameters filled in,
  deliberate departures from a pattern, and patterns declined.
- **The imported files themselves, committed.** Scripts, make fragments and
  rules land where they are used (`scripts/`, `mk/`); each pattern's
  `README.md`, `apply.md` and `CHANGELOG.md` land in
  `docs/app-tooling/<pattern>/`. They are committed so that a fresh clone
  builds without running peru, and so that every update is a diff.

A project is at **one commit of app-tooling for all its patterns**. Choosing
which patterns to take is free; mixing versions of them is not, so patterns
never need to say which versions of each other they work with.

### peru.yaml

```yaml
imports:
    app-tooling|pattern-imports: ./
    app-tooling|pattern-imports-docs: docs/app-tooling/pattern-imports/
    app-tooling|git-commit-stamp: ./
    app-tooling|git-commit-stamp-docs: docs/app-tooling/git-commit-stamp/

git module app-tooling:
    url: https://github.com/tikitu/app-tooling
    reup: v0.1.0     # the release tag, or the branch, this project follows
    rev: 8c1f0e4…    # the exact commit it is at; written by peru

rule pattern-imports:
    export: patterns/pattern-imports/files
rule pattern-imports-docs:
    pick: [patterns/pattern-imports/README.md, patterns/pattern-imports/apply.md, patterns/pattern-imports/CHANGELOG.md]
    export: patterns/pattern-imports

rule git-commit-stamp:
    export: patterns/git-commit-stamp/files
rule git-commit-stamp-docs:
    pick: [patterns/git-commit-stamp/README.md, patterns/git-commit-stamp/apply.md, patterns/git-commit-stamp/CHANGELOG.md]
    export: patterns/git-commit-stamp
```

- **One module, two rules per pattern**: one for its files, imported at the
  project root (a pattern's `files/` is laid out as the project is), one for
  its docs. Every rule reads the same clone.
- **`reup:`** is normally a release tag. It may be a branch, while a
  pattern is being worked out. Never `main`: nothing says what a project on
  `main` has.
- **`rev:`** is the pin, and it is what `peru sync` fetches: a moved tag or
  a moved branch changes nothing until `make app-tooling-update`, and then
  shows as a change to this line. For an annotated tag it is the tag
  object's hash; `git rev-parse <rev>^{commit}` gives the commit.
- `pick` is applied before `export`, so its paths start at the repository
  root.

### app-tooling.toml

```toml
# Conventions this project takes from app-tooling, beyond what peru.yaml
# records. docs/app-tooling/pattern-imports/README.md explains this file.

[patterns.git-commit-stamp]
# What was filled in for the pattern's parameters, when it is not obvious.
params = { ios_target = "MyApp", device = "My iPhone" }
# Where this project departs from the pattern on purpose, and why.
deviations = ["Mac app keeps its date-based CFBundleVersion"]

[declined.ast-grep-rules]
as_of = "v0.1.0"
reason = "keeps its Semgrep rules until they are ported"
```

`deviations` and `[declined.*]` matter as much as what was adopted: without
them, the next agent to bring the project up to date will "fix" what was
chosen on purpose. A pattern is declined `as_of` a release (or a commit),
because it may change enough later to be worth another look.

## Make targets

`mk/app-tooling.mk` (included from the `Makefile`) provides:

| Target | Does |
|---|---|
| `app-tooling-check` | Fails, naming them, if any imported file differs from what `rev:` has: edited or deleted in this project, or an update half done. Leaves the tree as it was |
| `app-tooling-update` | Runs the check, and refuses if it fails. Otherwise moves `rev:` to the newest commit of `reup:`, imports it, and prints the `CHANGELOG.md` entries the update added: the catch-up steps |

Both need a clean tree, with one exception: `peru.yaml` may have a changed
`reup:` line, and no other change, so that moving to another release is one
edit and one update. Both need `uv` (`brew install uv`), which runs peru at
a pinned version, and take `APP_TOOLING_LOCAL` (below).

## Applying a new pattern (for an agent)

1. Read `app-tooling.toml`. If the pattern is declined there, stop and say
   so.
2. Read the pattern's `README.md` and `apply.md` at the commit the project
   is at: on GitHub at `tree/<rev>/patterns/<name>`, or in a local
   checkout of app-tooling at that commit. (If the project should move to a
   newer commit first, that is `make app-tooling-update`, done and committed
   on its own.)
3. Work through **Detect** in `apply.md`. If the project already solves the
   problem its own way, stop and describe both to the user before replacing
   anything: the project's way may be better, and then it belongs in
   app-tooling instead.
4. Add the pattern's two rules and imports to `peru.yaml` (its `apply.md`
   gives them), and run `uvx peru@1.3.5 sync`. If it reports that it
   "would overwrite preexisting files", the project has files of its own at
   those paths: that is a Detect finding, so go back to step 3.
5. Fill in the **Parameters**, and do the **Steps**.
6. Run **Verify**, and report what it showed.
7. Record parameters and deviations in `app-tooling.toml`.
8. Commit, naming the pattern and the app-tooling commit.

## Updating (for an agent)

1. `make app-tooling-update`, on a clean tree. If it refuses because
   imported files were changed here, see the next section; do not work
   around the refusal.
2. Do what each `CHANGELOG.md` entry it printed says, and run the
   **Verify** of each pattern that changed.
3. Commit the update and the catch-up together, naming the old and new
   commits.

To move to a new release, or from a branch to a release once the branch
has been released, set `reup:` to the tag, leave it uncommitted, and update
as above: `make app-tooling-update` accepts a tree whose only change is that
line, and the commit then holds the `reup:` edit, the new `rev:`, the
imports and the catch-up together.

## Local changes to imported files

Imported files are never edited in the project. Updates replace them whole,
so an edit would be lost silently; that is why `app-tooling-update` refuses
while any imported file differs from the pin, and names the files.

**There is deliberately no merge.** Upstream and the project changing the
same file is a disagreement about what the pattern should be, and it is
settled by a decision, not by merging text. When the update refuses, first
put the pinned version back (`uvx peru@1.3.5 sync --force` overwrites the
edited files with what `rev:` has), and then find the change a home. In
order of preference:

1. **Build on the imported file, without changing it.** The best answer,
   when it can be done well: the project keeps its improvement *and* every
   future improvement to the pattern. The change goes somewhere the project
   owns that uses the imported file: a target of its own that runs the
   imported one and then does more; a make variable or argument the
   imported file already takes; a small script of the project's that calls
   the imported script; a rule in the project's own rule directory beside
   the imported ones. How to do it is a judgement, case by case, and the
   test is whether it is robust and obvious to the next reader. Something
   that *rewrites* the imported file's behaviour from outside (a
   find-and-replace over a make fragment on every build, redefining its
   targets, patching a script before running it) fails that test: it is
   brittle, it breaks silently when the pattern changes, and it hides what
   actually runs. If the only way to build on the file is one of those, the
   pattern is missing a seam, which is the next option.

2. **Change app-tooling.** When the improvement is good for every project,
   make it in the pattern. When it is about this project but the pattern
   gives it nowhere to go, add that place to the pattern: a parameter, a
   hook, a target meant to be built on, so that option 1 becomes possible.
   Either way, it meets any upstream change to the same file once, in
   app-tooling, where both can be seen. Then update the project to the
   commit that has it: on a branch, if it is still being tried out.

3. **Take the file over.** The last resort, because it opts the project
   out of every future improvement to that file: only when the project
   really does need its own version and neither of the above can give it.
   In `peru.yaml`, add to the pattern's rule a `drop:` naming the file by
   its path in app-tooling (`drop` comes before `export`, so the path starts
   at the repository root):

   ```yaml
   rule git-commit-stamp:
       # Taken over by this project: see app-tooling.toml.
       drop: patterns/git-commit-stamp/files/scripts/stamp-git-commit.sh
       export: patterns/git-commit-stamp/files
   ```

   peru now treats the file as one it used to import, and wants to delete
   it: run `uvx peru@1.3.5 sync --force`, then restore the project's version
   (`git checkout <commit that has it> -- <file>`). Record it under the
   pattern's `deviations` in `app-tooling.toml`, with the reason and with
   why options 1 and 2 could not work, and commit. From then on updates
   leave the file alone. Upstream changes to it still appear in the
   pattern's `CHANGELOG.md`; whether and how to carry them over by hand is
   the project's decision, each time.

If someone wants to merge by hand, they can (the old and new versions are
in app-tooling's history), but it is not a path the tooling offers.

## Working with a local checkout of app-tooling

- **Unpushed commits:** `APP_TOOLING_LOCAL=~/code/app-tooling`, given to
  either make target, reads them from the checkout. `peru.yaml` still names
  GitHub, so push them before anyone else syncs.
- **Uncommitted changes**, while working on a pattern:
  `uvx peru@1.3.5 override add app-tooling ~/code/app-tooling`, then
  `uvx peru@1.3.5 sync`, imports straight from the working tree. The
  override lives in `.peru/`, which is git-ignored; `peru override delete
  app-tooling` ends it. Do not commit imports made this way.

## A fresh clone

`.peru/` is git-ignored, so in a fresh clone peru does not know the
committed files are its own, and a plain `peru sync` refuses to overwrite
them. Both make targets handle this (the check syncs with `--force` onto a
clean tree and reads the diff); after either, peru knows its files again.
Run a plain `peru sync` only after one of them.
