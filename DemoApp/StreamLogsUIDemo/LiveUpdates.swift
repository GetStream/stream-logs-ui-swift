//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Foundation
import StreamLogsUI

/// Simulates a WebSocket connection that pushes inventory and order events.
@MainActor
final class LiveUpdates {
    enum Event {
        case inventoryUpdated(productId: String, stock: Int)
        case orderUpdated(orderId: String, status: String)
    }

    var onEvent: ((Event) -> Void)?
    private var task: Task<Void, Never>?
    private var tick = 0
    private let connectionId = "conn_\(UUID().uuidString.prefix(8).lowercased())"

    func connect(products: @escaping () -> [Product], orders: @escaping () -> [Order]) {
        guard task == nil else { return }
        Log.record(.info, .webSocket, "Connecting to wss://ws.acme.example/v1/live")
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard let self, !Task.isCancelled else { return }
            receive("connection.ok", ["connection_id": connectionId, "user_id": "u_1029"])
            send(["type": "subscribe", "channels": ["inventory", "orders"]])
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.5))
                guard !Task.isCancelled else { return }
                receiveNextEvent(products: products(), orders: orders())
            }
        }
    }

    func disconnect() {
        guard let task else { return }
        task.cancel()
        self.task = nil
        send(["type": "unsubscribe", "channels": ["inventory", "orders"]])
        Log.record(.info, .webSocket, "Disconnected from wss://ws.acme.example/v1/live")
    }

    private func receiveNextEvent(products: [Product], orders: [Order]) {
        tick += 1
        if tick.isMultiple(of: 4) {
            receive("health.check", ["connection_id": connectionId])
        } else if let order = orders.first(where: { $0.status != "delivered" }), tick.isMultiple(of: 3) {
            let status = order.status == "confirmed" ? "shipped" : "delivered"
            receive("order.updated", ["order": ["id": order.id, "status": status]])
            onEvent?(.orderUpdated(orderId: order.id, status: status))
        } else if let product = products.filter({ $0.stock > 0 }).randomElement() {
            let stock = max(product.stock - Int.random(in: 1...2), 0)
            receive("inventory.updated", [
                "product": ["id": product.id, "name": product.name, "stock": stock],
                "warehouse": "lisbon-1"
            ])
            onEvent?(.inventoryUpdated(productId: product.id, stock: stock))
            if stock == 0 {
                Log.record(.warning, .cart, "\(product.name) is sold out")
            } else if stock < 3 {
                Log.record(.notice, .cart, "Only \(stock) left of \(product.name)")
            }
        }
    }

    private func send(_ payload: [String: Any]) {
        let type = payload["type"] as? String ?? "unknown"
        Log.record(.debug, .webSocket, "Sent \(type)", metadata: [
            .webSocketEventType: type,
            .webSocketSentPayload: Self.json(payload)
        ])
    }

    private func receive(_ type: String, _ fields: [String: Any]) {
        var payload = fields
        payload["type"] = type
        payload["created_at"] = ISO8601DateFormatter().string(from: Date())
        Log.record(type == "health.check" ? .trace : .debug, .webSocket, "Received \(type)", metadata: [
            .webSocketEventType: type,
            .webSocketReceivedPayload: Self.json(payload)
        ])
    }

    private static func json(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
