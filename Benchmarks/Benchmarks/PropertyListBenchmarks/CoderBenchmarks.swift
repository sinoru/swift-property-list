//
//  CoderBenchmarks.swift
//  PropertyListBenchmarks
//

import Benchmark
import Foundation
import PropertyList

/// The structure every coder benchmark encodes or decodes.
private let profile = Profile(
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
/// paths through `PropertyListValue(propertyList:)` — the Darwin branch reads an object by its
/// CoreFoundation type ID, and a Swift value has to be bridged to one first — so measuring the
/// native ones would be measuring an input the defaults system never produces.
private func stored() throws -> Any {
    let encoded = try PropertyListValueEncoder().encode(profile).propertyList
    let data = try PropertyListSerialization.data(
        fromPropertyList: encoded,
        format: .binary,
        options: 0
    )

    return try unsafe PropertyListSerialization.propertyList(from: data, format: nil)
}

/// The profile as `PropertyListEncoder` writes it, in the binary format.
private func encodedProfile() throws -> Data {
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary

    return try encoder.encode(profile)
}

/// A single stored integer, the smallest thing a decoder can be asked to read.
private let scalar: PropertyListValue = 42

/// An `Int` that reads itself, so that the decoder only a self-decoding type gets is made.
private struct Count: Decodable {
    /// The integer read.
    var value: Int

    /// Reads the integer through a single value container.
    init(from decoder: any Decoder) throws {
        value = try decoder.singleValueContainer().decode(Int.self)
    }
}

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
/// Cross-module optimization was measured and moves nothing here: what is being timed is calls into
/// Foundation, which is prebuilt and so inlines under no setting, and thrown errors, which no
/// setting elides.
func registerCoderBenchmarks() {
    // MARK: - Reading From Bytes

    // The pair after this one starts from an `Any`, which is what `UserDefaults` hands back. These
    // two start from bytes instead, which is every other way a property list arrives, and so ask a
    // different question: with no round trip on either side, is Foundation's scanner cheaper than
    // building the object graph and walking it?
    //
    // Nothing here goes through `PropertyListValue.init(from:)`. That path pays for a failed attempt
    // per case it rules out and loses to both of these by a wide margin; the reading benchmarks are
    // where that is measured, and where what the attempts do and do not cost is written down.

    // Bytes straight through Foundation's scanner.
    Benchmark("Decode bytes through Foundation") { benchmark, data in
        for _ in benchmark.scaledIterations {
            blackHole(try! PropertyListDecoder().decode(Profile.self, from: data))
        }
    } setup: {
        try encodedProfile()
    }

    // Bytes to an object graph, then to a tree, then decoded off the tree.
    Benchmark("Decode bytes through the value coder") { benchmark, data in
        for _ in benchmark.scaledIterations {
            let value = try! PropertyListSerialization.propertyListValue(from: data)
            blackHole(try! PropertyListValueDecoder().decode(Profile.self, from: value))
        }
    } setup: {
        try encodedProfile()
    }

    // MARK: - Reading From A Property List Object

    Benchmark("Decode a stored object through the value coder") { benchmark, stored in
        for _ in benchmark.scaledIterations {
            let value = PropertyListValue(propertyList: stored)!
            blackHole(try! PropertyListValueDecoder().decode(Profile.self, from: value))
        }
    } setup: {
        try stored()
    }

    // The path this replaced: serialize the stored object, then scan it back.
    Benchmark("Decode a stored object through Foundation") { benchmark, stored in
        for _ in benchmark.scaledIterations {
            let data = try! PropertyListSerialization.data(
                fromPropertyList: stored,
                format: .binary,
                options: 0
            )
            blackHole(try! PropertyListDecoder().decode(Profile.self, from: data))
        }
    } setup: {
        try stored()
    }

    // MARK: - Reading A Scalar

    // A stored scalar read on its own is what `UserDefaults` does most, and at that size the loop
    // around the read is a large share of what is measured. The first case is the loop and nothing
    // a decoder does, so that share can be taken out of the two after it. The type that decodes
    // itself reads the same `Int` through a decoder made for it, which is what the top level did
    // for every type before it read scalars without one; the gap between those two is what making
    // that decoder costs.

    Benchmark("Read a scalar without decoding") { benchmark in
        for _ in benchmark.scaledIterations {
            if case .integer(let value) = scalar {
                blackHole(value)
            }
        }
    }

    Benchmark("Decode a top-level scalar") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(try! PropertyListValueDecoder().decode(Int.self, from: scalar))
        }
    }

    Benchmark("Decode a top-level scalar through a decoder") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(try! PropertyListValueDecoder().decode(Count.self, from: scalar))
        }
    }

    // MARK: - Writing

    Benchmark("Encode through the value coder") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(try! PropertyListValueEncoder().encode(profile).propertyList)
        }
    }

    // The path this replaced, single-element array and all: `PropertyListEncoder` refuses a
    // top-level fragment, so the value went in wrapped and came back out unwrapped.
    Benchmark("Encode through Foundation") { benchmark in
        for _ in benchmark.scaledIterations {
            let data = try! PropertyListEncoder().encode([profile])
            let list = try! unsafe PropertyListSerialization.propertyList(from: data, format: nil)

            blackHole((list as? [Any])?.first)
        }
    }
}
