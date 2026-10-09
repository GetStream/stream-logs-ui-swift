//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Foundation

public extension LogEntry {
    /// The name of a subsystem a log entry belongs to.
    ///
    /// The predefined subsystems are shared by Stream products. A product adds its own as static members,
    /// and any other name is created from its raw value, for example `LogEntry.Subsystem(rawValue: "Checkout")`.
    /// Subsystems with the same name are equal. Exported sessions store the name.
    struct Subsystem: Hashable, RawRepresentable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible, Comparable {
        /// The subsystem name, like `httpRequests`.
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: String) {
            self.init(rawValue: value)
        }

        public var description: String { rawValue }

        /// Logs that don't belong to another subsystem.
        public static let other = Subsystem(rawValue: "other")
        /// Logs written while reading or writing the local database.
        public static let database = Subsystem(rawValue: "database")
        /// Logs of HTTP requests.
        public static let httpRequests = Subsystem(rawValue: "httpRequests")
        /// Logs of WebSocket events.
        public static let webSocket = Subsystem(rawValue: "webSocket")

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}
