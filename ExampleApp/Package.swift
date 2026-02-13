// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SecurusExampleApp",
    platforms: [.iOS(.v17)],
    dependencies: [
        .package(path: "../SecurusSDK")
    ],
    targets: [
        .executableTarget(
            name: "SecurusExampleApp",
            dependencies: [
                .product(name: "SecurusSDK", package: "SecurusSDK")
            ],
            path: "Sources"
        )
    ]
)
