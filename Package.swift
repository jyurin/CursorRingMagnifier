// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "mouse-circle",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MouseCircleApp", targets: ["MouseCircleApp"])
    ],
    targets: [
        .executableTarget(
            name: "MouseCircleApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
