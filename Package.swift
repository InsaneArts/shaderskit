// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ShadersKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "ShadersKit", targets: ["ShadersKit"]),
    ],
    targets: [
        .target(
            name: "ShadersKit",
            path: "Sources/ShadersKit",
            resources: [
                .copy("Resources/MSL"),
                .copy("Resources/Descriptors"),
            ]
        ),
        .testTarget(
            name: "ShadersKitTests",
            dependencies: ["ShadersKit"],
            path: "Tests/ShadersKitTests"
        ),
    ]
)
