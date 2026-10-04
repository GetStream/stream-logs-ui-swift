//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import SwiftUI

@main
struct StreamLogsUIDemoApp: App {
    @StateObject private var store = StoreModel()

    init() {
        Log.setUp()
    }

    var body: some Scene {
        WindowGroup {
            StoreView()
                .environmentObject(store)
        }
    }
}
