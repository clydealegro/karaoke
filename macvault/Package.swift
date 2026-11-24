// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacVault",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MacVault", targets: ["MacVault"]),
    ],
    targets: [
        .target(name: "MacVaultCore"),
        .executableTarget(name: "MacVault", dependencies: ["MacVaultCore"]),
        .testTarget(name: "MacVaultCoreTests", dependencies: ["MacVaultCore"]),
    ]
)
