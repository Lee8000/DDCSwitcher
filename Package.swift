// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DDCSwitcher",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "DDCSwitcher", targets: ["DDCSwitcher"])],
    targets: [
        .target(name: "DDCSwitcherCore"),
        .executableTarget(name: "DDCSwitcher", dependencies: ["DDCSwitcherCore"]),
        .testTarget(name: "DDCSwitcherCoreTests", dependencies: ["DDCSwitcherCore"])
    ]
)
