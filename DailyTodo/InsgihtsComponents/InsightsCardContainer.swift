//
//  InsightsCardContainer.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct InsightsCardContainer<Content: View>: View {
    let delay: Double
    @ViewBuilder let content: Content

    @State private var isVisible = false

    init(delay: Double = 0, @ViewBuilder content: () -> Content) {
        self.delay = delay
        self.content = content()
    }

    var body: some View {
        content
            .animateWhenVisible($isVisible)
            .insightsReveal(isVisible: $isVisible, delay: delay)
    }
}
