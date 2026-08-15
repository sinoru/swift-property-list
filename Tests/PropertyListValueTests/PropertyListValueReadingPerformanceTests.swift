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
/// Nothing in this package's documentation rests on these numbers, and no API choice does either:
/// ``PropertyListValue/init(data:)`` is the way in for bytes because it keeps `<real>2.0</real>` a
/// real, which is a question of fidelity and would hold at any speed. The cases below are here so
/// the difference can be re-checked rather than assumed.
///
/// The shape of it: `PropertyListDecoder` reads bytes natively, scanning regions of the buffer with
/// no `NSString` or `NSNumber` in the way, and is the better machinery of the two.
/// `PropertyListSerialization` builds an Objective-C object graph that
/// ``PropertyListValue/init(propertyList:)`` then walks, bridging each node. The native reader
/// should win and does not, because a `Decoder` cannot be asked what a value is — only for it as
/// something — so a type-erased tree reaches every leaf through attempts that miss, and it loses
/// several times over on the misses alone. `testDeserializeOnly` splits the serialization side into
/// Foundation's share and this package's, so the comparison is not one opaque number against
/// another.
///
/// ## What a miss is not
///
/// It is tempting to read the gap as Foundation building a `DecodingError` message nobody will
/// read — the type name in `"Expected to decode ... but found ... instead."` comes out of runtime
/// metadata, and this initializer catches the error and drops it. That was measured and it is not
/// the answer. Throwing a `DecodingError` across a function boundary and catching it costs tens of
/// nanoseconds, and building the same error with a constant message instead of an interpolated one
/// costs the same to two significant figures. Holding the leaf count fixed and varying only the
/// number of misses per leaf prices a miss far above either. Whatever the attempts cost, it is
/// spent before Foundation decides to fail, not on the report of it.
///
/// Recorded so the theory is not re-derived from reading `DecodingError._typeMismatch` and believed
/// a second time.
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
