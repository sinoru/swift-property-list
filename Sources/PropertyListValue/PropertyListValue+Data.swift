//
//  PropertyListValue+Data.swift
//  PropertyList
//

import Foundation

extension PropertyListValue {
    /// Reads the bytes of a property list, in whichever format they are written.
    ///
    /// This is the way in for anything holding a whole property list — a file, a response body, a
    /// `WebResourceData` blob — and it is both the faster and the more faithful of the two:
    ///
    /// - **Faster than decoding.** ``init(from:)`` has to ask a `Decoder` for one case at a time
    ///   and pay a thrown `DecodingError` for each one that misses, which on a tree of about twenty
    ///   nodes came to roughly eight times the instructions this costs. The measurement is in
    ///   `PropertyListValueReadingPerformanceTests`.
    /// - **Faithful.** Reading goes through ``init(propertyList:)``, which asks
    ///   `CFNumberIsFloatType` and so keeps `<real>2</real>` as ``real(_:)``. ``init(from:)`` cannot
    ///   ask that question and reads the same bytes as ``integer(_:)``.
    ///
    /// What it is *not* is the fast way to a `Decodable` type. Building the object graph and
    /// walking it costs more than Foundation's scanner reading the bytes straight into the type —
    /// about 165,000 instructions against 137,000 on the same fixture, measured in
    /// `PropertyListCoderPerformanceTests`. Bytes with a type to read them into want
    /// `PropertyListDecoder`; this is for bytes whose shape the caller does not know in advance.
    ///
    /// (The reverse holds where the value starts as an `Any`, which is what `UserDefaults` returns:
    /// there the scanner has to be given bytes that do not exist yet, and serializing them costs
    /// more than the walk saves.)
    ///
    /// The pointer `PropertyListSerialization` wants for the format it detected is the only unsafe
    /// construct on this path, and it stops here: `nil` says the format is not wanted back, and no
    /// overload leaves the parameter out.
    ///
    /// - Parameter data: The bytes of a binary, XML, or OpenStep property list.
    /// - Throws: Whatever `PropertyListSerialization` throws for bytes that are not a property
    ///   list, or a `DecodingError/dataCorrupted(_:)` for one that is but holds something no case
    ///   here carries — a `CFKeyedArchiverUID`, which `NSKeyedArchiver` writes, being the one such
    ///   thing a property list is allowed to contain.
    public init(data: Data) throws {
        let object = try unsafe PropertyListSerialization.propertyList(from: data, format: nil)

        guard let value = Self(propertyList: object) else {
            // `DecodingError` rather than an error of this package's own, because it is what
            // `init(from:)` throws for the same condition, and a caller that reads property lists
            // both ways should not have to catch two spellings of one answer.
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: """
                        A property list holding a value no case of PropertyListValue carries.
                        """
                )
            )
        }

        self = value
    }
}
