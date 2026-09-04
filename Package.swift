// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "dc-elite-control",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "DCEliteCore", targets: ["DCEliteCore"]),
        .executable(name: "dc-elite", targets: ["DCEliteCLI"]),
        .executable(name: "DCEliteControlApp", targets: ["DCEliteControlApp"])
    ],
    targets: [
        .target(
            name: "DCEliteCore",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AudioToolbox")
            ]
        ),
        .executableTarget(
            name: "DCEliteCLI",
            dependencies: ["DCEliteCore"]
        ),
        .executableTarget(
            name: "DCEliteControlApp",
            dependencies: ["DCEliteCore"]
        ),
        .testTarget(
            name: "DCEliteCoreTests",
            dependencies: ["DCEliteCore"]
        )
    ]
)
