//
//  Vehicle.swift
//  PropertyListTestSupport
//

/// A class with a subclass, for the half of `Codable` that structures never reach.
///
/// A subclass that keeps keys of its own writes its superclass through `superEncoder()` and reads
/// it back through `superDecoder()`, and both land on a key — `super` — that no `CodingKey` the
/// caller wrote names. Two coders that are to read each other's output have to agree on that key,
/// and this pair is what asks them to.
package class Vehicle: Codable {
    package var kind: String

    package init(kind: String) {
        self.kind = kind
    }
}

package final class Car: Vehicle {
    package var doors: Int

    private enum CodingKeys: String, CodingKey {
        case doors
    }

    package init(kind: String, doors: Int) {
        self.doors = doors

        super.init(kind: kind)
    }

    package required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        doors = try container.decode(Int.self, forKey: .doors)

        try super.init(from: container.superDecoder())
    }

    package override func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(doors, forKey: .doors)

        try super.encode(to: container.superEncoder())
    }
}
