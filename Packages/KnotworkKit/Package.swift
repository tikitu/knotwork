// swift-tools-version: 6.2

import PackageDescription

// Every target gets the same two settings, spelled out rather than left to a
// default that moves between toolchains:
//
//   * Swift 6 language mode — strict concurrency checking, no opt-out.
//   * Default actor isolation `nil`, i.e. nonisolated, in UI targets too.
//     `@MainActor` is marked where it is needed. Making it the default hides
//     which code actually has to be on the main actor.
let shared: [SwiftSetting] = [.swiftLanguageMode(.v6), .defaultIsolation(nil)]

// The shared half: the knot, the model, the commands, and the view that edits
// the knot. It declares macOS as well as iOS, so that `make test` runs its
// suite on the Mac and a Mac app can be added beside the iOS one; `make check`
// compiles it for both. Platform-only code lives in a package whose manifest
// names that platform alone (KnotworkIOSKit), never behind `#if os(…)`.
//
// No dependencies yet: there is no data to store or share.
let package = Package(
    name: "KnotworkKit", platforms: [.macOS(.v26), .iOS(.v26)],
    products: [.library(name: "Core", targets: ["Core"]), .library(name: "UI", targets: ["UI"])],
    targets: [
        // The knot itself: break lines and the tiles they make. No UI.
        .target(name: "Core", swiftSettings: shared),
        // The model, the commands, and the views.
        .target(
            name: "UI", dependencies: ["Core"], resources: [.copy("Resources/Tiles")],
            swiftSettings: shared),
        .testTarget(name: "CoreTests", dependencies: ["Core"], swiftSettings: shared),
        .testTarget(name: "UITests", dependencies: ["UI"], swiftSettings: shared),
    ])
