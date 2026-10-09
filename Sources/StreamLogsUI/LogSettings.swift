//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Combine
import Foundation

/// Logger configuration that can be changed at runtime from ``LogSettingsView``.
///
/// Every destination, e.g. the console or the log viewer, has its own level and subsystems.
/// Changes are saved in `UserDefaults` and restored on the next launch. Destinations that keep their default values
/// follow the defaults set with ``setDefaults(_:)``, even when those change in a later build.
/// The settings don't depend on any logger. Use ``apply(_:)`` to update the app's logger whenever they change.
@MainActor
public final class LogSettings: ObservableObject {
    /// The settings displayed by ``LogSettingsView`` and ``LogListView`` by default.
    public static let shared = LogSettings()

    /// The destinations that logs are sent to.
    @Published public var destinations: [LogDestinationSettings] = [] {
        didSet {
            if !isRestoring {
                save()
            }
            notifyHandlers()
        }
    }

    /// The levels that can be chosen in ``LogSettingsView`` and in the level filter of ``LogListView``.
    ///
    /// The level filter also lists any other level that has been recorded. Defaults to ``LogEntry/Level/standardLevels``.
    @Published public var availableLevels = LogEntry.Level.standardLevels

    /// The subsystems that can be enabled or disabled, and chosen in the subsystem filter of ``LogListView``.
    ///
    /// The subsystem filter also lists any other subsystem that has been recorded.
    @Published public var availableSubsystems: [LogEntry.Subsystem] = [] {
        didSet { notifyHandlers() }
    }

    /// The destinations that receive logs.
    public var enabledDestinations: [LogDestinationSettings] {
        destinations.filter(\.isEnabled)
    }

    /// The levels and subsystems last chosen in the filters of ``LogListView``, saved in `UserDefaults`.
    ///
    /// ``LogListView`` and ``LogViewer`` start with this filter unless another one is passed to them. The search text isn't saved.
    public var lastFilter: LogFilter? {
        get {
            guard let data = userDefaults.data(forKey: Self.filterStorageKey),
                  let saved = try? JSONDecoder().decode(SavedFilter.self, from: data) else { return nil }
            return saved.filter
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(SavedFilter(newValue)) {
                userDefaults.set(data, forKey: Self.filterStorageKey)
            } else {
                userDefaults.removeObject(forKey: Self.filterStorageKey)
            }
        }
    }

    private static let storageKey = "io.getstream.logs-ui.destinations"
    private static let filterStorageKey = "io.getstream.logs-ui.filter"

    private let userDefaults: UserDefaults
    private var defaultDestinations: [LogDestinationSettings] = []
    private var isRestoring = false
    private var handlers: [@MainActor (LogSettings) -> Void] = []

    /// Creates settings without any destination, which save their changes in the given user defaults.
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// The settings of the destination with the given identifier.
    public subscript(destinationID: String) -> LogDestinationSettings? {
        destinations.first { $0.id == destinationID }
    }

    /// The available subsystems that the given destination does not ignore.
    public func enabledSubsystems(for destination: LogDestinationSettings) -> [LogEntry.Subsystem] {
        availableSubsystems.filter { !destination.disabledSubsystems.contains($0) }
    }

    /// Sets the destinations used when the settings are reset, and applies them with the changes saved for each of them.
    ///
    /// Call it on every launch: it doesn't overwrite the saved changes.
    public func setDefaults(_ destinations: [LogDestinationSettings]) {
        defaultDestinations = destinations
        let saved = loadSaved()
        restore(destinations.map { destination in
            saved[destination.id].map { $0.applied(to: destination) } ?? destination
        })
    }

    /// Calls the handler with the current settings, and again whenever they change.
    public func apply(_ handler: @escaping @MainActor (LogSettings) -> Void) {
        handlers.append(handler)
        handler(self)
    }

    /// Removes the saved changes and restores the default values.
    public func reset() {
        userDefaults.removeObject(forKey: Self.storageKey)
        restore(defaultDestinations)
    }

    private func restore(_ destinations: [LogDestinationSettings]) {
        isRestoring = true
        self.destinations = destinations
        isRestoring = false
        notifyHandlers()
    }

    private func notifyHandlers() {
        guard !isRestoring else { return }
        handlers.forEach { $0(self) }
    }

    private func loadSaved() -> [String: SavedDestination] {
        guard let data = userDefaults.data(forKey: Self.storageKey) else { return [:] }
        return (try? JSONDecoder().decode([String: SavedDestination].self, from: data)) ?? [:]
    }

    private func save() {
        let defaults = Dictionary(defaultDestinations.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var saved: [String: SavedDestination] = [:]
        for destination in destinations {
            guard let defaultDestination = defaults[destination.id] else { continue }
            let savedDestination = SavedDestination(destination)
            if savedDestination != SavedDestination(defaultDestination) {
                saved[destination.id] = savedDestination
            }
        }
        if saved.isEmpty {
            userDefaults.removeObject(forKey: Self.storageKey)
        } else if let data = try? JSONEncoder().encode(saved) {
            userDefaults.set(data, forKey: Self.storageKey)
        }
    }
}

private struct SavedDestination: Codable, Equatable {
    var isEnabled: Bool
    var levelSeverity: Int
    var levelName: String
    var disabledSubsystems: [String]

    init(_ destination: LogDestinationSettings) {
        isEnabled = destination.isEnabled
        levelSeverity = destination.level.severity
        levelName = destination.level.name
        disabledSubsystems = destination.disabledSubsystems.sorted().map(\.rawValue)
    }

    func applied(to destination: LogDestinationSettings) -> LogDestinationSettings {
        var destination = destination
        destination.isEnabled = isEnabled
        destination.level = LogEntry.Level(severity: levelSeverity, name: levelName)
        destination.disabledSubsystems = Set(disabledSubsystems.map(LogEntry.Subsystem.init(rawValue:)))
        return destination
    }
}

private struct SavedFilter: Codable {
    struct Level: Codable {
        var severity: Int
        var name: String
    }

    var levels: [Level]
    var subsystems: [String]

    init(_ filter: LogFilter) {
        levels = filter.levels.sorted().map { Level(severity: $0.severity, name: $0.name) }
        subsystems = filter.subsystems.sorted().map(\.rawValue)
    }

    var filter: LogFilter {
        LogFilter(
            levels: Set(levels.map { LogEntry.Level(severity: $0.severity, name: $0.name) }),
            subsystems: Set(subsystems.map(LogEntry.Subsystem.init(rawValue:)))
        )
    }
}
