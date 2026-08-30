// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WarBaseClient",
    platforms: [
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .executable(name: "WarBaseClient", targets: ["WarBaseClient"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.0")
    ],
    targets: [
        .executableTarget(
            name: "WarBaseClient",
            dependencies: [
                .product(name: "SwiftProtobuf", package: "swift-protobuf")
            ],
            path: "Sources",
            exclude: [
                "AnimatedSoldier.usdz",
                "Dying.usdz",
                "Firing_Rifle.usdz",
                "Firing_walk_Rifle.usdz",
                "Rifle_Idle.usdz",
                "Rifle_Jump.usdz",
                "Rifle_Run.usdz",
                "Strafe_Left.usdz",
                "Strafe_Right.usdz",
                "TPose.usdz",
                "Walking_Backwards.usdz",
                "industrial.usdz",
                "anim_data.json",
                "venice_sunset_1k.hdr"
            ]
        )
    ]
)
