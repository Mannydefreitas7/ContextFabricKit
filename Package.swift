// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ContextFabricKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ContextFabricKit", targets: ["ContextFabricKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pvieito/PythonKit.git", from: "0.3.0"),
    ],
    targets: [
        // Python.xcframework downloaded and staged by `make bootstrap`.
        // swift build will fail until that step is complete.
        .binaryTarget(
            name: "Python",
            path: "Artifacts/Python.xcframework"
        ),
        .target(
            name: "ContextFabricKit",
            dependencies: [
                "Python",
                .product(name: "PythonKit", package: "PythonKit"),
            ]
        ),
        .testTarget(
            name: "ContextFabricKitTests",
            dependencies: ["ContextFabricKit"]
        ),
    ]
)
