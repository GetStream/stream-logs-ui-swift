//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Foundation

struct Product: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let category: String
    let price: Double
    let currency: String
    var stock: Int
    let rating: Double
    let imageUrl: String
    let tags: [String]
}

struct CartItem: Codable, Hashable, Sendable {
    let productId: String
    var quantity: Int
}

struct Order: Codable, Hashable, Sendable {
    let id: String
    var status: String
    let total: Double
    let currency: String
    let items: [CartItem]
}

struct UserSession: Codable, Sendable {
    struct User: Codable, Sendable {
        let id: String
        let name: String
    }

    let user: User
    let accessToken: String
    let expiresIn: Int
}

struct ProductsResponse: Codable, Sendable {
    let products: [Product]
    let nextCursor: String?
}

struct OrderResponse: Codable, Sendable {
    let order: Order
}

struct Review: Codable, Sendable {
    let author: String
    let rating: Int
    let text: String
}

enum Catalog {
    static let products: [Product] = [
        Product(
            id: "prd_1001",
            name: "Aeropress Go",
            category: "Brewers",
            price: 39.9,
            currency: "EUR",
            stock: 12,
            rating: 4.8,
            imageUrl: "https://cdn.acme.example/products/prd_1001.jpg",
            tags: ["travel", "bestseller"]
        ),
        Product(
            id: "prd_1002",
            name: "Chemex Classic",
            category: "Brewers",
            price: 49.0,
            currency: "EUR",
            stock: 4,
            rating: 4.7,
            imageUrl: "https://cdn.acme.example/products/prd_1002.jpg",
            tags: ["pour-over"]
        ),
        Product(
            id: "prd_1003",
            name: "Hand Grinder",
            category: "Grinders",
            price: 89.0,
            currency: "EUR",
            stock: 7,
            rating: 4.6,
            imageUrl: "https://cdn.acme.example/products/prd_1003.jpg",
            tags: ["burr", "manual"]
        ),
        Product(
            id: "prd_1004",
            name: "Gooseneck Kettle",
            category: "Kettles",
            price: 64.5,
            currency: "EUR",
            stock: 2,
            rating: 4.5,
            imageUrl: "https://cdn.acme.example/products/prd_1004.jpg",
            tags: ["electric", "temperature-control"]
        ),
        Product(
            id: "prd_1005",
            name: "Ethiopia Yirgacheffe 250 g",
            category: "Beans",
            price: 14.5,
            currency: "EUR",
            stock: 30,
            rating: 4.9,
            imageUrl: "https://cdn.acme.example/products/prd_1005.jpg",
            tags: ["light-roast", "single-origin"]
        ),
        Product(
            id: "prd_1006",
            name: "Paper Filters (100)",
            category: "Accessories",
            price: 6.0,
            currency: "EUR",
            stock: 54,
            rating: 4.4,
            imageUrl: "https://cdn.acme.example/products/prd_1006.jpg",
            tags: ["consumable"]
        )
    ]
}
