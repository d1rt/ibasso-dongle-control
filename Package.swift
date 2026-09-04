// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ibasso-dongle-control",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "BassoCore", targets: ["BassoCore"]),
        .library(name: "DongleControlFeature", targets: ["DongleControlFeature"]),
        .executable(name: "ibasso-dongle", targets: ["BassoCLI"]),
        .executable(name: "DongleControlApp", targets: ["DongleControlApp"])
    ],
    targets: [
        .target(
            name: "BassoCore",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AudioToolbox")
            ]
        ),
        .executableTarget(
            name: "BassoCLI",
            dependencies: ["BassoCore"]
        ),
        .target(
            name: "DongleControlFeature",
            dependencies: ["BassoCore"]
        ),
        .executableTarget(
            name: "DongleControlApp",
            dependencies: ["BassoCore", "DongleControlFeature"]
        ),
        .testTarget(
            name: "BassoCoreTests",
            dependencies: ["BassoCore", "DongleControlFeature"]
        )
    ]
)
