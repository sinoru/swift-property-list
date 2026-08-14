# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `PropertyListValue`, an enum over the shapes a property list can hold, bridging
  to and from the `Any` tree that `UserDefaults` and `PropertyListSerialization`
  deal in. `bool` stays distinct from `integer`, and `unsignedInteger` covers only
  what `Int64` cannot hold.
- Literal, subscript, description, and `Data` conveniences for `PropertyListValue`,
  along with its `Encodable` and `Decodable` conformances.
- `PropertyListValueEncoder` and `PropertyListValueDecoder`, a `Codable` pair that
  reads and writes a `PropertyListValue` tree directly instead of round-tripping
  through serialized bytes. Numbers convert across integer and real at every depth.
- The `Value` and `ValueCoder` package traits, both enabled by default, so a
  consumer that only reads a property list can skip the coder machinery.

[Unreleased]: https://github.com/sinoru/swift-property-list/commits/main
