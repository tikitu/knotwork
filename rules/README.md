# Rules that carry their own reasoning

A lint rule knows *that* something is disallowed. It cannot tell you
*whether this instance is the case the rule was written for*. So every rule
here is a pair, side by side:

```
rules/url-path.yml    the ast-grep check
rules/url-path.md     why it exists, and what to do when it fires
```

and a test, `rule-tests/url-path-test.yml`, with code the rule must flag and
code it must leave alone.

Neither half is optional. A rule without a document becomes cargo cult: the
next person to trip it has to guess whether it matters, and usually guesses
wrong in one direction or the other. A document without a rule does not get
read.

```sh
make rules        # ast-grep test, then ast-grep scan
make lint         # fmt-check + rules — the whole non-compiling gate
```

Rules here are for mistakes that fail **silently** — the code runs, reports
success, and is wrong — or that keep coming back. A mistake the compiler or a
glance at the screen would catch does not need one.

## When a rule fires

**Read the rule's `.md` first.** It exists to tell you which of these is
right; each of them is, sometimes:

1. **Fix the code.** The default. The rule caught what it was written for.
2. **Allow an exception.** Suppress it on the line before with
   `// ast-grep-ignore: <rule-id>` and a comment saying why, **and** add the
   case under "Known exceptions" in the rule's `.md`. For a whole file or
   directory, add it to `ignores:` in the `.yml` instead, so the exception is
   visible in one place. An unexplained suppression is a silent repeal.
3. **Improve the rule.** If it fired on something no reasonable reading of
   its document covers, the pattern is wrong. Tighten it, and add the case to
   its test as `valid`, rather than accumulating suppressions.
4. **Retire the rule.** If the document no longer describes the project,
   delete the rule, its document and its test, and say why in the commit.
   Rules are not sacred.

Never suppress a rule without touching its document.

## Writing a rule

**Write the document first.** If you cannot say in a paragraph what goes
wrong without the rule, you have a preference, not a rule.

The document says:

- **The rule**, in one or two sentences.
- **Why it fails silently**: the concrete failure, in terms of *this* app.
  "Untestable" is weak; "the database open threw inside `withErrorReporting`,
  so the app launched, drew its window and showed an empty list" is strong.
- **What it cost**, if anything yet.
- **What to do instead.**
- **When a finding is not a bug.**
- **Known exceptions**: starts as "None yet", and grows.
- **What would break the rule**: the shapes of the mistake the pattern misses.

The `.yml` follows ast-grep's rule schema. Its `message` says what is wrong;
its `note` says what to do and **ends by pointing at the `.md`** — that line
is often all the person seeing the failure reads. Quote any value containing
`: `, or the YAML will not parse (ast-grep says so, loudly).

## Testing a rule

Every rule has a test in `rule-tests/`: `invalid` snippets it must flag, and
`valid` ones it must not — including the near misses that motivated any
`not:` clause. `make rules` runs the tests before the scan.

A rule that has never been seen to fire probably matches nothing: pattern
syntax is easy to get subtly wrong, and a check that silently matches
nothing is worse than none, because it looks like coverage. The tests are
what make that visible. When a rule comes from a real bug, make the buggy
code (from `git show <sha>~1:<path>`) one of its `invalid` cases.

Exploring a pattern: `ast-grep run -l swift -p '<pattern>' <file>`, and
`--debug-query=cst` to see how the Swift parser sees the code.

## The rules

| Rule | Invariant |
|---|---|
| [platform-conditionals](platform-conditionals.md) | Platform code is split by package, never by `#if os(…)` |
| [url-path](url-path.md) | Filesystem paths come from `path(percentEncoded: false)`, never `path()` |
