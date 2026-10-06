//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import StreamLogsUI
import XCTest

@MainActor
final class LogSettings_Tests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var subject: LogSettings!

    private let defaultDestinations = [
        LogDestinationSettings(id: "console", name: "Console", level: .error),
        LogDestinationSettings(id: "logViewer", name: "Log Viewer", level: .debug)
    ]

    override func setUp() async throws {
        try await super.setUp()
        suiteName = UUID().uuidString
        userDefaults = UserDefaults(suiteName: suiteName)
        subject = makeSettings()
    }

    override func tearDown() async throws {
        userDefaults.removePersistentDomain(forName: suiteName)
        subject = nil
        userDefaults = nil
        suiteName = nil
        try await super.tearDown()
    }

    func test_init_hasNoDestinations() {
        XCTAssertTrue(LogSettings(userDefaults: userDefaults).destinations.isEmpty)
    }

    func test_subscript_returnsDestinationWithIdentifier() {
        XCTAssertEqual(subject["logViewer"]?.level, .debug)
        XCTAssertNil(subject["unknown"])
    }

    func test_enabledDestinations_excludesDisabledDestinations() {
        subject.destinations[0].isEnabled = false

        XCTAssertEqual(subject.enabledDestinations.map(\.id), ["logViewer"])
    }

    func test_enabledSubsystems_excludesDisabledSubsystems() {
        subject.destinations[0].disabledSubsystems = ["httpRequests"]

        XCTAssertEqual(subject.enabledSubsystems(for: subject.destinations[0]), ["database", "webSocket"])
        XCTAssertEqual(subject.enabledSubsystems(for: subject.destinations[1]), ["database", "httpRequests", "webSocket"])
    }

    func test_setDefaults_restoresSavedChanges() {
        subject.destinations[0].isEnabled = false
        subject.destinations[1].level = .warning
        subject.destinations[1].disabledSubsystems = ["database", "webSocket"]

        let relaunched = makeSettings()

        XCTAssertEqual(relaunched.destinations, subject.destinations)
    }

    func test_setDefaults_restoresSavedCustomLevel() {
        let security = LogEntry.Level(severity: 45, name: "SECURITY")
        subject.destinations[0].level = security

        let relaunched = makeSettings()

        XCTAssertEqual(relaunched.destinations[0].level, security)
        XCTAssertEqual(relaunched.destinations[0].level.name, "SECURITY")
    }

    func test_setDefaults_doesNotOverwriteSavedChanges() {
        subject.destinations[0].level = .debug

        subject.setDefaults(defaultDestinations)

        XCTAssertEqual(subject.destinations[0].level, .debug)
        XCTAssertEqual(makeSettings().destinations[0].level, .debug)
    }

    func test_setDefaults_unchangedDestinationsFollowNewDefaults() {
        subject.destinations[0].level = .debug

        subject.setDefaults([
            LogDestinationSettings(id: "console", name: "Console", level: .info),
            LogDestinationSettings(id: "logViewer", name: "Log Viewer", level: .trace)
        ])

        XCTAssertEqual(subject.destinations.map(\.level), [.debug, .trace])
    }

    func test_setDefaults_usesDestinationsOfNewDefaults() {
        subject.destinations[1].level = .error

        subject.setDefaults([LogDestinationSettings(id: "console", name: "Console", level: .info)])

        XCTAssertEqual(subject.destinations.map(\.id), ["console"])
        XCTAssertEqual(subject.destinations[0].level, .info)
    }

    func test_setDefaults_notifiesHandlersOnce() {
        var callCount = 0
        subject.apply { _ in callCount += 1 }
        callCount = 0

        subject.setDefaults(defaultDestinations)

        XCTAssertEqual(callCount, 1)
    }

    func test_destinations_changingBackToDefaultRemovesSavedChange() {
        subject.destinations[0].level = .debug
        subject.destinations[0].level = .error

        subject.setDefaults([
            LogDestinationSettings(id: "console", name: "Console", level: .info),
            LogDestinationSettings(id: "logViewer", name: "Log Viewer", level: .debug)
        ])

        XCTAssertEqual(subject.destinations[0].level, .info)
    }

    func test_reset_restoresDefaults() {
        subject.destinations[0].isEnabled = false
        subject.destinations[1].level = .error
        subject.destinations[1].disabledSubsystems = ["database"]

        subject.reset()

        XCTAssertEqual(subject.destinations.map(\.isEnabled), [true, true])
        XCTAssertEqual(subject.destinations.map(\.level), [.error, .debug])
        XCTAssertTrue(subject.destinations[1].disabledSubsystems.isEmpty)
    }

    func test_reset_removesSavedChanges() {
        subject.destinations[0].isEnabled = false
        subject.destinations[1].level = .error

        subject.reset()

        XCTAssertEqual(makeSettings().destinations, defaultDestinations)
    }

    func test_reset_notifiesHandlersOnce() {
        var callCount = 0
        subject.apply { _ in callCount += 1 }
        subject.destinations[0].level = .debug
        callCount = 0

        subject.reset()

        XCTAssertEqual(callCount, 1)
    }

    func test_apply_callsHandlerImmediatelyAndOnEveryChange() {
        var levels: [LogEntry.Level] = []

        subject.apply { levels.append($0.destinations[0].level) }
        subject.destinations[0].level = .warning

        XCTAssertEqual(levels, [.error, .warning])
    }

    func test_apply_callsHandlerWhenSubsystemsChange() {
        var callCount = 0
        subject.apply { _ in callCount += 1 }

        subject.availableSubsystems = ["database"]

        XCTAssertEqual(callCount, 2)
    }

    private func makeSettings() -> LogSettings {
        let settings = LogSettings(userDefaults: userDefaults)
        settings.availableSubsystems = ["database", "httpRequests", "webSocket"]
        settings.setDefaults(defaultDestinations)
        return settings
    }
}
