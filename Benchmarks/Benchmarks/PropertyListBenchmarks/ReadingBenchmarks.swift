//
//  ReadingBenchmarks.swift
//  PropertyListBenchmarks
//

import Benchmark
import Foundation
import PropertyList

/// A tree shaped like a stored document rather than a single value: nested dictionaries and arrays
/// around the leaves, since the attempt order is only interesting once a value has something under
/// it.
private let tree: PropertyListValue = [
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

/// The tree as `PropertyListEncoder` writes it, in the binary format.
private func encodedTree() throws -> Data {
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary

    return try encoder.encode(tree)
}

/// What the ways to a ``PropertyListValue`` cost against each other.
///
/// Nothing in this package's documentation rests on these numbers, and no API choice does either:
/// `PropertyListSerialization.propertyListValue(from:)` is the way in for bytes because it keeps
/// `<real>2.0</real>` a real, which is a question of fidelity and would hold at any speed. The
/// cases below are here so the difference can be re-checked rather than assumed.
///
/// The shape of it: `PropertyListDecoder` reads bytes natively, scanning regions of the buffer with
/// no `NSString` or `NSNumber` in the way, and is the better machinery of the two.
/// `PropertyListSerialization` builds an object graph that
/// ``PropertyListValue/init(propertyList:)`` then walks, bridging each node. The native reader
/// should win and does not, because a `Decoder` cannot be asked what a value is — only for it as
/// something — so a type-erased tree reaches every leaf through attempts that miss, and it loses
/// several times over on the misses alone. The deserialization on its own, and the walk on its own,
/// split the serialization side into Foundation's share and this package's, so the comparison is
/// not one opaque number against another.
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
/// ## What is walked
///
/// The walk is measured over two inputs because they take different roads. What
/// `PropertyListSerialization` and `UserDefaults` hand back is already objects on Darwin, and is
/// read by its CoreFoundation type ID as it stands. A tree of Swift values — one a caller built by
/// hand, or read back from ``PropertyListValue/propertyList`` — has to be bridged to those objects
/// first there, and pays for it in its collections. The leaves on their own show what that costs
/// where there is no collection to bridge.
func registerReadingBenchmarks() {
    // Bytes to tree in one pass, through the attempt cascade.
    Benchmark("Read bytes through Decodable") { benchmark, data in
        for _ in benchmark.scaledIterations {
            blackHole(try! PropertyListDecoder().decode(PropertyListValue.self, from: data))
        }
    } setup: {
        try encodedTree()
    }

    // Bytes to `Any` to tree, through the initializer that does it: the path that keeps a
    // whole-valued `<real>` as a real.
    Benchmark("Read bytes through PropertyListSerialization") { benchmark, data in
        for _ in benchmark.scaledIterations {
            blackHole(try! PropertyListSerialization.propertyListValue(from: data))
        }
    } setup: {
        try encodedTree()
    }

    // The serialization step on its own, so the number above can be split into the part Foundation
    // spends building the object graph and the part this package spends walking it.
    Benchmark("Deserialize bytes without walking") { benchmark, data in
        for _ in benchmark.scaledIterations {
            blackHole(try! unsafe PropertyListSerialization.propertyList(from: data, format: nil))
        }
    } setup: {
        try encodedTree()
    }

    // The other half of that split: the graph Foundation built, walked and nothing else.
    Benchmark("Walk an object graph") { benchmark, object in
        for _ in benchmark.scaledIterations {
            blackHole(PropertyListValue(propertyList: object))
        }
    } setup: {
        try unsafe PropertyListSerialization.propertyList(from: encodedTree(), format: nil)
    }

    Benchmark("Walk a tree of Swift values") { benchmark, object in
        for _ in benchmark.scaledIterations {
            blackHole(PropertyListValue(propertyList: object))
        }
    } setup: {
        tree.propertyList
    }

    Benchmark("Walk Swift leaves") { benchmark, leaves in
        for _ in benchmark.scaledIterations {
            for leaf in leaves {
                blackHole(PropertyListValue(propertyList: leaf))
            }
        }
    } setup: {
        [
            1,
            "swift",
            true,
            1.5,
            Data([1, 2, 3]),
            Date(timeIntervalSinceReferenceDate: 0),
        ] as [Any]
    }
}
