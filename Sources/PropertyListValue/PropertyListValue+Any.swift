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
        self.init(object: value as AnyObject)
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
    /// What `CFGetTypeID` sends an object that is not CoreFoundation's own. No header declares it;
    /// CoreFoundation's sources and the Swift runtime's are where it is written down.
    private static let typeIDSelector = Selector(("_cfTypeID"))

    /// Reads an object by its CoreFoundation type ID.
    ///
    /// The type ID is asked first because bridged casts are too permissive, and too slow. Darwin
    /// hands every number back as an `NSNumber`, booleans included, and `NSNumber(value: 1) as? Bool`
    /// succeeds — so a ladder of Swift casts cannot tell `<true/>` from `<integer>1</integer>`, and
    /// each rung a value is turned down by runs the dynamic cast machinery again. One switch
    /// settles the class; each branch then force-casts to it, which cannot fail, and bridges from
    /// there.
    ///
    /// The class is asked whether it answers `_cfTypeID` before the object is asked for a type ID.
    /// `CFGetTypeID` answers for a CoreFoundation object itself and sends every other one that
    /// message, which `NSObject` and Swift's own root class implement and `NSProxy` does not: a
    /// proxy forwards it or raises, and either way an object that is not a property list would
    /// bring the process down rather than read as `nil`. Asking the object anything — `is
    /// NSObject` is `isKindOfClass:` — would be forwarded just the same. The runtime answers for
    /// the class without a message being sent, and the question is the one `CFGetTypeID` is about
    /// to depend on.
    private init?(object: AnyObject) {
        guard class_respondsToSelector(object_getClass(object), Self.typeIDSelector) else {
            return nil
        }

        switch CFGetTypeID(object) {
        case CFStringGetTypeID():
            self = .string((object as! NSString) as String)
        case CFBooleanGetTypeID():
            self = .bool(object === kCFBooleanTrue)
        case CFNumberGetTypeID():
            let number = object as! NSNumber

            // Asked before the integer casts. `NSNumber` bridging succeeds whenever the value is
            // exactly representable, so a stored `<real>2</real>` would otherwise pass `as? Int64`
            // and arrive as an integer.
            if CFNumberIsFloatType(number) {
                self = .real(number.doubleValue)
                return
            }

            // That same exactness check is what makes this ordering safe: a value above `Int64.max`
            // fails the first cast and reaches the second rather than coming back truncated.
            if let value = number as? Int64 {
                self = .integer(value)
            } else if let value = number as? UInt64 {
                self = .unsignedInteger(value)
            } else {
                return nil
            }
        case CFDataGetTypeID():
            self = .data((object as! NSData) as Data)
        case CFDateGetTypeID():
            self = .date((object as! NSDate) as Date)
        case CFArrayGetTypeID():
            let elements = object as! NSArray
            var array = [PropertyListValue]()
            array.reserveCapacity(elements.count)

            for element in elements {
                guard let element = PropertyListValue(object: element as AnyObject) else {
                    return nil
                }

                array.append(element)
            }

            self = .array(array)
        case CFDictionaryGetTypeID():
            // Walked where it stands. Casting to `[String: Any]` first would build a Swift
            // dictionary only for this one to be built from it. The stop pointer is the block's
            // own, written once and not kept.
            let elements = object as! NSDictionary
            var dictionary = [String: PropertyListValue](minimumCapacity: elements.count)
            var isPropertyList = true

            unsafe elements.enumerateKeysAndObjects { key, element, stop in
                guard
                    let key = key as? NSString,
                    let element = PropertyListValue(object: element as AnyObject)
                else {
                    isPropertyList = false
                    unsafe stop.pointee = true
                    return
                }

                dictionary[key as String] = element
            }

            guard isPropertyList else { return nil }

            self = .dictionary(dictionary)
        default:
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
