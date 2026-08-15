//
//  PropertyListValue+Data.swift
//  PropertyList
//

import Foundation

extension PropertyListValue {
    /// Reads the bytes of a property list, in whichever format they are written.
    ///
    /// This is the way in for anything holding a whole property list — a file, a response body, a
    /// `WebResourceData` blob — and what it is for is fidelity.
    ///
    /// A property list draws a distinction the format's two number elements make plain:
    /// `<real>2.0</real>` and `<integer>2</integer>` are different documents. Reading here goes
    /// through ``init(propertyList:)``, which asks `CFNumberIsFloatType` and so keeps the first as
    /// ``real(_:)``. ``init(from:)`` has no such question to ask — a `Decoder` says what a value can
    /// be read *as*, never what it was written *as* — and reads the same bytes as ``integer(_:)``.
    /// A tree read that way and written back out has changed the document.
    ///
    /// So this is the way in for bytes whose shape the caller does not know in advance. Bytes with
    /// a type to read them into want `PropertyListDecoder` and no tree in between; nothing here
    /// improves on handing Foundation the type it is going to fill.
    ///
    /// Two unsafe constructs sit on this path and neither escapes it. The pointer
    /// `PropertyListSerialization` wants for the format it detected stops here: `nil` says the
    /// format is not wanted back, and no overload leaves the parameter out. The other is away from
    /// Darwin, where ``init(propertyList:)`` reads `NSNumber.objCType` to tell a real from an
    /// integer — a pointer to storage the number owns, read for one byte and not kept.
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
