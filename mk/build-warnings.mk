# build-warnings.mk — remove two build warnings at their cause.
#
# Imported by peru from the app-tooling pattern `build-warnings`
# (https://github.com/tikitu/app-tooling). Never edit it here: `peru sync`
# refuses to overwrite a changed copy, and the change belongs in app-tooling.
# docs/app-tooling/build-warnings/ says how to use it.
#
# From the project's Makefile:   include mk/build-warnings.mk
#
# No parameters, no targets. Every make run of the project gets both parts.

# swift-issue-reporting (xctest-dynamic-overlay >= 1.11.0) builds
# IssueReportingTestSupport as a dynamic library at its own deployment target,
# which links against Testing.framework built for a newer one: an `ld:
# warning: building for macOS-12.0, but linking with dylib ...` in every test
# build. With this set, its manifest leaves the product's type to SwiftPM, which
# links it statically into the test bundle, at the project's own deployment
# target. Exported, so swift and xcodebuild in every recipe see it.
export OMIT_DYNAMIC_TEST_SUPPORT := 1

# Refuse to run at all while LM_SKIP_METADATA_EXTRACTION is set anywhere in
# the project and any Swift file has App Intents code (or, when it is set per
# target, while a skipped target compiles any): the skip would drop their
# metadata silently. Checked on every make run, so it cannot be missed.
# (make 3.81 has no .SHELLSTATUS: the script prints `ok` when it passes. On
# failure it runs again onto stderr, for its message with its line breaks.)
_build_warnings_script := $(dir $(lastword $(MAKEFILE_LIST)))../scripts/check-app-intents-skip.sh
_build_warnings_check := $(shell sh $(_build_warnings_script) 2>&1)
ifneq ($(lastword $(_build_warnings_check)),ok)
$(shell sh $(_build_warnings_script) >&2)
$(error scripts/check-app-intents-skip.sh failed, above)
endif
