// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let commonSwiftSettings: [PackageDescription.SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
    .strictMemorySafety(),
]

let package = Package(
    name: "PropertyList",
    // The floor is what a consumer of this package has to be able to deploy to, and the one that
    // set it is swift-user-defaults-kit — a `UserDefaults` value is a property list, so that
    // package reads one everywhere it runs.
    platforms: [
        .macOS(.v12),
        .macCatalyst(.v15),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1),
    ],
    products: [
        // Split so that reading a property list does not drag in the machinery for decoding a
        // `Decodable` out of one: the value type and its accessors are a few hundred lines, and the
        // `Coder` pair is several times that.
        .library(
            name: "PropertyList",
            targets: ["PropertyList"]
        ),
    ],
    traits: [
        .trait(name: "Value"),
        .trait(name: "ValueCoder", enabledTraits: ["Value"]),
        .default(enabledTraits: ["Value", "ValueCoder"]),
    ],
    targets: [
        .target(
            name: "PropertyList",
            dependencies: [
                .targetItem(name: "PropertyListValue", condition: .when(traits: ["Value"])),
                .targetItem(name: "PropertyListValueCoder", condition: .when(traits: ["ValueCoder"])),
            ],
            swiftSettings: commonSwiftSettings,
        ),
        .target(
            name: "PropertyListValue",
            swiftSettings: commonSwiftSettings
        ),
        .target(
            name: "PropertyListValueCoder",
            dependencies: ["PropertyListValue"],
            swiftSettings: commonSwiftSettings,
        ),
        // Fixtures the two test targets share. Not a product: it exists for this package's tests
        // and everything it offers is `package` rather than `public`.
        .target(
            name: "PropertyListTestSupport",
            swiftSettings: commonSwiftSettings,
        ),
        .testTarget(
            name: "PropertyListValueTests",
            dependencies: ["PropertyListValue", "PropertyListTestSupport"],
            swiftSettings: commonSwiftSettings,
        ),
        .testTarget(
            name: "PropertyListValueCoderTests",
            dependencies: [
                "PropertyListValueCoder",
                "PropertyListTestSupport",
            ],
            swiftSettings: commonSwiftSettings,
        ),
    ]
)
