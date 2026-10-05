//
//  Record.swift
//  PropertyListTestSupport
//

package import Foundation

/// A ``Profile`` together with the two kinds a property list stores natively.
///
/// `Date` and `Data` have `Codable` conformances of their own that write a number and a
/// sequence of bytes, and a property list coder is expected to bypass both and store each as
/// itself. Putting them one level down, next to a structure, is what makes a coder reach them
/// through a keyed container rather than only at the top.
package struct Record: Codable, Equatable, Sendable {
    /// The structure stored beside the two native kinds.
    package var profile: Profile
    /// When the record last changed, which a property list stores as a date.
    package var updatedAt: Date
    /// The bytes of a picture, which a property list stores as data.
    package var avatar: Data

    /// Creates a record from a profile, a date and bytes.
    package init(profile: Profile, updatedAt: Date, avatar: Data) {
        self.profile = profile
        self.updatedAt = updatedAt
        self.avatar = avatar
    }
}
