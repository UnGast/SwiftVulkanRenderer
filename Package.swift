// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftVulkanRenderer",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SwiftVulkanRenderer",
            targets: ["SwiftVulkanRenderer"]),
        .executable(
            name: "RasterizationDemo",
            targets: ["RasterizationDemo"]),
        .executable(
            name: "RaytracingDemo",
            targets: ["RaytracingDemo"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(name: "Swim", url: "https://github.com/t-ae/swim.git", .exact("3.9.0")),
        .package(name: "GfxMath", url: "https://github.com/UnGast/swift-gfx-math.git", .branch("master")),
        .package(name: "FirebladePAL", url: "https://github.com/fireblade-engine/pal", .branch("main"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SwiftVulkanRenderer",
            dependencies: [.product(name: "FirebladePAL", package: "FirebladePAL"), "CTinyObjLoader", "Swim", "GfxMath"],
            resources: [
                .process("Resources")
            ]),
        .target(
            name: "RasterizationDemo",
            dependencies: ["SwiftVulkanRenderer", "GfxMath", "Swim"]
        ),
        .target(
            name: "RaytracingDemo",
            dependencies: ["SwiftVulkanRenderer", "GfxMath", "Swim"]
        ),
        .target(name: "CTinyObjLoader")
    ]
)
