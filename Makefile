# Knotwork — build front door.
#
# An iOS app (iPhone and iPad). The code is in two SwiftPM packages; the Xcode
# project in apps/ios is generated from apps/ios/project.yml by XcodeGen and
# git-ignored (docs/ios.md).
#
# Quick start:
#   make check             # compile the shared package for macOS and iOS (fast gate)
#   make test              # its test suite, on the Mac
#   make ios-run           # build, install and launch on a simulator
#   make help              # everything else

# Two packages, split by platform rather than by `#if`: SHARED declares macOS
# and iOS and holds everything that is not iOS-specific, and its tests run on
# the Mac; IOS_PACKAGE is iOS only.
SHARED       := Packages/KnotworkKit
IOS_PACKAGE  := Packages/KnotworkIOSKit

IOS_DIR      := apps/ios
IOS_PROJECT  := $(IOS_DIR)/Knotwork.xcodeproj
IOS_SCHEME   := Knotwork
IOS_BUNDLE_ID:= org.logophile.Knotwork
# Simulator names change with Xcode releases: `xcrun simctl list devices
# available` lists what this Xcode has. Override with IOS_SIM=... The name is
# resolved once, to the simulator of that name on the newest iOS runtime, and
# the UDID used everywhere: names repeat across runtimes, and xcodebuild and
# simctl would each choose differently (docs/gotchas.md).
IOS_SIM      ?= iPhone 17
IOS_SIM_UDID  = $(or $(shell scripts/simulator-udid.py '$(IOS_SIM)'),$(error no simulator '$(IOS_SIM)': set IOS_SIM))
IOS_DEST      = platform=iOS Simulator,id=$(IOS_SIM_UDID)
IOS_DERIVED  := build/ios
IOS_SIM_APP  := $(IOS_DERIVED)/Build/Products/Debug-iphonesimulator/Knotwork.app
# The device for ios-device-* (as `xcrun devicectl list devices` names it).
IOS_DEVICE   ?= Tikitu iPhone 15

# app-tooling-update and app-tooling-check, for the conventions imported from
# app-tooling (peru.yaml; docs/app-tooling/pattern-imports/README.md).
include mk/app-tooling.mk

# Two dependency and Xcode warnings removed at their cause; refuses to run
# while the App Intents skip and App Intents code are both in the project
# (app-tooling: build-warnings). docs/app-tooling/build-warnings/.
include mk/build-warnings.mk

.PHONY: all help check test tile-sheets app-icon fmt fmt-check rules lint clean \
        ios-project ios-build ios-run ios-run-commands ios-screenshot \
        ios-device-build ios-device-run ios-device-which ios-clean

all: check

help:
	@echo "Build and test:"
	@echo "  check             Compile the shared package for macOS and iOS; the fast gate"
	@echo "  test              Run the shared package's tests, on the Mac"
	@echo "  tile-sheets       Render every tileset beside the original images, to build/tilesets/"
	@echo "  app-icon          Regenerate the app's icon ($(APP_ICON))"
	@echo "  clean             Remove build/ and the packages' .build/"
	@echo ""
	@echo "iOS:"
	@echo "  ios-project       Regenerate $(IOS_PROJECT) from project.yml"
	@echo "  ios-build         Build the app for the simulator ($(IOS_SIM))"
	@echo "  ios-run           Build, install and launch on the simulator"
	@echo "  ios-run-commands  The same, accepting commands (docs/commands.md)"
	@echo "  ios-screenshot    Save the simulator's screen to build/simulator.png"
	@echo "  ios-device-build  Build signed for a connected device (IOS_DEVICE=...)"
	@echo "  ios-device-run    Build and install on the device"
	@echo "  ios-device-which  Which commit the app on the device was built from"
	@echo "  ios-clean         Delete the generated Xcode project"
	@echo ""
	@echo "Lint / format:"
	@echo "  fmt               Reformat every Swift file in place (swift format)"
	@echo "  fmt-check         Fail if any Swift file is not formatted"
	@echo "  rules             Test the ast-grep rules, then scan (see rules/README.md)"
	@echo "  lint              fmt-check + rules — the whole non-compiling gate"
	@echo ""
	@echo "app-tooling:"
	@echo "  app-tooling-update  Move to the newest app-tooling commit peru.yaml follows; prints the steps"
	@echo "  app-tooling-check   Check files imported from app-tooling match peru.yaml's pin"

# ---------------------------------------------------------------------------
# Pinned dependencies
#
# Each package's Package.resolved is committed, and every build uses exactly
# those versions or fails, rather than resolving past them and rewriting the
# file: `--force-resolved-versions` for swift, and
# `-onlyUsePackageVersionsFromResolvedFile` (in XCODE_FLAGS) for xcodebuild.
# The generated Xcode project has no lockfile of its own: `ios-project` copies
# KnotworkIOSKit's into it, since the app's dependencies are that package's.
# Updating a dependency is a deliberate change of the committed files.
# ---------------------------------------------------------------------------

SWIFT_FLAGS          := --package-path $(SHARED) --force-resolved-versions
IOS_RESOLVED         := $(IOS_PACKAGE)/Package.resolved
IOS_PROJECT_RESOLVED := $(IOS_PROJECT)/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

# Every xcodebuild passes these. `-skipMacroValidation` because xcodebuild
# refuses a package's macros until someone clicks "Trust & Enable", which a
# script cannot; there are no package macros yet, so this costs nothing.
XCODE_FLAGS := -skipMacroValidation -onlyUsePackageVersionsFromResolvedFile

# ---------------------------------------------------------------------------
# Build and test
# ---------------------------------------------------------------------------

# The shared package for the Mac, then for iOS. The iOS compile keeps it free
# of Mac-only API, and the Mac one of iOS-only API; LM_SKIP_METADATA_EXTRACTION
# because a package scheme has no settings of its own (build-warnings).
check:
	swift build $(SWIFT_FLAGS)
	@cd $(SHARED) && xcodebuild -scheme KnotworkKit-Package -destination 'generic/platform=iOS' \
	  -derivedDataPath $(CURDIR)/build/ios-check $(XCODE_FLAGS) LM_SKIP_METADATA_EXTRACTION=YES -quiet build
	@echo "✓ shared package compiles for macOS and iOS"

# The tests live with the shared code; the iOS package is the root view and
# the app delegate.
test:
	swift test $(SWIFT_FLAGS)
	@echo "✓ tests pass"

# The tilesets drawn in code, beside Boston-Baden's images, as PNGs: each tile
# on its own, and some knots made of them.
tile-sheets:
	swift run $(SWIFT_FLAGS) TileSheets $(SHARED)/Sources/UI/Resources/Tiles build/tilesets

# The app's icon is drawn by the same code as the tiles; committed, so a build
# needs no step of its own. Run this after changing how the tiles look.
APP_ICON := $(IOS_DIR)/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png
app-icon:
	swift run $(SWIFT_FLAGS) TileSheets --icon $(APP_ICON)

clean:
	rm -rf build $(SHARED)/.build $(IOS_PACKAGE)/.build
	@echo "✓ removed build/ and the packages' .build/"

# ---------------------------------------------------------------------------
# iOS
#
# apps/ios/Knotwork.xcodeproj is GENERATED from apps/ios/project.yml and
# git-ignored. Edit the yaml, never the project.
# ---------------------------------------------------------------------------

ios-project:
	@command -v xcodegen >/dev/null 2>&1 || { echo "✗ xcodegen not installed (brew install xcodegen)"; exit 1; }
	cd $(IOS_DIR) && xcodegen generate --quiet
	@if [ -f $(IOS_RESOLVED) ]; then mkdir -p $(dir $(IOS_PROJECT_RESOLVED)) && cp $(IOS_RESOLVED) $(IOS_PROJECT_RESOLVED); fi
	@echo "✓ generated $(IOS_PROJECT)"

# Unsigned, for the simulator: no provisioning profile needed.
ios-build: ios-project
	xcodebuild build -project $(IOS_PROJECT) -scheme $(IOS_SCHEME) -destination '$(IOS_DEST)' \
	  -derivedDataPath $(IOS_DERIVED) CODE_SIGNING_ALLOWED=NO $(XCODE_FLAGS) -quiet
	@echo "✓ built $(IOS_SIM_APP)"

# Boots the simulator if need be, without opening Simulator.app, so nothing
# takes focus. `open -a Simulator` shows it, for a person.
define ios-install-and-launch
	@xcrun simctl boot $(IOS_SIM_UDID) 2>/dev/null || true
	@xcrun simctl bootstatus $(IOS_SIM_UDID) -b >/dev/null
	xcrun simctl install $(IOS_SIM_UDID) $(IOS_SIM_APP)
	xcrun simctl launch --terminate-running-process $(IOS_SIM_UDID) $(IOS_BUNDLE_ID) $(1)
endef

ios-run: ios-build
	$(call ios-install-and-launch,)
	@echo "✓ launched on $(IOS_SIM) ($(IOS_SIM_UDID))"

ios-run-commands: ios-build
	$(call ios-install-and-launch,--accept-commands)
	@echo "✓ launched on $(IOS_SIM) ($(IOS_SIM_UDID)), accepting commands:"
	@echo "  scripts/send-commands.sh '<json>'   (the booted simulator: docs/commands.md)"

ios-screenshot:
	@mkdir -p build
	xcrun simctl io $(IOS_SIM_UDID) screenshot build/simulator.png
	@echo "✓ build/simulator.png"

ios-device-build: ios-project
	xcodebuild build -project $(IOS_PROJECT) -scheme $(IOS_SCHEME) \
	  -destination 'platform=iOS,name=$(IOS_DEVICE)' -derivedDataPath $(IOS_DERIVED) \
	  -allowProvisioningUpdates $(XCODE_FLAGS) -quiet
	@echo "✓ built for $(IOS_DEVICE)"

ios-device-run: ios-device-build
	xcrun devicectl device install app --device '$(IOS_DEVICE)' \
	  $(IOS_DERIVED)/Build/Products/Debug-iphoneos/Knotwork.app
	@echo "✓ installed on $(IOS_DEVICE)"

# Which commit the app on $(IOS_DEVICE) was built from (app-tooling:
# git-commit-stamp).
ios-device-which:
	@scripts/device-which-commit.sh '$(IOS_DEVICE)' '$(IOS_BUNDLE_ID)'

ios-clean:
	rm -rf $(IOS_PROJECT)
	@echo "✓ removed generated $(IOS_PROJECT)"

# ---------------------------------------------------------------------------
# Lint and format
#
# `swift format` comes from the Xcode toolchain; configuration is
# .swift-format. The ast-grep rules catch mistakes that fail *silently*; each
# sits beside a document saying why it exists, and has a test. See
# rules/README.md.
# ---------------------------------------------------------------------------

# NOT scripts/: swift-format mangles a `#!/usr/bin/env swift` script.
SWIFT_FORMAT_PATHS := Packages $(IOS_DIR)/App

fmt:
	@swift format --configuration .swift-format --recursive --in-place $(SWIFT_FORMAT_PATHS)
	@echo "✓ formatted"

fmt-check:
	@swift format lint --configuration .swift-format --recursive --strict $(SWIFT_FORMAT_PATHS) \
	  && echo "✓ formatting clean"

# The tests first: a rule whose pattern has quietly stopped matching would
# otherwise pass every scan.
rules:
	@command -v ast-grep >/dev/null 2>&1 || { \
	  echo "  ✗ ast-grep not installed (brew install ast-grep)"; exit 1; }
	@ast-grep test --skip-snapshot-tests
	ast-grep scan Packages $(IOS_DIR)/App
	@echo "✓ rules clean"

lint: fmt-check rules
	@echo "✓ lint clean"
