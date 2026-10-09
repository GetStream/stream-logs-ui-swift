//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Foundation
import StreamLogsUI

enum Subsystem: String, CaseIterable {
    case app
    case network
    case webSocket
    case cart
    case auth
}

extension LogEntry.Subsystem {
    init(_ subsystem: Subsystem) {
        self.init(rawValue: subsystem.rawValue)
    }
}

extension LogEntry.Level {
    static let security = LogEntry.Level(severity: 45, name: "SECURITY")
}

/// A minimal logger that sends its logs to the console and to the log viewer,
/// each with the level and subsystems chosen in the log viewer settings.
@MainActor
enum Log {
    private static let consoleID = "console"
    private static let logViewerID = "logViewer"
    private static var destinations: [LogDestinationSettings] = []

    static func setUp() {
        let settings = LogSettings.shared
        settings.availableSubsystems = Subsystem.allCases.map(LogEntry.Subsystem.init)
        settings.setDefaults([
            LogDestinationSettings(id: consoleID, name: "Console", level: .info),
            LogDestinationSettings(id: logViewerID, name: "Log Viewer", level: .trace)
        ])
        settings.apply { settings in
            destinations = settings.enabledDestinations
        }

        LogViewer.showsFloatingButton = true
        LogViewer.presentsOnShake = true
    }

    static func record(
        _ level: LogEntry.Level,
        _ subsystem: Subsystem,
        _ message: String,
        error: Error? = nil,
        metadata: [LogEntry.MetadataKey: String] = [:],
        function: StaticString = #function,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        let entry = LogEntry(
            date: Date(),
            level: level,
            subsystems: [LogEntry.Subsystem(subsystem)],
            threadName: "main",
            functionName: function,
            fileName: file,
            lineNumber: line,
            message: message,
            error: error,
            metadata: metadata
        )
        for destination in destinations where level >= destination.level {
            guard !destination.disabledSubsystems.contains(LogEntry.Subsystem(subsystem)) else { continue }
            if destination.id == logViewerID {
                InMemoryLogRecorder.shared.record(entry)
            } else {
                print("\(level.name) [\(subsystem.rawValue)] \(entry.message)")
            }
        }
    }
}
