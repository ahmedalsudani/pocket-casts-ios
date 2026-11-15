// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Modules",
    platforms: [
        .iOS(.v17), .watchOS(.v10), .macOS(.v13)
    ],
    products: XcodeSupport.products + [
        .library(
            name: "PocketCastsUtils",
            targets: ["PocketCastsUtils"]
        ),
        .library(
            name: "PocketCastsDataModel",
            targets: ["PocketCastsDataModel"]
        ),
        .library(
            name: "PocketCastsServer",
            targets: ["PocketCastsServer"]
        ),
        .library(
            name: "EndOfYear",
            targets: ["EndOfYear"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/danielebogo/Swime", branch: "master"),
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.4.0"),
        .package(url: "https://github.com/ra1028/DifferenceKit", from: "1.2.0"),
        .package(url: "https://github.com/krisk/fuse-swift", from: "1.4.0"),
        .package(url: "https://github.com/shiftyjelly/SwipeCellKit", from: "2.7.6"),
        .package(url: "https://github.com/Automattic/Agrume", from: "5.6.12"),
        .package(url: "https://github.com/joeldev/JLRoutes", from: "2.1.1"),
        .package(url: "https://github.com/onevcat/Kingfisher", from: "7.10.2"),
        .package(url: "https://github.com/dagronf/SwiftSubtitles", from: "1.8.3"),
        .package(url: "https://github.com/Automattic/google-cast", from: "1.0.1"),
    ],
    targets: XcodeSupport.targets + [
        .target(
            name: "PocketCastsUtils",
            path: "Sources/PocketCastsUtils",
            swiftSettings: [
                .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "PocketCastsUtilsTests",
            dependencies: ["PocketCastsUtils"],
            path: "Tests/PocketCastsUtilsTests"
        ),
        .target(
            name: "PocketCastsDataModel",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                "PocketCastsUtils",
            ],
            path: "Sources/PocketCastsDataModel",
            swiftSettings: [
                .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "PocketCastsDataModelTests",
            dependencies: ["PocketCastsDataModel"],
            path: "Tests/PocketCastsDataModelTests"
        ),
        .target(
            name: "PocketCastsServer",
            dependencies: [
                .product(name: "Swime", package: "Swime"),
                "PocketCastsDataModel",
                "PocketCastsUtils",
            ],
            path: "Sources/PocketCastsServer",
            swiftSettings: [
                .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
            ],
            linkerSettings: [
                .linkedFramework("CFNetwork", .when(platforms: [.iOS]))
            ]
        ),
        .testTarget(
            name: "PocketCastsServerTests",
            dependencies: ["PocketCastsServer"],
            path: "Tests/PocketCastsServerTests",
            resources: [.copy("Fixtures")]
        ),
        .target(
            name: "EndOfYear",
            dependencies: [
                "PocketCastsUtils",
            ],
            path: "Sources/EndOfYear"
        ),
        .target(
            name: "AEXML",
            path: "Sources/AEXML"
        ),
        .target(
            name: "MNAVChapters",
            path: "Sources/MNAVChapters"
        ),
        .target(
            name: "SJUtils",
            path: "Sources/SJUtils"
        ),
        .target(
            name: "VoiceBoostN",
            path: "Sources/VoiceBoostN",
            linkerSettings: [
                .linkedFramework("Accelerate")
            ]
        )
    ]
)

// MARK: - XcodeSupport (Xcode Targets)

// Below are dependencies for the respective Xcode targets.
//
// You can add internal or third-party dependencies to these targets or even
// source files and resources.
//
// - note: SwiftPM automatically detects which modules are shared between
//   multiple targets and decides when to use dynamic frameworks.

enum XcodeTargetNames {
    static let podcasts = "podcasts"
    static let pocketCastsWatchApp = "Pocket Casts Watch App"
    static let podcastsIntents = "PodcastsIntents"
    static let podcastsIntentsUI = "PodcastsIntentsUI"
    static let widgetExtension = "WidgetExtension"
}

enum XcodeSupport {
    static var products: [Product] {
        [
            XcodeTargetNames.podcasts,
            XcodeTargetNames.pocketCastsWatchApp,
            XcodeTargetNames.podcastsIntents,
            XcodeTargetNames.podcastsIntentsUI,
            XcodeTargetNames.widgetExtension,
        ].map { .supportingProduct(forXcodeTarget: $0) }
    }

    static var targets: [Target] {
        [
            .xcodeTarget(
                XcodeTargetNames.podcasts,
                dependencies: [
                    "PocketCastsDataModel",
                    "PocketCastsServer",
                    "PocketCastsUtils",
                    .product(name: "Lottie", package: "lottie-ios"),
                    .product(name: "DifferenceKit", package: "DifferenceKit"),
                    .product(name: "SwipeCellKit", package: "SwipeCellKit"),
                    .product(name: "Agrume", package: "Agrume"),
                    .product(name: "JLRoutes", package: "JLRoutes"),
                    .product(name: "Kingfisher", package: "Kingfisher"),
                    .product(name: "SwiftSubtitles", package: "SwiftSubtitles"),
                    .product(name: "GoogleCast", package: "google-cast"),
                    "EndOfYear",
                    "AEXML",
                    "MNAVChapters",
                    "SJUtils",
                    "VoiceBoostN",
                ]
            ),
            .xcodeTarget(
                XcodeTargetNames.pocketCastsWatchApp,
                dependencies: [
                    "PocketCastsDataModel",
                    "PocketCastsServer",
                    "PocketCastsUtils",
                    .product(name: "Kingfisher", package: "Kingfisher"),
                    "MNAVChapters",
                    "SJUtils",
                ]
            ),
            .xcodeTarget(
                XcodeTargetNames.podcastsIntents,
                dependencies: [
                    .product(name: "Fuse", package: "fuse-swift"),
                ]
            ),
            .xcodeTarget(
                XcodeTargetNames.podcastsIntentsUI,
                dependencies: []
            ),
            .xcodeTarget(
                XcodeTargetNames.widgetExtension,
                dependencies: [
                    "PocketCastsUtils",
                ]
            ),
        ]
    }
}

extension Product {
    static func supportingProduct(forXcodeTarget targetName: String) -> Product {
        .library(
            name: "XcodeTarget_\(targetName)",
            targets: ["XcodeTarget_\(targetName)"]
        )
    }
}

extension Target {
    static func xcodeTarget(_ name: String, dependencies: [Dependency]) -> Target {
        .target(
            name: name.supportingName,
            dependencies: dependencies,
            path: "Sources/XcodeSupport/\(name.replacing(" ", with: "-").supportingName)"
        )
    }
}

extension String {
    var supportingName: String {
        "XcodeTarget_\(self)"
    }
}
