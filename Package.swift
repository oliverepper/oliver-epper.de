// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "OliverEpper",
    products: [
        .executable(name: "OliverEpper", targets: ["OliverEpper"])
    ],
    dependencies: [
        .package(url: "https://github.com/johnsundell/publish.git", from: "0.3.0"),
        .package(url: "https://github.com/Ze0nC/SwiftPygmentsPublishPlugin", .branch("master")),
        .package(url: "https://github.com/insidegui/DarkImagePublishPlugin", .branch("master"))
    ],
    targets: [
        .target(
            name: "OliverEpper",
            dependencies: [
                "Publish",
                "SwiftPygmentsPublishPlugin",
                "DarkImagePublishPlugin"]
        )
    ]
)
