// swift-tools-version: 6.3

import PackageDescription

// A package of its own rather than a target of the one above it, so that nothing a consumer
// resolves ever includes the benchmark harness: the manifest they read has no dependencies, and
// this one is only ever opened from inside this directory.
let package = Package(
    name: "Benchmarks",
    // The harness's floor, not the library's. The library deploys further back than this and is
    // not held to it by being measured here.
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        // `ValueFoundation` on top of the defaults: the bridge to Foundation's `Any` is half of what
        // is measured, and away from Apple platforms it is not compiled without being asked for.
        .package(path: "../", traits: [.defaults, "ValueFoundation"]),
        .package(url: "https://github.com/ordo-one/benchmark.git", from: "1.36.4"),
    ],
    targets: [
        .executableTarget(
            name: "PropertyListBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "PropertyList", package: "swift-property-list"),
            ],
            path: "Benchmarks/PropertyListBenchmarks",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("ImmutableWeakCaptures"),
                .strictMemorySafety(),
            ],
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark"),
            ]
        ),
    ]
)
