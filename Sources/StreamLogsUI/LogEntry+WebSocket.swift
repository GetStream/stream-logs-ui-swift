//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Foundation

struct LogWebSocketMessage: Equatable, Sendable {
    enum Direction: Equatable, Sendable {
        case received
        case sent
    }

    let direction: Direction
    let eventType: String?
    let payloadKey: LogEntry.MetadataKey
    let payload: String
}

extension LogEntry {
    var webSocketMessage: LogWebSocketMessage? {
        let eventType = metadata[.webSocketEventType]
        if let payload = metadata[.webSocketReceivedPayload] {
            return LogWebSocketMessage(direction: .received, eventType: eventType, payloadKey: .webSocketReceivedPayload, payload: payload)
        }
        if let payload = metadata[.webSocketSentPayload] {
            return LogWebSocketMessage(direction: .sent, eventType: eventType, payloadKey: .webSocketSentPayload, payload: payload)
        }
        return nil
    }
}

public extension Dictionary where Key == LogEntry.MetadataKey, Value == String {
    /// Creates the metadata of a WebSocket message received from the server, so the entry is displayed as a WebSocket message.
    ///
    /// JSON payloads are pretty-printed.
    ///
    /// - Parameters:
    ///   - eventType: The type of the event, like `message.new`.
    ///   - receivedPayload: The payload that was received.
    static func webSocket(eventType: String? = nil, receivedPayload: Data) -> Self {
        webSocket(eventType: eventType, payloadKey: .webSocketReceivedPayload, payload: receivedPayload)
    }

    /// Creates the metadata of a WebSocket message sent to the server, so the entry is displayed as a WebSocket message.
    ///
    /// JSON payloads are pretty-printed.
    ///
    /// - Parameters:
    ///   - eventType: The type of the event, like `health.check`.
    ///   - sentPayload: The payload that was sent.
    static func webSocket(eventType: String? = nil, sentPayload: Data) -> Self {
        webSocket(eventType: eventType, payloadKey: .webSocketSentPayload, payload: sentPayload)
    }

    private static func webSocket(eventType: String?, payloadKey: LogEntry.MetadataKey, payload: Data) -> Self {
        var metadata: Self = [payloadKey: bodyDescription(of: payload) ?? ""]
        metadata[.webSocketEventType] = eventType
        return metadata
    }
}
