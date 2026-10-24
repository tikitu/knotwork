// swift-tools-version: 6.2

import PackageDescription

// The same settings as KnotworkKit, for the same reason: default isolation is
// spelled out as nonisolated, and code opts in to `@MainActor`.
let shared: [SwiftSetting] = [.swiftLanguageMode(.v6), .defaultIsolation(nil)]

// The iOS half. Declaring iOS as the *only* platform is the whole design: an
// iOS-only API is at home here, needs no `#if os(iOS)` guard, and cannot leak
// into KnotworkKit, which cannot see this package.
//
// Never built by `swift build` on the host; xcodebuild builds it for iOS,
// through apps/ios.
let package = Package(
    name: "KnotworkIOSKit", platforms: [.iOS(.v26)],
    products: [
        // Linked by the app target in apps/ios, a forwarding shell over this.
        .library(name: "KnotworkIOS", targets: ["KnotworkIOS"])
    ],
    dependencies: [
        .package(path: "../KnotworkKit"),
        // The simulator's command inbox (docs/commands.md); the same pin as
        // KnotworkKit's.
        .package(url: "https://github.com/tikitu/app-utils", exact: "0.4.0"),
    ],
    targets: [
        .target(
            name: "KnotworkIOS",
            dependencies: [
                .product(name: "Core", package: "KnotworkKit"),
                .product(name: "UI", package: "KnotworkKit"),
                .product(name: "CommandInbox", package: "app-utils"),
            ], swiftSettings: shared)
    ])
