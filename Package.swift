// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Battleship",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Battleship", targets: ["Battleship"])
    ],
    targets: [
        .executableTarget(
            name: "Battleship",
            path: "Sources/Battleship",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("QuartzCore")
            ]
        ),
        .testTarget(
            name: "BattleshipTests",
            dependencies: ["Battleship"],
            path: "Tests/BattleshipTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
