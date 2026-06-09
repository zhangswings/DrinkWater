// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DrinkWater",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DrinkWater",
            path: "Sources/DrinkWater",
        )
    ]
)
