// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MenuBuddy",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MenuBuddy",
            path: "Sources/MenuBuddy"
        )
    ]
)
