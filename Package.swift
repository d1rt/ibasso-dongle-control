// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "dc-elite-control",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "DCEliteCore", targets: ["DCEliteCore"]),
        .executable(name: "dc-elite", targets: ["DCEliteCLI"])
    ],
    targets: [
        .target(
            name: "DCEliteCore",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .executableTarget(
            name: "DCEliteCLI",
            dependencies: ["DCEliteCore"]
        ),
        .testTarget(
            name: "DCEliteCoreTests",
            dependencies: ["DCEliteCore"]
        )
    ]
)
