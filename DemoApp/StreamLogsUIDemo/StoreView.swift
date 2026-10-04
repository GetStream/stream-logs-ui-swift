//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import StreamLogsUI
import SwiftUI

struct StoreView: View {
    @EnvironmentObject private var store: StoreModel
    @State private var showsFloatingButton = LogViewer.showsFloatingButton

    var body: some View {
        NavigationStack {
            List {
                productsSection
                cartSection
                ordersSection
                debugSection
                logViewerSection
            }
            .navigationTitle("Acme Coffee")
            .navigationDestination(for: Product.self) { product in
                ProductView(productId: product.id)
            }
            .refreshable {
                await store.loadProducts()
            }
            .task {
                await store.start()
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { store.errorMessage != nil },
                    set: { if !$0 { store.errorMessage = nil } }
                ),
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(store.errorMessage ?? "") }
            )
        }
    }

    private var productsSection: some View {
        Section {
            if store.products.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
            ForEach(store.products) { product in
                NavigationLink(value: product) {
                    ProductRow(product: product)
                }
            }
        } header: {
            Text(store.userName.map { "Welcome, \($0)" } ?? "Products")
        }
    }

    @ViewBuilder
    private var cartSection: some View {
        if !store.cart.isEmpty {
            Section("Cart") {
                ForEach(store.cart, id: \.productId) { item in
                    LabeledContent(
                        store.product(for: item)?.name ?? item.productId,
                        value: "× \(item.quantity)"
                    )
                }
                Button {
                    Task { await store.placeOrder() }
                } label: {
                    HStack {
                        Text("Place order")
                        Spacer()
                        if store.isPlacingOrder {
                            ProgressView()
                        } else {
                            Text(store.cartTotal, format: .currency(code: "EUR"))
                        }
                    }
                }
                .disabled(store.isPlacingOrder)
            }
        }
    }

    @ViewBuilder
    private var ordersSection: some View {
        if !store.orders.isEmpty {
            Section("Orders") {
                ForEach(store.orders, id: \.id) { order in
                    LabeledContent(order.id, value: order.status.capitalized)
                }
            }
        }
    }

    private var debugSection: some View {
        Section {
            Toggle("Live updates", isOn: $store.isLive)
            Toggle("Offline", isOn: $store.isOffline)
            Button("Log one entry of each level") {
                store.logOneOfEachLevel()
            }
        } header: {
            Text("Debug")
        } footer: {
            Text(
                "Live updates simulate a WebSocket. Placing an order fails once with a 503 and is retried, "
                    + "and opening a product requests its reviews, which return a 404."
            )
        }
    }

    private var logViewerSection: some View {
        Section {
            Button("Open log viewer") {
                LogViewer.present()
            }
            Toggle("Floating button", isOn: $showsFloatingButton)
                .onChange(of: showsFloatingButton) { isOn in
                    LogViewer.showsFloatingButton = isOn
                }
        } header: {
            Text("Log viewer")
        } footer: {
            Text("You can also shake the device to open the log viewer.")
        }
    }
}

private struct ProductRow: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.name)
            HStack {
                Text(product.price, format: .currency(code: product.currency))
                Spacer()
                StockLabel(stock: product.stock)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}

private struct StockLabel: View {
    let stock: Int

    var body: some View {
        switch stock {
        case 0:
            Text("Sold out").foregroundStyle(.red)
        case 1..<3:
            Text("Only \(stock) left").foregroundStyle(.orange)
        default:
            Text("\(stock) in stock")
        }
    }
}

private struct ProductView: View {
    @EnvironmentObject private var store: StoreModel
    @State private var reviews: [Review]?
    let productId: String

    var body: some View {
        if let product = store.products.first(where: { $0.id == productId }) {
            List {
                Section {
                    LabeledContent("Category", value: product.category)
                    LabeledContent("Price", value: product.price.formatted(.currency(code: product.currency)))
                    LabeledContent("Rating", value: product.rating.formatted())
                    LabeledContent("Stock") { StockLabel(stock: product.stock) }
                }
                Section {
                    Button("Add to cart") {
                        Task { await store.addToCart(product) }
                    }
                    .disabled(product.stock == 0)
                }
                Section("Reviews") {
                    if let reviews {
                        if reviews.isEmpty {
                            Text("Reviews are unavailable.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(reviews, id: \.author) { review in
                            VStack(alignment: .leading) {
                                Text(review.author).font(.headline)
                                Text(review.text)
                            }
                        }
                    } else {
                        ProgressView()
                    }
                }
            }
            .navigationTitle(product.name)
            .task {
                reviews = await store.reviews(for: product)
            }
        }
    }
}
