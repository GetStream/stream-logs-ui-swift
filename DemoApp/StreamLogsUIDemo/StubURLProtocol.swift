//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Foundation
import os

/// Answers requests to `api.acme.example` locally, so the demo works without a backend.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    static let host = "api.acme.example"

    private struct State {
        var isOffline = false
        var orderAttempts = 0
        var orderCount = 0
    }

    private enum Stub {
        case json(statusCode: Int, body: Data)
        case failure(URLError)
    }

    private static let state = OSAllocatedUnfairLock(initialState: State())

    static var isOffline: Bool {
        get { state.withLock { $0.isOffline } }
        set { state.withLock { $0.isOffline = newValue } }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let stub = Self.stub(for: request)
        let latency = Double.random(in: 0.15...0.6)
        DispatchQueue.global().asyncAfter(deadline: .now() + latency) { [self] in
            guard let client, let url = request.url else { return }
            switch stub {
            case let .failure(error):
                client.urlProtocol(self, didFailWithError: error)
            case let .json(statusCode, body):
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: [
                        "Content-Type": "application/json",
                        "X-Request-Id": UUID().uuidString.lowercased()
                    ]
                )
                if let response {
                    client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                }
                client.urlProtocol(self, didLoad: body)
                client.urlProtocolDidFinishLoading(self)
            }
        }
    }

    override func stopLoading() {}

    // MARK: - Routes

    private static func stub(for request: URLRequest) -> Stub {
        if isOffline {
            return .failure(URLError(.notConnectedToInternet))
        }
        let path = request.url?.path ?? ""
        switch (request.httpMethod ?? "GET", path) {
        case ("POST", "/v1/auth/refresh"):
            return json(200, [
                "user": ["id": "u_1029", "name": "Ada Lovelace"],
                "access_token": "demo-access-token",
                "expires_in": 3600
            ])
        case ("GET", "/v1/products"):
            let products = Catalog.products.compactMap(jsonObject)
            return json(200, ["products": products, "next_cursor": NSNull()])
        case ("POST", "/v1/cart/items"):
            return addToCart(body: body(of: request))
        case ("POST", "/v1/orders"):
            return placeOrder(body: body(of: request))
        case let ("GET", path) where path.hasSuffix("/reviews"):
            return json(404, error("not_found", "Reviews are not available for this product."))
        default:
            return json(404, error("not_found", "No route for \(path)."))
        }
    }

    private static func addToCart(body: [String: Any]) -> Stub {
        guard
            let productId = body["product_id"] as? String,
            let product = Catalog.products.first(where: { $0.id == productId })
        else {
            return json(422, error("invalid_product", "The product does not exist."))
        }
        return json(201, [
            "cart_id": "cart_7f3a",
            "item": [
                "product_id": product.id,
                "name": product.name,
                "quantity": body["quantity"] as? Int ?? 1,
                "unit_price": product.price,
                "currency": product.currency
            ]
        ])
    }

    private static func placeOrder(body: [String: Any]) -> Stub {
        let isFirstAttempt = state.withLock { state in
            state.orderAttempts += 1
            return state.orderAttempts.isMultiple(of: 2) == false
        }
        if isFirstAttempt {
            var payload = error("payment_provider_unavailable", "The payment provider did not respond in time.")
            payload["retry_after"] = 1
            return json(503, payload)
        }

        let items = body["items"] as? [[String: Any]] ?? []
        let total = items.reduce(0.0) { total, item in
            let product = Catalog.products.first { $0.id == item["product_id"] as? String }
            return total + (product?.price ?? 0) * Double(item["quantity"] as? Int ?? 1)
        }
        let number = state.withLock { state in
            state.orderCount += 1
            return state.orderCount
        }
        return json(201, [
            "order": [
                "id": "ord_\(4200 + number)",
                "status": "confirmed",
                "total": (total * 100).rounded() / 100,
                "currency": "EUR",
                "items": items
            ]
        ])
    }

    // MARK: - Helpers

    private static func json(_ statusCode: Int, _ object: [String: Any]) -> Stub {
        let body = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
        return .json(statusCode: statusCode, body: body)
    }

    private static func error(_ code: String, _ message: String) -> [String: Any] {
        ["error": ["code": code, "message": message]]
    }

    private static func jsonObject(_ product: Product) -> [String: Any]? {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? encoder.encode(product) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func body(of request: URLRequest) -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(buffer, count: count)
            }
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
}
