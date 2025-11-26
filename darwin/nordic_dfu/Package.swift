// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "nordic_dfu",
    platforms: [
        .iOS("11.0"),
        .macOS("10.15")
    ],
    products: [
        .library(name: "nordic-dfu", targets: ["nordic_dfu"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "nordic_dfu",
            dependencies: [],
            resources: [
                .process("Resources"),
            ]
        )
    ]
)
