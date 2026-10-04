//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Foundation
import StreamLogsUI

@MainActor
final class StoreModel: ObservableObject {
    @Published private(set) var userName: String?
    @Published private(set) var products: [Product] = []
    @Published private(set) var cart: [CartItem] = []
    @Published private(set) var orders: [Order] = []
    @Published private(set) var isPlacingOrder = false
    @Published var errorMessage: String?

    @Published var isLive = false {
        didSet {
            guard isLive != oldValue else { return }
            if isLive {
                liveUpdates.connect(products: { [weak self] in self?.products ?? [] }, orders: { [weak self] in self?.orders ?? [] })
            } else {
                liveUpdates.disconnect()
            }
        }
    }

    @Published var isOffline = false {
        didSet {
            guard isOffline != oldValue else { return }
            StubURLProtocol.isOffline = isOffline
            Log.record(isOffline ? .warning : .info, .network, isOffline ? "The device went offline" : "The device is back online")
        }
    }

    private let api = StoreAPI()
    private let liveUpdates = LiveUpdates()

    init() {
        liveUpdates.onEvent = { [weak self] event in
            self?.handle(event)
        }
    }

    var cartTotal: Double {
        cart.reduce(0) { total, item in
            total + (product(for: item)?.price ?? 0) * Double(item.quantity)
        }
    }

    func product(for item: CartItem) -> Product? {
        products.first { $0.id == item.productId }
    }

    func start() async {
        guard userName == nil else { return }
        Log.record(.info, .app, "App launched")
        do {
            let session = try await api.refreshSession()
            userName = session.user.name
            Log.record(.security, .auth, "Access token refreshed for \(session.user.id), expires in \(session.expiresIn) s")
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        await loadProducts()
    }

    func loadProducts() async {
        do {
            products = try await api.products()
            Log.record(.info, .app, "Loaded \(products.count) products")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addToCart(_ product: Product) async {
        do {
            try await api.addToCart(product)
            if let index = cart.firstIndex(where: { $0.productId == product.id }) {
                cart[index].quantity += 1
            } else {
                cart.append(CartItem(productId: product.id, quantity: 1))
            }
            Log.record(.info, .cart, "Added \(product.name) to the cart (\(cart.count) items)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reviews(for product: Product) async -> [Review] {
        Log.record(.debug, .app, "Opened \(product.name)")
        do {
            return try await api.reviews(for: product)
        } catch {
            Log.record(.notice, .app, "Showing \(product.name) without reviews")
            return []
        }
    }

    func placeOrder() async {
        guard !cart.isEmpty, !isPlacingOrder else { return }
        isPlacingOrder = true
        defer { isPlacingOrder = false }
        Log.record(.info, .cart, "Placing an order with \(cart.count) items")
        do {
            let order: Order
            do {
                order = try await api.placeOrder(cart)
            } catch let error as APIError where error.statusCode == 503 {
                Log.record(.warning, .cart, "The payment provider is unavailable, retrying in 1 s")
                try await Task.sleep(for: .seconds(1))
                order = try await api.placeOrder(cart)
            }
            orders.insert(order, at: 0)
            cart = []
            Log.record(.notice, .cart, "Order \(order.id) confirmed")
        } catch {
            Log.record(.error, .cart, "Failed to place the order", error: error)
            errorMessage = error.localizedDescription
        }
    }

    func logOneOfEachLevel() {
        Log.record(.trace, .app, "StoreView body evaluated in 1.8 ms")
        Log.record(.debug, .app, "Image cache hit for 6 of 6 products")
        Log.record(.info, .app, "The user opened the debug section")
        Log.record(.notice, .app, "A new version of the app is available: 1.1.0")
        Log.record(.warning, .network, "Product images took 2.4 s to load")
        Log.record(.security, .auth, "The access token will expire in 5 minutes")
        Log.record(
            .error,
            .cart,
            "Failed to persist the cart",
            error: CocoaError(.fileWriteOutOfSpace)
        )
        Log.record(
            .critical,
            .app,
            """
            The local database is corrupted and will be rebuilt
            file: Library/Application Support/Store.sqlite
            reason: database disk image is malformed (SQLITE_CORRUPT)
            """
        )
    }

    private func handle(_ event: LiveUpdates.Event) {
        switch event {
        case let .inventoryUpdated(productId, stock):
            guard let index = products.firstIndex(where: { $0.id == productId }) else { return }
            products[index].stock = stock
        case let .orderUpdated(orderId, status):
            guard let index = orders.firstIndex(where: { $0.id == orderId }) else { return }
            orders[index].status = status
            Log.record(.info, .cart, "Order \(orderId) is \(status)")
        }
    }
}
