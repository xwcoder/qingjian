// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QingJianCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "QingJianCore",
            targets: ["QingJianCore"]
        ),
    ],
    targets: [
        .target(
            name: "QingJianCore",
            dependencies: [],
            path: "Sources/QingJianCore"
        ),
        .testTarget(
            name: "QingJianCoreTests",
            dependencies: ["QingJianCore"],
            path: "Tests/QingJianCoreTests"
        ),
    ]
)

