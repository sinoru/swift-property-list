//
//  PropertyListValueReadingPerformanceTests.swift
//  PropertyListTests
//

// XCTest rather than the testing library: measurement has no equivalent there, and the two coexist
// in one target. Darwin only, because `XCTMetric` does — swift-corelibs-xctest has no
// `measure(metrics:)` to call.
#if canImport(Darwin)
import Foundation
import PropertyListTestSupport
import XCTest

import PropertyListValue

/// What the two ways from bytes to a ``PropertyListValue`` cost against each other.
///
/// ``PropertyListValue/init(from:)`` exists on the claim that `PropertyListDecoder` reads the bytes
/// in Swift, over regions of the buffer, while `PropertyListSerialization` builds a graph of
/// `NSString`, `NSNumber` and `NSDictionary` that ``PropertyListValue/init(propertyList:)`` then
/// walks with a dynamic cast per node. Against that, the decoder pays for a thrown `DecodingError`
/// on every attempt that misses, and there are up to eight of them per value. Which side wins is
/// the question this answers.
///
/// Every case is skipped in a debug build, where an unoptimized measurement says nothing about
/// anything, so an ordinary `swift test` is untouched. Measure in release:
///
///     swift test -c release --filter PropertyListValueReadingPerformanceTests
///
/// No `-enable-testing`, and no `-cross-module-optimization` either: both were measured and both
/// move nothing here, since the work is calls into a prebuilt Foundation and errors thrown on the
/// way, neither of which any of those settings reaches.
///
/// Read instructions retired rather than elapsed time: the work here is small enough that the clock
/// varies by more between runs than the difference being measured.
///
/// Nothing here fails on a regression. There is no baseline to fail against — a number means
/// something next to the number beside it, not next to one from another machine.
final class PropertyListValueReadingPerformanceTests: XCTestCase {
    /// A tree shaped like a stored document rather than a single value: nested dictionaries and
    /// arrays around the leaves, since the attempt order is only interesting once a value has
    /// something under it.
    private static let tree: PropertyListValue = [
        "version": 1,
        "generator": "swift-property-list",
        "resources": [
            [
                "url": "https://example.com/a.png",
                "mimeType": "image/png",
                "bytes": 2048,
                "inline": true,
                "ratio": 1.5,
            ],
            [
                "url": "https://example.com/b.css",
                "mimeType": "text/css",
                "bytes": 512,
                "inline": false,
                "ratio": 0.25,
            ],
        ],
        "tags": ["swift", "macOS", "property-list"],
    ]

    private static func encodedTree() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary

        return try encoder.encode(tree)
    }

    /// Built fresh per call: `XCTMetric` is not `Sendable`, so one shared array could not be a
    /// static, and a metric is free to carry state from the run it just took part in.
    private var metrics: [any XCTMetric] {
        [XCTClockMetric(), XCTCPUMetric()]
    }

    private static let iterations = 1_000

    override func setUpWithError() throws {
        #if DEBUG
        throw XCTSkip("Measurements only mean something optimized; build for release.")
        #else
        try XCTSkipIf(
            threadSanitizerIsLoaded,
            "A measurement taken under ThreadSanitizer would not mean anything."
        )
        #endif
    }

    /// Bytes to tree in one pass, through the attempt cascade.
    func testReadThroughDecodable() throws {
        let data = try Self.encodedTree()
        var read = 0

        measure(metrics: metrics) {
            for _ in 0 ..< Self.iterations {
                let value = try! PropertyListDecoder().decode(PropertyListValue.self, from: data)
                read += value["resources"]?.array?.count ?? 0
            }
        }

        // A measurement whose work was optimized away reports excellent numbers.
        XCTAssertGreaterThan(read, 0)
    }

    /// Bytes to `Any` to tree, through the initializer that does it: the path that keeps a
    /// whole-valued `<real>` as a real.
    func testReadThroughData() throws {
        let data = try Self.encodedTree()
        var read = 0

        measure(metrics: metrics) {
            for _ in 0 ..< Self.iterations {
                let value = try! PropertyListValue(data: data)
                read += value["resources"]?.array?.count ?? 0
            }
        }

        XCTAssertGreaterThan(read, 0)
    }

    /// The serialization step on its own, so the number above can be split into the part Foundation
    /// spends building the object graph and the part this package spends walking it.
    func testDeserializeOnly() throws {
        let data = try Self.encodedTree()
        var read = 0

        measure(metrics: metrics) {
            for _ in 0 ..< Self.iterations {
                let object = try! unsafe PropertyListSerialization.propertyList(
                    from: data,
                    format: nil
                )
                read += (object as? [String: Any])?.count ?? 0
            }
        }

        XCTAssertGreaterThan(read, 0)
    }
}
#endif
