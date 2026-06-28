// swift-tools-version: 5.9
//
//  Package.swift
//  AmbilightCore
//
//  Shared, platform-agnostic business / TV-communication logic for the
//  Ambilight Hue Control app. Consumed by the tvOS, iOS (universal) and
//  watchOS targets.
//

import PackageDescription

let package = Package(
    name: "AmbilightCore",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        .library(
            name: "AmbilightCore",
            targets: ["AmbilightCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.10.0"),
        // Mocker is test-only.
        .package(url: "https://github.com/WeTransfer/Mocker.git", from: "3.0.2"),
    ],
    targets: [
        .target(
            name: "AmbilightCore",
            dependencies: ["Alamofire"]
        ),
        .testTarget(
            name: "AmbilightCoreTests",
            dependencies: [
                "AmbilightCore",
                "Alamofire",
                "Mocker",
            ]
        ),
    ]
)
