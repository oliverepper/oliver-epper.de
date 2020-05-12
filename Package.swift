// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "OliverEpper",
    products: [
        .executable(name: "OliverEpper", targets: ["OliverEpper"])
    ],
    dependencies: [
        .package(url: "https://github.com/johnsundell/publish.git", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "OliverEpper",
            dependencies: ["Publish"]
        )
    ]
)