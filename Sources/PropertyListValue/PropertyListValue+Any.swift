//
//  PropertyListValue+Any.swift
//  PropertyList
//

// Foundation itself, not FoundationEssentials: `NSNumber` and `PropertyListSerialization` live only
// in the former, which is the module that brings ICU along with it. Where FoundationEssentials can
// be imported this waits for the `ValueFoundation` trait, so a package that never reaches for the
// `Any` the defaults system deals in links none of it. Where it cannot — Darwin, or a toolchain
// whose Foundation is still one piece — the rest of the module imports Foundation anyway, and this
// costs nothing more. Asked of the platform being built for rather than decided in the manifest,
// whose `#if` answers for the host and would get a cross-compile wrong.
#if ValueFoundation || !canImport(FoundationEssentials)

#if canImport(ObjectiveC)
import CoreFoundationKit
#endif
import Foundation

extension PropertyListValue {
    /// Reads the `Any` that `UserDefaults.object(forKey:)` and `PropertyListSerialization` deal in.
    ///
    /// This is the one place that knows what those hand back, and it differs by platform: Darwin
    /// returns Objective-C objects, and swift-corelibs-foundation returns Swift ones. Keeping the
    /// difference here is what lets everything above it read a `PropertyListValue` and stop caring.
    ///
    /// - Parameter value: A property list value. Anything else — a type the format cannot hold, or a
    ///   collection with one nested somewhere inside it — is not one, and yields `nil`.
    public init?(propertyList value: Any) {
#if canImport(ObjectiveC)
        // Everything Darwin hands back is already an object, and a Swift value a caller built by
        // hand bridges to the same classes, so one question about the object answers for both.
        //
        // The object is a caller's, so it is read with the initializer that turns a proxy away:
        // one reads as `nil`, as anything else that is not a property list does, rather than
        // being sent a message it would raise on.
        guard let value = CoreFoundationValue(value as AnyObject) else { return nil }

        self.init(value)
#else
        // Numbers first, and not for tidiness. Each `as?` against an `Any` runs the dynamic cast
        // machinery, and the two collection ones run the most of it — a stored number reaching the
        // number case had to be turned down by `as? [String: Any]` on the way, which measured as the
        // largest single cost in reading one. A number is also the thing most often asked for.
        //
        // Nothing else can answer to a number, so moving this cannot change what any value reads as:
        // the test is a single check against `NSNumber`, which a string or a collection fails as
        // surely here as it did below.
        if let value = PropertyListValue(number: value) {
            self = value
            return
        }

        switch value {
        case let value as String:
            self = .string(value)
        case let value as Data:
            self = .data(value)
        case let value as Date:
            self = .date(value)
        case let value as [Any]:
            var array = [PropertyListValue]()
            array.reserveCapacity(value.count)

            for element in value {
                guard let element = PropertyListValue(propertyList: element) else { return nil }

                array.append(element)
            }

            self = .array(array)
        case let value as [String: Any]:
            var dictionary = [String: PropertyListValue](minimumCapacity: value.count)

            for (key, element) in value {
                guard let element = PropertyListValue(propertyList: element) else { return nil }

                dictionary[key] = element
            }

            self = .dictionary(dictionary)
        // swift-corelibs-foundation bridges an `NSArray` to `[Any]` through a cast, and on WASI
        // that cast fails where it succeeds on Linux, so an array a caller built as an `NSArray`
        // would otherwise read as nothing at all. `NSArray` is a sequence of its elements
        // everywhere, and copying it out is what the cast would have done. Only an array needs
        // this: an `NSDictionary` casts to `[String: Any]` there, and every other case unboxes
        // through its own cast above.
        case let value as NSArray:
            guard let array = PropertyListValue(propertyList: Array(value)) else { return nil }

            self = array
        default:
            return nil
        }
#endif
    }

#if canImport(ObjectiveC)
    /// Reads an object that has been told apart by its CoreFoundation type ID.
    ///
    /// The type ID is asked rather than a ladder of Swift casts climbed, because bridged casts are
    /// too permissive, and too slow. Darwin hands every number back as an `NSNumber`, booleans
    /// included, and `NSNumber(value: 1) as? Bool` succeeds — so the casts cannot tell `<true/>`
    /// from `<integer>1</integer>`, and each rung a value is turned down by runs the dynamic cast
    /// machinery again. `CoreFoundationValue` settles the type once and hands each branch what it
    /// needs to read from there.
    ///
    /// A collection is a sequence of its elements, each already told apart the way the collection
    /// was, so it is walked where it stands: casting to `[Any]` or `[String: Any]` first would
    /// build a Swift collection only for this one to be built from it. A proxy found inside one
    /// arrives as an object of another type, and reads as `nil` like any other.
    private init?(_ value: CoreFoundationValue) {
        switch value {
        case .string(let string):
            self = .string(string as String)
        case .boolean(let bool):
            self = .bool(bool)
        case .number(let number):
            // Whether the number is floating-point is asked before its value is, so a stored
            // `<real>2</real>` stays a real, and an integer above `Int64.max` arrives unsigned
            // rather than truncated. Both are `CoreFoundationValue.Number`'s to get right.
            switch CoreFoundationValue.Number(number) {
            case .integer(let value)?:
                self = .integer(value)
            case .unsignedInteger(let value)?:
                self = .unsignedInteger(value)
            case .floatingPoint(let value)?:
                self = .real(value)
            case nil:
                return nil
            }
        case .data(let data):
            self = .data(data as Data)
        case .date(let date):
            self = .date(date as Date)
        case .array(let elements):
            var array = [PropertyListValue]()
            array.reserveCapacity(elements.count)

            for element in elements {
                guard let element = PropertyListValue(element) else { return nil }

                array.append(element)
            }

            self = .array(array)
        case .dictionary(let elements):
            var dictionary = [String: PropertyListValue](minimumCapacity: elements.count)

            for (key, element) in elements {
                guard case .string(let key) = key, let element = PropertyListValue(element) else {
                    return nil
                }

                dictionary[key as String] = element
            }

            self = .dictionary(dictionary)
        case .other:
            return nil
        }
    }
#else
    /// Reads the numbers, which swift-corelibs-foundation hands back in a shape of its own.
    private init?(number value: Any) {
        // swift-corelibs-foundation unboxes exactly two things on its way out of
        // `PropertyListSerialization` — the `CFBoolean` singletons, which become a Swift `Bool` —
        // and hands everything else back as it built it. Every number therefore arrives as an
        // `NSNumber`, which conforms to none of Swift's numeric protocols, so asking for one of
        // those matches nothing at all. Bridging to `NSNumber` first is what puts the value where
        // it can be asked about, and it takes a Swift-native number just as well: a caller building
        // an `Any` tree by hand, or reading one back from ``propertyList``, lands here too.
        guard let value = value as? NSNumber else { return nil }

        switch unsafe value.objCType.pointee {
        case CChar(UInt8(ascii: "f")), CChar(UInt8(ascii: "d")):
            // What stands in for `CFNumberIsFloatType` here. corelibs imports CoreFoundation
            // `@_implementationOnly` and its `NSNumber` is not toll-free bridged, so that function
            // cannot be reached with this value even where the module can be imported.
            //
            // Asked before the integer casts for the same reason Darwin asks its question first: a
            // stored `<real>2</real>` casts to `Int64` exactly, and would otherwise arrive as an
            // integer.
            self = .real(value.doubleValue)
        case CChar(UInt8(ascii: "c")) where value === (true as NSNumber) || value === (false as NSNumber):
            // A boolean and a one-byte integer are the same spelling in `objCType`, and identity
            // against the singletons is what separates them. Both ways in reach it: a `<true/>` the
            // serializer already turned into a Swift `Bool` bridges back to the same singleton, and
            // so does an `NSNumber(value: true)` a caller made. An integer that happens to be one
            // byte wide fails the guard and falls through to the casts below, which is where it
            // belongs.
            self = .bool(value.boolValue)
        default:
            // The exactness of `NSNumber`'s bridging is what makes this ordering safe: a value above
            // `Int64.max` fails the first cast and reaches the second rather than coming back
            // truncated. Anything wider than either carrier is refused, which is the reason to ask
            // in this order at all.
            if let value = value as? Int64 {
                self = .integer(value)
            } else if let value = value as? UInt64 {
                self = .unsignedInteger(value)
            } else {
                return nil
            }
        }
    }
#endif

    /// The `Any` to hand `UserDefaults.set(_:forKey:)`.
    ///
    /// Both platforms take the Swift types this produces: Darwin bridges them, and
    /// swift-corelibs-foundation's own `set(_:forKey:)` accepts each one by name.
    public var propertyList: Any {
        switch self {
        case .dictionary(let value):
            return value.mapValues(\.propertyList)
        case .array(let value):
            return value.map(\.propertyList)
        case .string(let value):
            return value
        case .data(let value):
            return value
        case .date(let value):
            return value
        case .bool(let value):
            return value
        case .integer(let value):
            // Narrowed to `Int` where it fits, which is every value but the far ends of the range.
            // Both spellings store the same number, and on Darwin both bridge to the same
            // `NSNumber`; the difference shows on Linux, where `Int64` is a separate type and
            // anyone reading `object(forKey:)` with an `as? Int` of their own would miss it.
            if let value = Int(exactly: value) {
                return value
            }

            return value
        case .unsignedInteger(let value):
            return value
        case .real(let value):
            return value
        }
    }
}

#endif
