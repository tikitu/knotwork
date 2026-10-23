#!/usr/bin/env bash
#
# stamp-git-commit.sh — record in a built app which commit it was built from.
#
# Imported by peru from the app-tooling pattern `git-commit-stamp`
# (https://github.com/tikitu/app-tooling). Never edit it here: `peru sync`
# refuses to overwrite a changed copy, and the change belongs in app-tooling.
# docs/app-tooling/git-commit-stamp/ says what it is for.
#
# Usage:
#   scripts/stamp-git-commit.sh [--bundle-version] <Info.plist>
#
# Sets `AppGitCommit` in the plist to the short SHA of HEAD, with `-dirty`
# appended when the working tree differs from HEAD (tracked changes or
# untracked files that are not ignored, since SwiftPM compiles untracked
# sources too); `no-commits` in a repository with nothing committed yet.
# Outside a git repository, or if git fails, the build fails: a stamp of
# "unknown" would later read as an answer. To build from an export with no
# .git on purpose, set STAMP_ALLOW_NO_GIT=1 and it writes `unknown`.
#
# --bundle-version also sets `CFBundleVersion` to `<count>.<dirty>`: the
# number of commits in HEAD's history, which rises along a branch, then 1 if
# the tree was dirty and 0 if not. It is there because it is the only one of
# the two that can be read back from a phone: `xcrun devicectl device info
# apps` reports CFBundleVersion and not custom keys. The dot is what makes it
# recognisable: a build from before the stamp has a hand-set `1`, which
# would otherwise read as "built from the first commit". App Store Connect
# accepts up to three dot-separated integers, compared part by part.
#
# Called on the *built* plist, never the source one: from an Xcode run-script
# phase with "$TARGET_BUILD_DIR/$INFOPLIST_PATH" (so Xcode's Run button gets
# the stamp too), and from build.sh with the assembled bundle's plist. The
# build signs after this, so the stamp is covered by the signature.
set -euo pipefail

BUNDLE_VERSION=no
if [ "${1:-}" = "--bundle-version" ]; then
	BUNDLE_VERSION=yes
	shift
fi
PLIST="${1:?usage: stamp-git-commit.sh [--bundle-version] <Info.plist>}"
[ -f "$PLIST" ] || { echo "✗ stamp-git-commit: no plist at $PLIST" >&2; exit 1; }

# No optional locks: this runs inside builds, possibly while someone else is
# using git in the same checkout, and must never leave or trip over
# .git/index.lock.
export GIT_OPTIONAL_LOCKS=0

if COMMIT="$(git rev-parse --short=12 HEAD 2>/dev/null)"; then
	# Separately, so that a failing `git status` stops the build rather than
	# reading as a clean tree.
	STATUS="$(git status --porcelain)"
	DIRTY=0
	if [ -n "$STATUS" ]; then
		COMMIT="$COMMIT-dirty"
		DIRTY=1
	fi
	COUNT="$(git rev-list --count HEAD)"
elif git rev-parse --git-dir >/dev/null 2>&1; then
	# A repository with no commits yet, as a new app is before its first.
	COMMIT=no-commits
	COUNT=0
	DIRTY=1
elif [ "${STAMP_ALLOW_NO_GIT:-}" = 1 ]; then
	COMMIT=unknown
	COUNT=""
else
	echo "error: stamp-git-commit: git cannot read HEAD from $PWD; set STAMP_ALLOW_NO_GIT=1 to build without a stamp" >&2
	exit 1
fi

plutil -replace AppGitCommit -string "$COMMIT" "$PLIST"
if [ "$BUNDLE_VERSION" = yes ]; then
	if [ -n "$COUNT" ]; then
		plutil -replace CFBundleVersion -string "$COUNT.$DIRTY" "$PLIST"
	else
		echo "warning: stamp-git-commit: no git; CFBundleVersion left as it was" >&2
	fi
fi
echo "stamped AppGitCommit=$COMMIT${COUNT:+ (commit $COUNT)}"
