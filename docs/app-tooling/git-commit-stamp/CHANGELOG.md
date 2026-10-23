# git-commit-stamp changelog

## v0.1.0 (2026-10-05)

First version. `stamp-git-commit.sh` writes `AppGitCommit`, and with
`--bundle-version` a `CFBundleVersion` of `<count>.<dirty>`;
`device-which-commit.sh` reads the latter back from a device. Tried on
a local clone of an existing iOS app: simulator build, signed device build,
and the read-back against a real phone (on a build from before the stamp,
which it correctly refused to interpret).
