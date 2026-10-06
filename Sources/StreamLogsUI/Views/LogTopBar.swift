//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import SwiftUI

@available(iOS 16.0, *)
extension View {
    // Places content below the navigation bar, sharing its see-through scroll edge effect on iOS 26.
    @ViewBuilder
    func topBar(@ViewBuilder _ content: () -> some View) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            safeAreaBar(edge: .top, spacing: 0, content: content)
        } else {
            legacyTopBar(content)
        }
        #else
        legacyTopBar(content)
        #endif
    }

    private func legacyTopBar(@ViewBuilder _ content: () -> some View) -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                content()
                Divider()
            }
            .background(.bar)
        }
    }
}
