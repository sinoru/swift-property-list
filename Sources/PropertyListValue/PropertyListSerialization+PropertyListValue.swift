//
//  PropertyListSerialization+PropertyListValue.swift
//  PropertyList
//

import Foundation

extension PropertyListSerialization {
    /// Reads the bytes of a property list, in whichever format they are written, into a
    /// `PropertyListValue`.
    ///
    /// This is the way in for anything holding a whole property list — a file, a response body, a
    /// `WebResourceData` blob — and what it is for is fidelity. It sits beside
    /// `propertyList(from:options:format:)` because it does the same job and hands back a typed
    /// tree where that one hands back `Any`.
    ///
    /// A property list draws a distinction the format's two number elements make plain:
    /// `<real>2.0</real>` and `<integer>2</integer>` are different documents. Reading here goes
    /// through ``PropertyListValue/init(propertyList:)``, which asks `CFNumberIsFloatType` and so
    /// keeps the first as ``PropertyListValue/real(_:)``. ``PropertyListValue/init(from:)`` has no
    /// such question to ask — a `Decoder` says what a value can be read *as*, never what it was
    /// written *as* — and reads the same bytes as ``PropertyListValue/integer(_:)``. A tree read
    /// that way and written back out has changed the document.
    ///
    /// So this is the way in for bytes whose shape the caller does not know in advance. Bytes with
    /// a type to read them into want `PropertyListDecoder` and no tree in between; nothing here
    /// improves on handing Foundation the type it is going to fill.
    ///
    /// What fidelity cannot recover is what the bytes never held. An XML `<date>` has no place for
    /// a fraction of a second, so a date written to that format arrives here rounded down to the
    /// second; a binary property list stores the whole `Double` and hands it back.
    ///
    /// Two unsafe constructs sit on this path and neither escapes it. The pointer
    /// `propertyList(from:options:format:)` wants for the format it detected stops here: `nil` says
    /// the format is not wanted back, and no overload leaves the parameter out. The other is away
    /// from Darwin, where ``PropertyListValue/init(propertyList:)`` reads `NSNumber.objCType` to
    /// tell a real from an integer — a pointer to storage the number owns, read for one byte and
    /// not kept.
    ///
    /// - Parameter data: The bytes of a binary, XML, or OpenStep property list.
    /// - Returns: The property list the bytes hold.
    /// - Throws: Whatever `propertyList(from:options:format:)` throws for bytes that are not a
    ///   property list, or a `DecodingError/dataCorrupted(_:)` for one that is but holds something
    ///   no case of `PropertyListValue` carries — a `CFKeyedArchiverUID`, which `NSKeyedArchiver`
    ///   writes, being the one such thing a property list is allowed to contain.
    public static func propertyListValue(from data: Data) throws -> PropertyListValue {
        let object = try unsafe propertyList(from: data, format: nil)

        guard let value = PropertyListValue(propertyList: object) else {
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

        return value
    }
}
