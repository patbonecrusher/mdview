// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MdViewer",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "MdViewer",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            resources: [
                .copy("Resources/style.css"),
                .copy("Resources/modest.css"),
                .copy("Resources/modest_dark.css"),
                .copy("Resources/welcome_logo.png"),
            ]
        )
    ]
)
