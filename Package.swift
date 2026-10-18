// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "Voxea",
    platforms: [.macOS(.v14)],
    dependencies: [.package(url: "https://github.com/FluidInference/FluidAudio.git", revision: "2d6c42ca5f3accc0faf9fee9e0fff5b9b2cf6042", traits: [])],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .executableTarget(name: "Voxea", dependencies: [.product(name: "FluidAudio", package: "FluidAudio"), "CSQLite"])
    ],
    swiftLanguageModes: [.v5]
)
