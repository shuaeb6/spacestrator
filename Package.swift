// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Spacestrator",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // C shim that lazily binds to private SkyLight symbols via dlopen/dlsym.
        .target(
            name: "CSkyLight",
            path: "Sources/CSkyLight"
        ),

        // All app logic lives here so it can be unit-tested (executable targets
        // can't be imported by test targets).
        .target(
            name: "SpacestratorKit",
            dependencies: ["CSkyLight"],
            path: "Sources/SpacestratorKit",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Carbon"),
                .linkedFramework("UserNotifications")
            ]
        ),

        // Thin entry point: just sets up NSApplication + AppDelegate.
        .executableTarget(
            name: "Spacestrator",
            dependencies: ["SpacestratorKit"],
            path: "Sources/Spacestrator"
        ),

        .testTarget(
            name: "SpacestratorKitTests",
            dependencies: ["SpacestratorKit"],
            path: "Tests/SpacestratorKitTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
