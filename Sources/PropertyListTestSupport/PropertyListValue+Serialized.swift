//
//  PropertyListValue+Serialized.swift
//  PropertyListTestSupport
//

import Foundation
import PropertyListValue

extension PropertyListValue {
    /// The bytes `PropertyListEncoder` writes this value as, in the given format.
    ///
    /// What a test reaches for when it needs the bytes of a property list and does not care how
    /// they were made — only that Foundation made them, so that reading them back takes the path a
    /// stored file or a `WebResourceData` blob would take.
    ///
    /// `PropertyListEncoder` refuses a top-level fragment, so a scalar has to be put in a container
    /// before it comes here. A test that wants a scalar at the top writes its XML by hand instead.
    package func serialized(
        as format: PropertyListSerialization.PropertyListFormat
    ) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = format

        return try encoder.encode(self)
    }
}
