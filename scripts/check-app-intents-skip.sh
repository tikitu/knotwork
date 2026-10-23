#!/bin/sh
#
# check-app-intents-skip.sh — fail while the project both skips Xcode's App
# Intents metadata step and has App Intents code.
#
# Imported by peru from the app-tooling pattern `build-warnings`
# (https://github.com/tikitu/app-tooling). Never edit it here: `peru sync`
# refuses to overwrite a changed copy, and the change belongs in app-tooling.
# docs/app-tooling/build-warnings/ says what it is for.
#
# Usage: scripts/check-app-intents-skip.sh
#
# Reads the project this script was imported into (the directory above
# scripts/), not the whole git repository, which may hold more than one.
#
# LM_SKIP_METADATA_EXTRACTION=YES removes Xcode's "Metadata extraction
# skipped" warning by not running the step at all. On a target with App
# Intents it would drop their metadata without any error, and the intents
# would vanish from Shortcuts and Siri. So: if any file outside Markdown and
# this pattern's own files mentions LM_SKIP_METADATA_EXTRACTION, no Swift
# file may mention the AppIntents module or its main protocols. A mention in
# a comment counts, on purpose. Untracked files count; ignored ones (build
# output, checkouts) do not.
#
# Per target: when every mention of the setting itself is the indirection
#   LM_SKIP_METADATA_EXTRACTION = $(LM_SKIP_METADATA_EXTRACTION_$(TARGET_NAME:c99extidentifier))
# the skip reaches only the targets named by LM_SKIP_METADATA_EXTRACTION_<Target>,
# and check-app-intents-skip-targets.py checks only what those targets compile,
# their packages' sources included.
#
# Prints `ok` as its last line when the project passes; anything else is a
# failure, with a non-zero exit. mk/build-warnings.mk relies on the `ok`.

set -u

cd "$(dirname "$0")/.." || exit 2
git rev-parse --is-inside-work-tree >/dev/null || { echo "✗ check-app-intents-skip: not in a git repository"; exit 2; }

# git grep exits 1 for "no match"; anything above that is a failure, which
# must not read as "nothing found".
grep_or_fail() {
  out=$(git grep --untracked -I "$@")
  status=$?
  if [ "$status" -gt 1 ]; then
    echo "✗ check-app-intents-skip: git grep failed ($status)"
    exit 2
  fi
  printf '%s' "$out"
}

# This pattern's own files, wherever they are: a project may hold another
# that imports them too (in a subdirectory), and a case-insensitive disk may
# have put them in Scripts/.
skips=$(grep_or_fail -l -e LM_SKIP_METADATA_EXTRACTION -- . \
  ':(exclude)*.md' ':(exclude,glob)**/docs/app-tooling/**' \
  ':(exclude,glob,icase)**/mk/build-warnings.mk' \
  ':(exclude,glob,icase)**/scripts/check-app-intents-skip.sh' \
  ':(exclude,glob,icase)**/scripts/check-app-intents-skip-targets.py') || exit $?

if [ -z "$skips" ]; then
  echo "ok"
  exit 0
fi

pattern='AppIntents|AppIntent|AppShortcutsProvider|AppEntity|AppEnum'
intents=$(grep_or_fail -n -w -E "$pattern" -- '*.swift') || exit $?

if [ -z "$intents" ]; then
  echo "ok"
  exit 0
fi

# Per target, if no mention of the setting is anything but the indirection.
indirection='$(LM_SKIP_METADATA_EXTRACTION_$(TARGET_NAME:c99extidentifier))'
mentions=$(printf '%s\n' "$skips" | while IFS= read -r f; do
  grep -n -E 'LM_SKIP_METADATA_EXTRACTION([^_A-Za-z0-9]|$)' "$f" | sed "s|^|$f:|"
done)
if [ -n "$mentions" ] && ! printf '%s\n' "$mentions" | grep -q -v -F "$indirection"; then
  targets=$(printf '%s\n' "$skips" | while IFS= read -r f; do
    grep -o -E 'LM_SKIP_METADATA_EXTRACTION_[A-Za-z0-9_]+' "$f"
  done | sed 's/^LM_SKIP_METADATA_EXTRACTION_//' | sort -u)
  if [ -z "$targets" ]; then
    echo "ok"
    exit 0
  fi
  # shellcheck disable=SC2086 # target names are words
  out=$(python3 scripts/check-app-intents-skip-targets.py "$pattern" $targets)
  status=$?
  if [ "$status" -eq 0 ]; then
    echo "ok"
    exit 0
  fi
  if [ "$status" -gt 1 ]; then
    printf '%s\n' "$out"
    exit 2
  fi
  echo "✗ LM_SKIP_METADATA_EXTRACTION is set on targets that compile App Intents code."
  echo "  The skip would drop the intents' metadata. Remove those targets'"
  echo "  LM_SKIP_METADATA_EXTRACTION_<Target> from:"
  printf '%s\n' "$skips" | sed 's/^/    /'
  echo "  App Intents code, by skipped target:"
  printf '%s\n' "$out" | head -10 | sed 's/^/    /'
  echo "  docs/app-tooling/build-warnings/README.md has why."
  exit 1
fi

echo "✗ LM_SKIP_METADATA_EXTRACTION is set, but this project has App Intents code."
echo "  The skip would drop the intents' metadata. Remove it from:"
printf '%s\n' "$skips" | sed 's/^/    /'
echo "  App Intents code:"
printf '%s\n' "$intents" | head -10 | sed 's/^/    /'
echo "  docs/app-tooling/build-warnings/README.md has why."
exit 1
