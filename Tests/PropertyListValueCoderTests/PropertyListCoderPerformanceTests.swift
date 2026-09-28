//
//  PropertyListCoderPerformanceTests.swift
//  PropertyListValueCoderTests
//

// XCTest rather than the testing library: measurement has no equivalent there, and the two coexist
// in one target. Darwin only, because `XCTMetric` does — swift-corelibs-xctest has no
// `measure(metrics:)` to call.
#if canImport(Darwin)
import Foundation
import PropertyListTestSupport
import XCTest

import PropertyListValue
import PropertyListValueCoder

/// What this package's coder costs against the two hops it replaced.
///
/// The claim the coder was built on is that reading a stored value through `PropertyListDecoder`
/// meant serializing it to `Data` and scanning that back first, and that writing meant the reverse
/// plus a single-element array to get past the top-level fragment restriction. Both of those paths
/// are reconstructed here so the claim is a number rather than an argument.
///
/// The bytes pair answers a separate question, and answers it against this package: with a
/// `Decodable` type already in hand there is nothing for a tree to do, and handing Foundation the
/// type it is going to fill beats building the tree and walking it. No documentation quotes the
/// margin — the guidance it supports holds without one — but the cases are kept so the guidance is
/// checkable rather than asserted.
///
/// Every case is skipped in a debug build, where an unoptimized measurement says nothing about
/// anything, so an ordinary `swift test` is untouched and no environment variable has to be
/// remembered. Measure in release:
///
///     swift test -c release --filter PropertyListCoderPerformanceTests
///
/// No `-enable-testing`, because nothing here needs a `@testable import` — asking for one would
/// publish the internal symbols of the very module being timed. It was measured both ways and
/// moves nothing, and neither does `-cross-module-optimization`: what is being timed is calls into
/// Foundation, which is prebuilt and so inlines under no setting, and thrown errors, which none of
/// them elides.
///
/// Read instructions retired rather than elapsed time: the work here is small enough that the clock
/// varies by more between runs than the difference being measured.
///
/// Nothing here fails on a regression. There is no baseline to fail against — a number means
/// something next to the number beside it, not next to one from another machine.
final class PropertyListCoderPerformanceTests: XCTestCase {
    /// A value with enough shape to be worth encoding: a dictionary, a nested array, and a string
    /// that is not the same length as its key.
    private static let profile = Profile(
        name: "Jane Doe",
        age: 30,
        tags: ["swift", "macOS", "property-list"],
        nickname: "Janie"
    )

    /// The stored form, as `object(forKey:)` would hand it back.
    ///
    /// Round-tripped through `PropertyListSerialization` rather than handed over as the encoder left
    /// it, and that is the whole point of it: the encoder produces Swift-native types, while the
    /// defaults system produces `__NSCFDictionary`, `NSString` and `NSNumber`. Those take different
    /// paths through `PropertyListValue(propertyList:)` — the Darwin branch is written around
    /// `NSNumber` and `CFGetTypeID` — so measuring the native ones would be measuring an input this
    /// package never sees.
    ///
    /// A local rather than a static, because `Any` carries no `Sendable` and a property list object
    /// cannot be given one — a static would need an opt-out, and reading it inside the measured
    /// block would then need marking as unsafe on every line. Building it costs one encode and one
    /// round trip outside the block, neither of which is being timed.
    private func stored() throws -> Any {
        let encoded = try PropertyListValueEncoder().encode(Self.profile).propertyList
        let data = try PropertyListSerialization.data(
            fromPropertyList: encoded,
            format: .binary,
            options: 0
        )

        return try unsafe PropertyListSerialization.propertyList(from: data, format: nil)
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

    // MARK: - Reading From Bytes

    // The pair below starts from an `Any`, which is what `UserDefaults` hands back. These two start
    // from bytes instead, which is every other way a property list arrives, and so ask a different
    // question: with no round trip on either side, is Foundation's scanner cheaper than building
    // the object graph and walking it?
    //
    // Nothing here goes through `PropertyListValue.init(from:)`. That path pays for a failed attempt
    // per case it rules out and loses to both of these by a wide margin;
    // `PropertyListValueReadingPerformanceTests` is where that is measured, and where what the
    // attempts do and do not cost is written down.

    private static func encodedProfile() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary

        return try encoder.encode(profile)
    }

    /// Bytes straight through Foundation's scanner.
    func testDecodeFromDataThroughFoundation() throws {
        let data = try Self.encodedProfile()
        var decoded = 0

        measure(metrics: metrics) {
            for _ in 0 ..< Self.iterations {
                decoded += try! PropertyListDecoder().decode(Profile.self, from: data).age
            }
        }

        XCTAssertGreaterThan(decoded, 0)
    }

    /// Bytes to an object graph, then to a tree, then decoded off the tree.
    func testDecodeFromDataThroughTheValueCoder() throws {
        let data = try Self.encodedProfile()
        var decoded = 0

        measure(metrics: metrics) {
            for _ in 0 ..< Self.iterations {
                let value = try! PropertyListSerialization.propertyListValue(from: data)
                decoded += try! PropertyListValueDecoder().decode(Profile.self, from: value).age
            }
        }

        XCTAssertGreaterThan(decoded, 0)
    }

    // MARK: - Reading From A Property List Object

    func testDecodeThroughTheValueCoder() throws {
        let stored = try stored()
        var decoded = 0

        measure(metrics: metrics) {
            for _ in 0 ..< Self.iterations {
                let value = PropertyListValue(propertyList: stored)!
                decoded += try! PropertyListValueDecoder().decode(Profile.self, from: value).age
            }
        }

        // A measurement whose work was optimized away reports excellent numbers.
        XCTAssertGreaterThan(decoded, 0)
    }

    /// The path this replaced: serialize the stored object, then scan it back.
    func testDecodeThroughFoundation() throws {
        let stored = try stored()
        var decoded = 0

        measure(metrics: metrics) {
            for _ in 0 ..< Self.iterations {
                let data = try! PropertyListSerialization.data(
                    fromPropertyList: stored,
                    format: .binary,
                    options: 0
                )
                decoded += try! PropertyListDecoder().decode(Profile.self, from: data).age
            }
        }

        XCTAssertGreaterThan(decoded, 0)
    }

    // MARK: - Reading A Scalar

    // A stored scalar read on its own is what `UserDefaults` does most, and at that size the loop
    // around the read is a large share of what is measured. The empty loop is here so that share
    // can be taken out: a case's cost per read is its number less that one, divided by the
    // iterations. The type that decodes itself reads the same `Int` through a decoder made for
    // it, which is what the top level did for every type before it read scalars without one; the
    // gap between those two is what making that decoder costs.

    private static let scalar: PropertyListValue = 42

    /// An `Int` that reads itself, so that the decoder only a self-decoding type gets is made.
    private struct Count: Decodable {
        var value: Int

        init(from decoder: any Decoder) throws {
            value = try decoder.singleValueContainer().decode(Int.self)
        }
    }

    /// The loop and nothing a decoder does, for the cases below to be read against.
    func testReadAScalarWithoutDecoding() {
        var total = 0

        measure(metrics: metrics) {
            for _ in 0 ..< Self.iterations {
                if case .integer(let value) = Self.scalar {
                    total &+= Int(value)
                }
            }
        }

        XCTAssertGreaterThan(total, 0)
    }

    func testDecodeATopLevelScalar() {
        var total = 0

        measure(metrics: metrics) {
            for _ in 0 ..< Self.iterations {
                total += try! PropertyListValueDecoder().decode(Int.self, from: Self.scalar)
            }
        }

        XCTAssertGreaterThan(total, 0)
    }

    func testDecodeATopLevelScalarThroughADecoder() {
        var total = 0

        measure(metrics: metrics) {
            for _ in 0 ..< Self.iterations {
                total += try! PropertyListValueDecoder().decode(Count.self, from: Self.scalar).value
            }
        }

        XCTAssertGreaterThan(total, 0)
    }

    // MARK: - Writing

    func testEncodeThroughTheValueCoder() {
        var encoded = 0

        measure(metrics: metrics) {
            for _ in 0 ..< Self.iterations {
                let value = try! PropertyListValueEncoder().encode(Self.profile).propertyList
                encoded += (value as? [String: Any])?.count ?? 0
            }
        }

        XCTAssertGreaterThan(encoded, 0)
    }

    /// The path this replaced, single-element array and all: `PropertyListEncoder` refuses a
    /// top-level fragment, so the value went in wrapped and came back out unwrapped.
    func testEncodeThroughFoundation() {
        var encoded = 0

        measure(metrics: metrics) {
            for _ in 0 ..< Self.iterations {
                let data = try! PropertyListEncoder().encode([Self.profile])
                let list = try! unsafe PropertyListSerialization.propertyList(from: data, format: nil)
                let value = (list as? [Any])?.first

                encoded += (value as? [String: Any])?.count ?? 0
            }
        }

        XCTAssertGreaterThan(encoded, 0)
    }
}
#endif
