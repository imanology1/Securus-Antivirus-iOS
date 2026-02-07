// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

// ============================================================================
// Securus iOS SDK - Swift Package Manager Manifest
// ============================================================================
// A modular mobile security SDK providing network anomaly detection,
// runtime integrity verification, and on-device AI-powered threat analysis.
//
// Modules:
//   - SecurusCore:    Core engine, models, crypto, storage, and utilities
//   - SecurusNetwork: Network traffic monitoring and anomaly detection
//   - SecurusRuntime: Runtime integrity checks (jailbreak, debugger, repackaging)
// ============================================================================

import PackageDescription

let package = Package(
    name: "SecurusSDK",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        // Full SDK umbrella - most integrators will use this
        .library(
            name: "SecurusSDK",
            targets: ["SecurusCore", "SecurusNetwork", "SecurusRuntime"]
        ),
        // Individual modules for granular adoption
        .library(
            name: "SecurusCore",
            targets: ["SecurusCore"]
        ),
        .library(
            name: "SecurusNetwork",
            targets: ["SecurusNetwork"]
        ),
        .library(
            name: "SecurusRuntime",
            targets: ["SecurusRuntime"]
        )
    ],
    targets: [
        // MARK: - Core Module
        .target(
            name: "SecurusCore",
            dependencies: [],
            path: "Sources/SecurusCore",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("SECURUS_SDK")
            ]
        ),

        // MARK: - Network Module
        .target(
            name: "SecurusNetwork",
            dependencies: ["SecurusCore"],
            path: "Sources/SecurusNetwork",
            swiftSettings: [
                .define("SECURUS_SDK")
            ]
        ),

        // MARK: - Runtime Module
        .target(
            name: "SecurusRuntime",
            dependencies: ["SecurusCore"],
            path: "Sources/SecurusRuntime",
            swiftSettings: [
                .define("SECURUS_SDK")
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "SecurusCoreTests",
            dependencies: ["SecurusCore"],
            path: "Tests/SecurusCoreTests"
        ),
        .testTarget(
            name: "SecurusNetworkTests",
            dependencies: ["SecurusNetwork", "SecurusCore"],
            path: "Tests/SecurusNetworkTests"
        ),
        .testTarget(
            name: "SecurusRuntimeTests",
            dependencies: ["SecurusRuntime", "SecurusCore"],
            path: "Tests/SecurusRuntimeTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
