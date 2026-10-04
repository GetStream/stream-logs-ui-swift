//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Foundation
import StreamLogsUI

struct APIError: LocalizedError {
    let statusCode: Int
    let code: String
    let message: String

    var errorDescription: String? { message }
}

@MainActor
final class StoreAPI {
    private let session: URLSession
    private let baseURL = URL(string: "https://\(StubURLProtocol.host)/v1")!
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var accessToken: String?

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": "AcmeStore/1.0 (iOS)"
        ]
        session = URLSession(configuration: configuration)
        encoder.keyEncodingStrategy = .convertToSnakeCase
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func refreshSession() async throws -> UserSession {
        let session: UserSession = try await send("POST", "auth/refresh", body: ["refresh_token": "demo-refresh-token"])
        accessToken = session.accessToken
        return session
    }

    func products() async throws -> [Product] {
        let response: ProductsResponse = try await send("GET", "products")
        return response.products
    }

    func reviews(for product: Product) async throws -> [Review] {
        try await send("GET", "products/\(product.id)/reviews")
    }

    func addToCart(_ product: Product) async throws {
        let _: CartResponse = try await send(
            "POST",
            "cart/items",
            body: CartItem(productId: product.id, quantity: 1)
        )
    }

    func placeOrder(_ items: [CartItem]) async throws -> Order {
        struct Body: Encodable {
            let items: [CartItem]
            let paymentMethod: String
        }
        let response: OrderResponse = try await send(
            "POST",
            "orders",
            body: Body(items: items, paymentMethod: "card_visa_4242")
        )
        return response.order
    }

    private func send<Response: Decodable>(
        _ method: String,
        _ path: String,
        body: (any Encodable)? = nil
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            Log.record(
                .error,
                .network,
                "\(method) /v1/\(path) failed",
                error: error,
                metadata: .http(request: request, error: error, session: session)
            )
            throw error
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let isSuccess = (200..<300).contains(statusCode)
        Log.record(
            isSuccess ? .debug : .error,
            .network,
            "\(statusCode) \(method) /v1/\(path)",
            metadata: .http(request: request, response: response, responseBody: data, session: session)
        )
        guard isSuccess else {
            let failure = try? decoder.decode(ErrorResponse.self, from: data).error
            throw APIError(
                statusCode: statusCode,
                code: failure?.code ?? "unknown",
                message: failure?.message ?? "The request failed with status \(statusCode)."
            )
        }
        return try decoder.decode(Response.self, from: data)
    }
}

private struct ErrorResponse: Decodable {
    struct Failure: Decodable {
        let code: String
        let message: String
    }

    let error: Failure
}

private struct CartResponse: Decodable {
    let cartId: String
}
