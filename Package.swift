// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let commonSwiftSettings: [PackageDescription.SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("ImmutableWeakCaptures"),
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
        // Bridging to the `Any` Foundation deals in needs Foundation itself, which is the one that
        // brings ICU; everything else reads `Data` and `Date` from FoundationEssentials. So it is
        // asked for rather than on by default — and only matters where FoundationEssentials can be
        // imported. Elsewhere, Darwin included, the package imports Foundation regardless and the
        // bridge is always compiled in.
        .trait(name: "ValueFoundation", enabledTraits: ["Value"]),
        .default(enabledTraits: ["Value", "ValueCoder"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/sinoru/swift-core-foundation-kit.git",
            from: "0.1.0"
        ),
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
            dependencies: [
                // Darwin alone, where what Foundation hands back is an object to be told apart by
                // its CoreFoundation type ID and read from there. CoreFoundationKit builds nowhere
                // else.
                .product(
                    name: "CoreFoundationKit",
                    package: "swift-core-foundation-kit",
                    condition: .when(
                        platforms: [.macOS, .macCatalyst, .iOS, .tvOS, .watchOS, .visionOS]
                    )
                ),
            ],
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
            dependencies: ["PropertyListValue"],
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
