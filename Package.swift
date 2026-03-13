// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "PNProtocol",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "PNProtocol",
            targets: ["PNProtocol"]
        ),
    ],
    dependencies: [
        // CocoaMQTT for MQTT transport
        .package(url: "https://github.com/emqx/CocoaMQTT.git", from: "2.1.6"),
    ],
    targets: [
        .target(
            name: "PNProtocol",
            dependencies: ["CocoaMQTT"],
            path: "Sources/PNProtocol"
        ),
        .testTarget(
            name: "PNProtocolTests",
            dependencies: ["PNProtocol"]
        ),
    ]
)
