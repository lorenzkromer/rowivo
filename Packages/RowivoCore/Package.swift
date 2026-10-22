// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RowivoCore",
    platforms: [.iOS(.v18), .watchOS(.v11), .macOS(.v14)],
    products: [.library(name: "RowivoCore", targets: ["RowivoCore"])],
    targets: [.target(name: "RowivoCore"), .testTarget(name: "RowivoCoreTests", dependencies: ["RowivoCore"])]
)
