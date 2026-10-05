//
//  Theme.swift
//  PropertyListTestSupport
//
//  Created by Kang Jaehong on 7/18/26.
//

/// An enumeration backed by a string, which encodes to a single value rather than to a container.
package enum Theme: String, Codable, Equatable, Sendable {
    /// The light appearance.
    case light
    /// The dark appearance.
    case dark
}
